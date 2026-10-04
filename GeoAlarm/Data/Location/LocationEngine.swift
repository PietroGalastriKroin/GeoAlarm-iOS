import CoreLocation
import Foundation
import Observation

/// Dono único do `CLLocationManager`: autorização em duas etapas, monitoramento das (no
/// máximo 20) regiões, posição atual e rastreamento contínuo para a soneca por distância.
@MainActor
@Observable
final class LocationEngine: NSObject, GeofenceMonitoring, LocationProviding {
    enum Authorization: Equatable {
        case notDetermined
        case denied
        case whenInUse
        case always
    }

    private(set) var authorization: Authorization = .notDetermined
    private(set) var lastKnown: Coordinate?
    private(set) var monitoredAlarmIDs: Set<UUID> = []
    /// Quantos alarmes ligados existem além dos que cabem no limite de 20 regiões.
    private(set) var overflowCount = 0

    @ObservationIgnored var onRegionEvent: ((UUID, GeofenceTransition) -> Void)?
    /// Chamado quando a posição muda o bastante para valer reavaliar quais regiões monitorar.
    @ObservationIgnored var onSignificantMove: (() -> Void)?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var allAlarms: [GeoAlarm] = []
    @ObservationIgnored private var pendingFixes: [UUID: CheckedContinuation<Coordinate?, Never>] = [:]
    @ObservationIgnored private var trackingTokens: Set<UUID> = []
    @ObservationIgnored private var significantChangesRunning = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorization = Self.map(manager.authorizationStatus)
        if let loc = manager.location {
            lastKnown = Coordinate(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
    }

    // MARK: Autorização (duas etapas: nunca pedir "ao usar" e "sempre" juntos)

    /// Etapa 1: "Ao usar o app".
    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    /// Etapa 2: "Sempre". Só faz sentido depois da etapa 1; o iOS ignora se for chamada antes.
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    private static func map(_ status: CLAuthorizationStatus) -> Authorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted, .denied: return .denied
        case .authorizedWhenInUse: return .whenInUse
        case .authorizedAlways: return .always
        @unknown default: return .denied
        }
    }

    // MARK: Posição atual

    func currentLocation() async -> Coordinate? {
        guard authorization == .whenInUse || authorization == .always else { return lastKnown }
        let token = UUID()
        return await withCheckedContinuation { continuation in
            pendingFixes[token] = continuation
            manager.requestLocation()
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self?.resolveFix(token: token, with: self?.lastKnown)
            }
        }
    }

    private func resolveFix(token: UUID, with coordinate: Coordinate?) {
        pendingFixes.removeValue(forKey: token)?.resume(returning: coordinate)
    }

    // MARK: Geofencing

    func sync(alarms: [GeoAlarm]) {
        allAlarms = alarms
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            EventLog.shared.add("Monitoramento de regiões indisponível neste aparelho")
            return
        }

        let enabledCount = alarms.filter(\.isEnabled).count
        let wanted = RegionSelector.select(from: alarms, around: lastKnown)
        overflowCount = max(0, enabledCount - wanted.count)

        let wantedIDs = Set(wanted.map { $0.id.uuidString })
        var existing: [String: CLCircularRegion] = [:]
        for region in manager.monitoredRegions {
            guard let circular = region as? CLCircularRegion else { continue }
            if wantedIDs.contains(circular.identifier) {
                existing[circular.identifier] = circular
            } else {
                manager.stopMonitoring(for: circular)
            }
        }

        let maxRadius = manager.maximumRegionMonitoringDistance
        for alarm in wanted {
            let id = alarm.id.uuidString
            let radius = maxRadius > 0 ? min(alarm.effectiveRadiusMeters, maxRadius) : alarm.effectiveRadiusMeters
            let center = CLLocationCoordinate2D(latitude: alarm.coordinate.latitude,
                                                longitude: alarm.coordinate.longitude)
            let notifyOnEntry = alarm.transition == .enter
            if let old = existing[id],
               old.center.latitude == center.latitude,
               old.center.longitude == center.longitude,
               old.radius == radius,
               old.notifyOnEntry == notifyOnEntry,
               old.notifyOnExit == !notifyOnEntry {
                continue   // já está igual: não reinicia (preserva o estado dentro/fora)
            }
            let region = CLCircularRegion(center: center, radius: radius, identifier: id)
            region.notifyOnEntry = notifyOnEntry
            region.notifyOnExit = !notifyOnEntry
            manager.startMonitoring(for: region)
        }
        monitoredAlarmIDs = Set(wanted.map(\.id))

        // Com mais alarmes que regiões, precisamos saber quando o usuário se desloca para
        // trocar o conjunto monitorado.
        updateSignificantChanges(needed: overflowCount > 0 && authorization == .always)
        EventLog.shared.add("Regiões monitoradas: \(wanted.count) de \(enabledCount) alarmes ligados")
    }

    private func updateSignificantChanges(needed: Bool) {
        if needed && !significantChangesRunning {
            manager.startMonitoringSignificantLocationChanges()
            significantChangesRunning = true
        } else if !needed && significantChangesRunning {
            manager.stopMonitoringSignificantLocationChanges()
            significantChangesRunning = false
        }
    }

    // MARK: Rastreamento contínuo (soneca por distância)

    /// Liga localização contínua em segundo plano (indicador azul do iOS) enquanto houver
    /// algum `token` ativo. Consome bateria, por isso só roda durante uma soneca por distância.
    func startTracking(token: UUID) {
        let wasEmpty = trackingTokens.isEmpty
        trackingTokens.insert(token)
        guard wasEmpty else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.distanceFilter = kCLDistanceFilterNone
        manager.startUpdatingLocation()
        EventLog.shared.add("Rastreamento contínuo ligado (soneca por distância)")
    }

    func stopTracking(token: UUID) {
        guard trackingTokens.remove(token) != nil, trackingTokens.isEmpty else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        EventLog.shared.add("Rastreamento contínuo desligado")
    }

    // MARK: Tratamento dos callbacks (sempre no MainActor)

    fileprivate func handle(authorizationStatus status: CLAuthorizationStatus) {
        authorization = Self.map(status)
        EventLog.shared.add("Autorização de localização: \(authorization)")
        sync(alarms: allAlarms)
    }

    fileprivate func handle(locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let coordinate = Coordinate(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude)
        lastKnown = coordinate
        for token in Array(pendingFixes.keys) {
            resolveFix(token: token, with: coordinate)
        }
        if significantChangesRunning { onSignificantMove?() }
    }

    fileprivate func handle(regionID: String, transition: GeofenceTransition) {
        guard let id = UUID(uuidString: regionID) else { return }
        EventLog.shared.add("Evento de região: \(transition == .enter ? "entrou" : "saiu") (\(regionID.prefix(8)))")
        onRegionEvent?(id, transition)
    }
}

extension LocationEngine: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handle(authorizationStatus: status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.handle(locations: locations) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in EventLog.shared.add("Erro de localização: \(error.localizedDescription)") }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handle(regionID: id, transition: .enter) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let id = region.identifier
        Task { @MainActor in self.handle(regionID: id, transition: .exit) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     monitoringDidFailFor region: CLRegion?,
                                     withError error: Error) {
        let id = region?.identifier ?? "?"
        Task { @MainActor in
            EventLog.shared.add("Falha ao monitorar região \(id.prefix(8)): \(error.localizedDescription)")
        }
    }
}
