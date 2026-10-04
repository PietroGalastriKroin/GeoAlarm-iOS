import AppIntents
import Foundation

// Intents executados pelos botões do alerta do AlarmKit na tela de bloqueio. Rodam no
// processo do app (o sistema o inicia em segundo plano se for preciso), sem abrir a interface.

struct SnoozeGeoAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Soneca"

    @Parameter(title: "Alarme")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        await AppContainer.shared.snoozeFromSystem(alarmID: alarmID)
        return .result()
    }
}

struct DismissGeoAlarmIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Dispensar"

    @Parameter(title: "Alarme")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        await AppContainer.shared.dismissFromSystem(alarmID: alarmID)
        return .result()
    }
}
