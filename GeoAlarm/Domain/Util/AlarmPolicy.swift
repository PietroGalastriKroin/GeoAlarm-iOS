import Foundation

/// Regras de negócio puras de quando um alarme dispara e como a soneca funciona.
enum AlarmPolicy {
    /// Intervalo entre reverificações da soneca por distância (igual ao app Android: 2 min).
    static let distanceSnoozeRecheckInterval: TimeInterval = 120

    /// Se um evento de região deve tocar o alarme: o alarme precisa estar ligado, ativo no dia
    /// atual e a transição ocorrida precisa ser a configurada.
    static func shouldFire(_ alarm: GeoAlarm,
                           on transition: GeofenceTransition,
                           at date: Date = Date(),
                           calendar: Calendar = .current) -> Bool {
        alarm.transition == transition && alarm.isActive(on: date, calendar: calendar)
    }

    /// Soneca por distância: toca de novo se o usuário ainda estiver a `snoozeDistanceMeters`
    /// (ou menos) do ponto central.
    static func shouldRingAgain(_ alarm: GeoAlarm, userLocation: Coordinate) -> Bool {
        Geo.isWithin(alarm.snoozeDistanceMeters, of: alarm.coordinate, point: userLocation)
    }
}
