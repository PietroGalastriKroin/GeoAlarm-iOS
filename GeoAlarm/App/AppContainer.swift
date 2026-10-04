import Foundation
import SwiftData
import UIKit
import UserNotifications

/// Raiz de composição: cria e liga todas as dependências à mão (sem framework de DI), no
/// mesmo espírito do `ServiceLocator` do app Android. É um singleton porque o sistema
/// pode acordar o app em segundo plano (evento de região, botão do alarme) sem passar pela
/// interface, e esse código precisa encontrar os mesmos objetos que a UI usa.
@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let modelContainer: ModelContainer
    let repository: SwiftDataGeoAlarmRepository
    let settingsRepository: UserDefaultsSettingsRepository
    let settingsStore: SettingsStore
    let location: LocationEngine
    let fallbackDelivery: NotificationFallbackDelivery
    let delivery: LayeredAlarmDelivery
    let coordinator: AlarmCoordinator
    let notificationDelegate = NotificationDelegate()

    let getAlarms: GetAlarmsUseCase
    let getAlarm: GetAlarmUseCase
    let saveAlarm: SaveAlarmUseCase
    let deleteAlarm: DeleteAlarmUseCase
    let toggleAlarm: ToggleAlarmUseCase
    let resyncGeofences: ResyncGeofencesUseCase

    private init() {
        do {
            modelContainer = try SwiftDataGeoAlarmRepository.makeContainer()
        } catch {
            // Banco ilegível: segue em memória para o app abrir e o erro ficar visível no log.
            EventLog.shared.add("Erro ao abrir o banco de dados: \(error.localizedDescription)")
            modelContainer = try! SwiftDataGeoAlarmRepository.makeContainer(inMemory: true)
        }
        repository = SwiftDataGeoAlarmRepository(container: modelContainer)
        settingsRepository = UserDefaultsSettingsRepository()
        settingsStore = SettingsStore(repository: settingsRepository)
        location = LocationEngine()
        fallbackDelivery = NotificationFallbackDelivery()
        delivery = LayeredAlarmDelivery(fallback: fallbackDelivery, settings: settingsRepository)

        getAlarms = GetAlarmsUseCase(repository: repository)
        getAlarm = GetAlarmUseCase(repository: repository)
        resyncGeofences = ResyncGeofencesUseCase(repository: repository, geofences: location)
        saveAlarm = SaveAlarmUseCase(repository: repository, resync: resyncGeofences)
        deleteAlarm = DeleteAlarmUseCase(repository: repository, delivery: delivery, resync: resyncGeofences)
        toggleAlarm = ToggleAlarmUseCase(repository: repository, delivery: delivery, resync: resyncGeofences)

        coordinator = AlarmCoordinator(getAlarm: getAlarm, delivery: delivery, location: location)
        coordinator.isAppActive = { [weak self] in self?.isAppActive() ?? false }

        location.onRegionEvent = { [weak self] id, transition in
            guard let self else { return }
            Task {
                await self.coordinator.handleRegionEvent(alarmID: id, transition: transition)
                // Reavalia o conjunto das 20 regiões depois de cada evento.
                self.resyncGeofences()
            }
        }
        location.onSignificantMove = { [weak self] in self?.resyncGeofences() }
    }

    /// Chamado na abertura do app, inclusive quando o sistema o relança em segundo plano.
    func start() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        fallbackDelivery.registerCategories()
        #if DEBUG
        applyUITestLaunchArguments()
        #endif
        resyncGeofences()
    }

    func isAppActive() -> Bool {
        UIApplication.shared.applicationState == .active
    }

    // MARK: Ações vindas dos botões do alerta do sistema

    func snoozeFromSystem(alarmID: String) async {
        await coordinator.snoozeFromSystem(alarmID: alarmID)
    }

    func dismissFromSystem(alarmID: String) async {
        coordinator.dismissFromSystem(alarmID: alarmID)
    }
}
