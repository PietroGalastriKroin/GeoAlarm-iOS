import Foundation

/// Escolhe a melhor estratégia disponível para fazer o alarme tocar fora do app:
/// AlarmKit (iOS 26+, autorizado) e, se não der, notificações locais em cadeia.
@MainActor
final class LayeredAlarmDelivery: AlarmDelivering {
    private let fallback: NotificationFallbackDelivery
    private let settings: SettingsRepository
    private var kitStorage: AnyObject?

    init(fallback: NotificationFallbackDelivery, settings: SettingsRepository) {
        self.fallback = fallback
        self.settings = settings
    }

    @available(iOS 26.0, *)
    var alarmKit: AlarmKitDelivery {
        if let existing = kitStorage as? AlarmKitDelivery { return existing }
        let created = AlarmKitDelivery(settings: settings)
        kitStorage = created
        return created
    }

    func deliver(_ alarm: GeoAlarm, after delay: TimeInterval) async -> DeliveryOutcome {
        await schedule(alarm, fireDate: Date().addingTimeInterval(max(delay, 1)), delay: delay)
    }

    func scheduleSnooze(_ alarm: GeoAlarm, minutes: Int) async -> DeliveryOutcome {
        let delay = TimeInterval(max(minutes, 1) * 60)
        return await schedule(alarm, fireDate: Date().addingTimeInterval(delay), delay: delay)
    }

    func cancel(alarmID: UUID) {
        if #available(iOS 26.0, *) {
            alarmKit.cancel(alarmID: alarmID)
        }
        fallback.cancel(alarmID: alarmID)
    }

    private func schedule(_ alarm: GeoAlarm, fireDate: Date, delay: TimeInterval) async -> DeliveryOutcome {
        if #available(iOS 26.0, *) {
            if await alarmKit.ensureAuthorized() {
                do {
                    try await alarmKit.schedule(alarm, fireDate: fireDate)
                    return .alarmKit
                } catch {
                    EventLog.shared.add("AlarmKit falhou, usando notificações: \(error.localizedDescription)")
                }
            } else {
                EventLog.shared.add("AlarmKit sem autorização, usando notificações")
            }
        }
        let outcome = await fallback.schedule(alarm, after: delay)
        if case .failed(let reason) = outcome {
            EventLog.shared.add("Nenhuma estratégia de alarme funcionou: \(reason)")
        }
        return outcome
    }
}
