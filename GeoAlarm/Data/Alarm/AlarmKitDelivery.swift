import AlarmKit
import AppIntents
import Foundation
import SwiftUI

/// Metadados anexados a cada alarme do sistema, para sabermos de qual geo-alarme ele veio.
struct GeoAlarmMetadata: AlarmMetadata {
    var alarmID: String
}

/// Entrega o alarme pelo AlarmKit (iOS 26+): o sistema toca mesmo com o iPhone no silencioso,
/// em Foco e com a tela bloqueada, e mostra um alerta próprio na tela de bloqueio.
///
/// O identificador do alarme do sistema é o próprio `GeoAlarm.id`. Assim há no máximo um
/// alarme do sistema por geo-alarme (o toque inicial ou a soneca) e o cancelamento não
/// precisa guardar mapeamentos que se perderiam se o app fosse encerrado.
@available(iOS 26.0, *)
@MainActor
final class AlarmKitDelivery {
    private let manager = AlarmManager.shared
    private let catalog: SoundCatalog
    private let settings: SettingsRepository

    init(catalog: SoundCatalog = .shared, settings: SettingsRepository) {
        self.catalog = catalog
        self.settings = settings
    }

    var authorizationState: AlarmManager.AuthorizationState { manager.authorizationState }

    /// Garante a autorização do usuário, pedindo se ainda não foi pedida.
    func ensureAuthorized() async -> Bool {
        switch manager.authorizationState {
        case .authorized:
            return true
        case .notDetermined:
            do {
                return try await manager.requestAuthorization() == .authorized
            } catch {
                EventLog.shared.add("Erro ao pedir autorização do AlarmKit: \(error.localizedDescription)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func schedule(_ alarm: GeoAlarm, fireDate: Date) async throws {
        // Reagendar com o mesmo id: remove o anterior para evitar duplicidade.
        cancel(alarmID: alarm.id)

        let stopButton = AlarmButton(text: "Dispensar", textColor: .white, systemImageName: "stop.circle")
        var secondaryButton: AlarmButton?
        var secondaryIntent: SnoozeGeoAlarmIntent?
        if alarm.snoozeType != .none {
            secondaryButton = AlarmButton(text: "Soneca", textColor: .white, systemImageName: "zzz")
            secondaryIntent = SnoozeGeoAlarmIntent(alarmID: alarm.id.uuidString)
        }

        // O inicializador com `stopButton` é o único disponível no iOS 26.0; a Apple o marcou
        // como obsoleto a partir do 26.1, mas ele continua funcionando.
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: alarm.displayTitle),
            stopButton: stopButton,
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryButton == nil ? nil : .custom
        )
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: GeoAlarmMetadata(alarmID: alarm.id.uuidString),
            tintColor: Color(rgb: alarm.backgroundColorRGB ?? settings.settings.accentColorRGB)
        )
        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: DismissGeoAlarmIntent(alarmID: alarm.id.uuidString),
            secondaryIntent: secondaryIntent,
            sound: alertSound(for: alarm)
        )
        _ = try await manager.schedule(id: alarm.id, configuration: configuration)
        EventLog.shared.add("AlarmKit: alarme agendado para \(fireDate.formatted(date: .omitted, time: .standard))")
    }

    func cancel(alarmID: UUID) {
        try? manager.stop(id: alarmID)
        try? manager.cancel(id: alarmID)
    }

    private func alertSound(for alarm: GeoAlarm) -> AlertConfiguration.AlertSound {
        guard settings.settings.customSoundInSystemAlert,
              let fileName = catalog.systemSoundFileName(for: SoundReference(id: alarm.soundID)) else {
            return .default
        }
        return .named(fileName)
    }
}
