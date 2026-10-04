import Foundation

/// Condição de disparo relativa à área do alarme.
enum GeofenceTransition: String, Codable, CaseIterable, Sendable {
    case enter
    case exit
}

/// Padrão de vibração/háptica tocado junto com (ou no lugar de) o som.
enum VibrationPattern: String, Codable, CaseIterable, Sendable {
    case none
    case continuous
    case shortPulse
    case sos
    case heartbeat
}

/// Como o alarme volta a tocar depois de silenciado uma vez.
enum SnoozeType: String, Codable, CaseIterable, Sendable {
    case none
    case time
    case distance
}

/// Como o usuário precisa interagir com a tela de alarme para descartá-lo.
enum DismissStyle: String, Codable, CaseIterable, Sendable {
    case button
    case swipe
    case hold
}

enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case light
    case dark
    case system
}

/// Dia da semana com os mesmos valores de `Calendar.component(.weekday)` (1 = domingo).
enum Weekday: Int, Codable, CaseIterable, Sendable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    init(date: Date, calendar: Calendar = .current) {
        self = Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday
    }

    static let weekdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<Weekday> = [.saturday, .sunday]
    static let everyDay: Set<Weekday> = Set(Weekday.allCases)
}
