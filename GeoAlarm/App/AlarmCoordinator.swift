import Foundation
import Observation
import UIKit

/// Orquestra o ciclo de vida de um disparo: decide se o alarme toca dentro do app ou pelo
/// sistema (AlarmKit/notificações), controla som e háptica, e implementa as sonecas.
@MainActor
@Observable
final class AlarmCoordinator {
    /// Alarme atualmente exibido na tela de alarme (nil = nenhuma tela aberta).
    private(set) var activeAlarm: GeoAlarm?
    private(set) var distanceMeters: Double?

    @ObservationIgnored private let getAlarm: GetAlarmUseCase
    @ObservationIgnored private let delivery: AlarmDelivering
    @ObservationIgnored private let location: LocationEngine
    @ObservationIgnored private let sound = AlarmSoundPlayer()
    @ObservationIgnored private let haptics = HapticPlayer()
    @ObservationIgnored private var lastFired: [UUID: Date] = [:]
    @ObservationIgnored private var distanceSnoozeTasks: [UUID: Task<Void, Never>] = [:]

    /// Injetado pelo AppContainer (evita depender de UIKit nas regras de decisão).
    @ObservationIgnored var isAppActive: () -> Bool = { true }

    /// Janela mínima entre dois disparos do mesmo alarme (o iOS pode repetir eventos de borda).
    private static let refireWindow: TimeInterval = 60

    init(getAlarm: GetAlarmUseCase, delivery: AlarmDelivering, location: LocationEngine) {
        self.getAlarm = getAlarm
        self.delivery = delivery
        self.location = location
    }

    // MARK: Disparo por geofence

    func handleRegionEvent(alarmID: UUID, transition: GeofenceTransition) async {
        guard let alarm = try? getAlarm(id: alarmID) else {
            EventLog.shared.add("Evento ignorado: alarme não encontrado")
            return
        }
        guard AlarmPolicy.shouldFire(alarm, on: transition) else {
            EventLog.shared.add("Evento ignorado para \"\(alarm.displayTitle)\" (transição ou dia da semana não confere)")
            return
        }
        if distanceSnoozeTasks[alarmID] != nil || activeAlarm?.id == alarmID {
            EventLog.shared.add("Evento ignorado para \"\(alarm.displayTitle)\": já está tocando ou em soneca")
            return
        }
        if let last = lastFired[alarmID], Date().timeIntervalSince(last) < Self.refireWindow {
            EventLog.shared.add("Evento repetido ignorado para \"\(alarm.displayTitle)\"")
            return
        }
        lastFired[alarmID] = Date()
        await fire(alarm)
    }

    /// Toca o alarme da forma mais adequada ao estado do app.
    func fire(_ alarm: GeoAlarm) async {
        if isAppActive() {
            EventLog.shared.add("Disparo de \"\(alarm.displayTitle)\" com o app aberto: tela de alarme")
            present(alarm, playFeedback: true)
        } else {
            let outcome = await delivery.deliver(alarm, after: 2)
            EventLog.shared.add("Disparo de \"\(alarm.displayTitle)\" com o app em segundo plano: \(describe(outcome))")
        }
    }

    // MARK: Tela de alarme

    /// Abre a tela de alarme. `playFeedback` liga som e háptica dentro do app.
    func present(_ alarm: GeoAlarm, playFeedback: Bool) {
        stopFeedback()
        activeAlarm = alarm
        distanceMeters = nil
        UIApplication.shared.isIdleTimerDisabled = true
        if playFeedback {
            if alarm.soundEnabled {
                sound.start(soundID: alarm.soundID, fadeInSeconds: alarm.volumeFadeInSeconds)
            }
            if alarm.vibrationEnabled {
                haptics.start(alarm.vibrationPattern)
            }
        }
        Task { await refreshDistance() }
    }

    func refreshDistance() async {
        guard let alarm = activeAlarm else { return }
        guard let here = await location.currentLocation() else { return }
        distanceMeters = Geo.distanceMeters(from: here, to: alarm.coordinate)
    }

    /// Toque em notificação do plano B: para a cadeia de notificações e continua dentro do app.
    func openFromNotification(alarmID: UUID) {
        guard let alarm = try? getAlarm(id: alarmID) else { return }
        delivery.cancel(alarmID: alarmID)
        present(alarm, playFeedback: true)
    }

    // MARK: Dispensar e soneca

    func dismiss() {
        guard let alarm = activeAlarm else { return }
        finish(alarmID: alarm.id)
    }

    func snooze() async {
        guard let alarm = activeAlarm else { return }
        closeScreen()
        await startSnooze(alarm)
    }

    func snoozeFromSystem(alarmID: String) async {
        guard let id = UUID(uuidString: alarmID), let alarm = try? getAlarm(id: id) else { return }
        if activeAlarm?.id == id { closeScreen() }
        await startSnooze(alarm)
    }

    func dismissFromSystem(alarmID: String) {
        guard let id = UUID(uuidString: alarmID) else { return }
        finish(alarmID: id)
    }

    /// Encerra tudo relacionado ao alarme: tela, som, agendamentos e rastreamento.
    private func finish(alarmID: UUID) {
        if activeAlarm?.id == alarmID { closeScreen() }
        cancelDistanceSnooze(alarmID)
        delivery.cancel(alarmID: alarmID)
        EventLog.shared.add("Alarme dispensado")
    }

    private func closeScreen() {
        stopFeedback()
        activeAlarm = nil
        distanceMeters = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func stopFeedback() {
        sound.stop()
        haptics.stop()
    }

    private func startSnooze(_ alarm: GeoAlarm) async {
        switch alarm.snoozeType {
        case .none:
            delivery.cancel(alarmID: alarm.id)
        case .time:
            let outcome = await delivery.scheduleSnooze(alarm, minutes: alarm.snoozeMinutes)
            EventLog.shared.add("Soneca de \(alarm.snoozeMinutes) min: \(describe(outcome))")
        case .distance:
            delivery.cancel(alarmID: alarm.id)
            startDistanceSnooze(alarm)
        }
    }

    // MARK: Soneca por distância

    /// O iOS não oferece um timer periódico confiável em segundo plano. Para reverificar a
    /// distância a cada 2 minutos como no Android, mantemos localização contínua ligada
    /// (com o indicador azul do sistema) enquanto a soneca estiver ativa.
    private func startDistanceSnooze(_ alarm: GeoAlarm) {
        cancelDistanceSnooze(alarm.id)
        location.startTracking(token: alarm.id)
        let startedAt = Date()
        EventLog.shared.add("Soneca por distância: toca de novo se estiver a menos de \(Int(alarm.snoozeDistanceMeters)) m do ponto")
        distanceSnoozeTasks[alarm.id] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if Task.isCancelled { return }
                await self?.evaluateDistanceSnooze(alarmID: alarm.id, startedAt: startedAt)
            }
        }
    }

    private func evaluateDistanceSnooze(alarmID: UUID, startedAt: Date) async {
        guard Date().timeIntervalSince(startedAt) >= AlarmPolicy.distanceSnoozeRecheckInterval else { return }
        // Relê o alarme: se foi apagado ou desligado durante a soneca, encerra.
        guard let alarm = try? getAlarm(id: alarmID), alarm.isEnabled else {
            cancelDistanceSnooze(alarmID)
            return
        }
        guard let here = location.lastKnown else { return }
        if AlarmPolicy.shouldRingAgain(alarm, userLocation: here) {
            cancelDistanceSnooze(alarmID)
            await fire(alarm)
        }
    }

    private func cancelDistanceSnooze(_ alarmID: UUID) {
        guard let task = distanceSnoozeTasks.removeValue(forKey: alarmID) else { return }
        task.cancel()
        location.stopTracking(token: alarmID)
    }

    // MARK: Utilitários

    private func describe(_ outcome: DeliveryOutcome) -> String {
        switch outcome {
        case .alarmKit: return "agendado no AlarmKit"
        case .notificationFallback: return "agendado por notificações"
        case .failed(let reason): return "FALHOU (\(reason))"
        }
    }
}
