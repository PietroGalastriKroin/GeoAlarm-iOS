import Foundation
import UserNotifications

/// Trata as notificações do plano B (cadeia de notificações) e seus botões.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Com o app aberto o alarme já aparece na tela própria; não duplica com banner/som.
        let alarmID = notification.request.content.userInfo["alarmID"] as? String
        let handled: Bool = await MainActor.run {
            guard let alarmID, let id = UUID(uuidString: alarmID) else { return false }
            let container = AppContainer.shared
            if container.coordinator.activeAlarm?.id == id { return true }
            if container.isAppActive() {
                // Notificação chegou com o app aberto e sem tela de alarme: abre a tela.
                container.coordinator.openFromNotification(alarmID: id)
                return true
            }
            return false
        }
        return handled ? [] : [.banner, .sound, .list]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let alarmID = response.notification.request.content.userInfo["alarmID"] as? String,
              let id = UUID(uuidString: alarmID) else { return }
        await MainActor.run {
            AppContainer.shared.delivery.cancel(alarmID: id)
        }
        switch response.actionIdentifier {
        case NotificationFallbackDelivery.snoozeActionID:
            await AppContainer.shared.coordinator.snoozeFromSystem(alarmID: alarmID)
        case NotificationFallbackDelivery.dismissActionID:
            await MainActor.run { AppContainer.shared.coordinator.dismissFromSystem(alarmID: alarmID) }
        default:
            await MainActor.run { AppContainer.shared.coordinator.openFromNotification(alarmID: id) }
        }
    }
}
