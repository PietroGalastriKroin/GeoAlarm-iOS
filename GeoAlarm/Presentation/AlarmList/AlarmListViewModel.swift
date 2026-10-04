import Foundation
import Observation

@MainActor
@Observable
final class AlarmListViewModel {
    private(set) var alarms: [GeoAlarm] = []
    var errorMessage: String?

    @ObservationIgnored private let getAlarms: GetAlarmsUseCase
    @ObservationIgnored private let toggleAlarm: ToggleAlarmUseCase
    @ObservationIgnored private let deleteAlarm: DeleteAlarmUseCase

    convenience init() {
        self.init(container: AppContainer.shared)
    }

    init(container: AppContainer) {
        getAlarms = container.getAlarms
        toggleAlarm = container.toggleAlarm
        deleteAlarm = container.deleteAlarm
    }

    func load() {
        do {
            alarms = try getAlarms()
        } catch {
            errorMessage = "Não foi possível carregar os alarmes: \(error.localizedDescription)"
        }
    }

    func setEnabled(_ alarm: GeoAlarm, enabled: Bool) {
        do {
            try toggleAlarm(id: alarm.id, enabled: enabled)
            load()
        } catch {
            errorMessage = "Não foi possível alterar o alarme: \(error.localizedDescription)"
        }
    }

    func delete(_ alarm: GeoAlarm) {
        do {
            try deleteAlarm(id: alarm.id)
            load()
        } catch {
            errorMessage = "Não foi possível excluir o alarme: \(error.localizedDescription)"
        }
    }
}
