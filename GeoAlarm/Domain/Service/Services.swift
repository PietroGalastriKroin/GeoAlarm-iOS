import Foundation

/// Mantém o conjunto de regiões monitoradas pelo sistema alinhado com os alarmes.
@MainActor
protocol GeofenceMonitoring: AnyObject {
    /// IDs dos alarmes que estão sendo monitorados agora (no máximo 20).
    var monitoredAlarmIDs: Set<UUID> { get }
    /// Recalcula e aplica o conjunto de regiões. Deve ser chamado após qualquer mudança.
    func sync(alarms: [GeoAlarm])
}

enum DeliveryOutcome: Equatable, Sendable {
    /// Alarme agendado pelo sistema (AlarmKit): toca com tela bloqueada e no silencioso.
    case alarmKit
    /// Notificações locais em cadeia (sem AlarmKit disponível ou autorizado).
    case notificationFallback
    case failed(String)
}

/// Estratégia de entrega do alarme fora do app. É aqui que Critical Alerts ou CallKit
/// poderiam entrar no futuro sem tocar no resto do código.
@MainActor
protocol AlarmDelivering: AnyObject {
    /// Faz o alarme tocar `delay` segundos a partir de agora.
    func deliver(_ alarm: GeoAlarm, after delay: TimeInterval) async -> DeliveryOutcome
    /// Agenda um novo toque daqui a `minutes` minutos (soneca por tempo).
    func scheduleSnooze(_ alarm: GeoAlarm, minutes: Int) async -> DeliveryOutcome
    /// Cancela tudo que estiver agendado ou tocando para este alarme.
    func cancel(alarmID: UUID)
}

@MainActor
protocol LocationProviding: AnyObject {
    /// Última posição conhecida, sem custo.
    var lastKnown: Coordinate? { get }
    /// Pede uma posição nova (com timeout curto). Retorna `lastKnown` se falhar.
    func currentLocation() async -> Coordinate?
}
