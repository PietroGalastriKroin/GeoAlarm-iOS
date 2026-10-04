#if DEBUG
import Foundation

/// Dados e atalhos usados só pelos testes de interface (capturas de tela no CI).
/// Ativados por argumentos de lançamento, nunca no uso normal e nem em builds Release.
extension AppContainer {
    func applyUITestLaunchArguments() {
        let args = CommandLine.arguments
        guard args.contains("-seedDemo") else { return }

        if ((try? repository.all()) ?? []).isEmpty {
            var home = GeoAlarm(title: "Casa", coordinate: Coordinate(latitude: -25.4284, longitude: -49.2733))
            home.message = "Você chegou em casa."
            home.radiusMeters = 300
            home.activeDays = Weekday.weekdays

            var work = GeoAlarm(title: "Saída do trabalho", coordinate: Coordinate(latitude: -25.4390, longitude: -49.2690))
            work.transition = .exit
            work.radiusMeters = 500
            work.snoozeType = .distance

            var gym = GeoAlarm(title: "Academia", coordinate: Coordinate(latitude: -25.4450, longitude: -49.2800))
            gym.isEnabled = false
            gym.radiusMeters = 1000
            gym.activeDays = [.monday, .wednesday, .friday, .saturday]

            for alarm in [home, work, gym] { try? repository.save(alarm) }
        }

        if let index = args.firstIndex(of: "-showTrigger"), args.indices.contains(index + 1) {
            var alarm = GeoAlarm(title: "Chegando em casa",
                                 coordinate: Coordinate(latitude: -25.4284, longitude: -49.2733))
            alarm.message = "Hora de descansar. Não esqueça de dar comida ao gato."
            switch args[index + 1] {
            case "hold": alarm.dismissStyle = .hold
            case "button": alarm.dismissStyle = .button
            default: alarm.dismissStyle = .swipe
            }
            coordinator.present(alarm, playFeedback: false)
        }
    }
}
#endif
