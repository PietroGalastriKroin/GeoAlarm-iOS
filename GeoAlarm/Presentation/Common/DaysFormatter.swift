import Foundation

enum DaysFormatter {
    static let shortNames: [Weekday: String] = [
        .sunday: "Dom", .monday: "Seg", .tuesday: "Ter", .wednesday: "Qua",
        .thursday: "Qui", .friday: "Sex", .saturday: "Sáb",
    ]

    /// Ordem de exibição: segunda a domingo.
    static let displayOrder: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    static func summary(_ days: Set<Weekday>) -> String {
        if days == Weekday.everyDay { return "Todos os dias" }
        if days == Weekday.weekdays { return "Seg a Sex" }
        if days == Weekday.weekend { return "Fim de semana" }
        if days.isEmpty { return "Nenhum dia" }
        return displayOrder.filter(days.contains).compactMap { shortNames[$0] }.joined(separator: ", ")
    }
}
