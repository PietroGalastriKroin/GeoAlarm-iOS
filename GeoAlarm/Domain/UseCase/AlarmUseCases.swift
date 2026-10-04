import Foundation

/// Casos de uso pequenos e de propósito único em cima do repositório. Toda mudança nos
/// alarmes termina em `ResyncGeofencesUseCase`, para o monitoramento nunca ficar defasado.
@MainActor
struct GetAlarmsUseCase {
    let repository: GeoAlarmRepository
    func callAsFunction() throws -> [GeoAlarm] {
        try repository.all().sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

@MainActor
struct GetAlarmUseCase {
    let repository: GeoAlarmRepository
    func callAsFunction(id: UUID) throws -> GeoAlarm? { try repository.get(id: id) }
}

@MainActor
struct ResyncGeofencesUseCase {
    let repository: GeoAlarmRepository
    let geofences: GeofenceMonitoring
    func callAsFunction() {
        geofences.sync(alarms: (try? repository.all()) ?? [])
    }
}

@MainActor
struct SaveAlarmUseCase {
    let repository: GeoAlarmRepository
    let resync: ResyncGeofencesUseCase
    func callAsFunction(_ alarm: GeoAlarm) throws {
        try repository.save(alarm)
        resync()
    }
}

@MainActor
struct DeleteAlarmUseCase {
    let repository: GeoAlarmRepository
    let delivery: AlarmDelivering
    let resync: ResyncGeofencesUseCase
    func callAsFunction(id: UUID) throws {
        delivery.cancel(alarmID: id)
        try repository.delete(id: id)
        resync()
    }
}

@MainActor
struct ToggleAlarmUseCase {
    let repository: GeoAlarmRepository
    let delivery: AlarmDelivering
    let resync: ResyncGeofencesUseCase
    func callAsFunction(id: UUID, enabled: Bool) throws {
        try repository.setEnabled(id: id, enabled: enabled)
        if !enabled { delivery.cancel(alarmID: id) }
        resync()
    }
}
