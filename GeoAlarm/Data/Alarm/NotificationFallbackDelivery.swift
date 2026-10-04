import Foundation
import UserNotifications

/// Plano B quando o AlarmKit não está disponível ou autorizado (iOS < 26 ou permissão negada):
/// uma cadeia de notificações locais, cada uma com o som do alarme. Um som de notificação
/// toca no máximo ~30 s e não repete, então encadeamos várias para simular um toque contínuo.
/// Limitação real: notificações respeitam o botão de silencioso e o modo Foco.
@MainActor
final class NotificationFallbackDelivery {
    static let categoryID = "geoalarm.ringing"
    static let snoozeActionID = "geoalarm.snooze"
    static let dismissActionID = "geoalarm.dismiss"

    /// 10 notificações, uma a cada 12 s: cerca de 2 minutos de toque.
    private static let chainLength = 10
    private static let chainInterval: TimeInterval = 12

    private let center = UNUserNotificationCenter.current()
    private let catalog: SoundCatalog

    init(catalog: SoundCatalog = .shared) {
        self.catalog = catalog
    }

    func registerCategories() {
        let dismiss = UNNotificationAction(identifier: Self.dismissActionID, title: "Dispensar", options: [.destructive])
        let snooze = UNNotificationAction(identifier: Self.snoozeActionID, title: "Soneca", options: [])
        let category = UNNotificationCategory(identifier: Self.categoryID,
                                              actions: [dismiss, snooze],
                                              intentIdentifiers: [],
                                              options: [])
        center.setNotificationCategories([category])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func ensureAuthorized() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    func schedule(_ alarm: GeoAlarm, after delay: TimeInterval) async -> DeliveryOutcome {
        guard await ensureAuthorized() else { return .failed("Notificações não autorizadas") }
        cancel(alarmID: alarm.id)

        let reference = SoundReference(id: alarm.soundID)
        for index in 0..<Self.chainLength {
            let content = UNMutableNotificationContent()
            content.title = alarm.displayTitle
            content.body = alarm.message.isEmpty ? "Você chegou ao destino." : alarm.message
            content.categoryIdentifier = Self.categoryID
            content.userInfo = ["alarmID": alarm.id.uuidString]
            content.interruptionLevel = .timeSensitive
            if alarm.soundEnabled {
                if let file = catalog.systemSoundFileName(for: reference) {
                    content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: file))
                } else {
                    content.sound = .default
                }
            }
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(delay, 1) + Double(index) * Self.chainInterval, repeats: false)
            let request = UNNotificationRequest(identifier: identifier(alarm.id, index), content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                return .failed(error.localizedDescription)
            }
        }
        EventLog.shared.add("Notificações em cadeia agendadas (\(Self.chainLength))")
        return .notificationFallback
    }

    func cancel(alarmID: UUID) {
        let ids = (0..<Self.chainLength).map { identifier(alarmID, $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func identifier(_ alarmID: UUID, _ index: Int) -> String {
        "\(alarmID.uuidString)#\(index)"
    }
}
