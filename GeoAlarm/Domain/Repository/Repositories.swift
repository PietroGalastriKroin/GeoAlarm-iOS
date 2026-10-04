import Foundation

@MainActor
protocol GeoAlarmRepository {
    func all() throws -> [GeoAlarm]
    func get(id: UUID) throws -> GeoAlarm?
    func save(_ alarm: GeoAlarm) throws
    func delete(id: UUID) throws
    func setEnabled(id: UUID, enabled: Bool) throws
}

@MainActor
protocol SettingsRepository {
    var settings: AppSettings { get }
    func update(_ transform: (inout AppSettings) -> Void)
}
