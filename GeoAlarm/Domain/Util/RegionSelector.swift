import Foundation

/// O iOS monitora no máximo 20 regiões por app. Quando há mais alarmes ativos, escolhemos
/// os que estão mais perto da posição atual (distância até a borda da área) e trocamos o
/// conjunto conforme o usuário se move.
enum RegionSelector {
    static let systemLimit = 20

    /// Alarmes que devem estar monitorados agora, do mais próximo para o mais distante.
    /// - Parameters:
    ///   - alarms: todos os alarmes (os desligados são ignorados).
    ///   - current: posição atual; se for `nil`, mantém a ordem recebida.
    ///   - limit: capacidade disponível (por padrão, o limite do sistema).
    static func select(from alarms: [GeoAlarm],
                       around current: Coordinate?,
                       limit: Int = systemLimit) -> [GeoAlarm] {
        // Só vale a pena monitorar o que está ligado; os dias da semana são conferidos no
        // disparo (um alarme de segunda não deve sumir do monitoramento na terça).
        let enabled = alarms.filter(\.isEnabled)
        guard let current else { return Array(enabled.prefix(limit)) }

        let ranked = enabled
            .map { alarm -> (GeoAlarm, Double) in
                let edge = Geo.distanceMeters(from: alarm.coordinate, to: current) - alarm.effectiveRadiusMeters
                return (alarm, edge)
            }
            .sorted { $0.1 < $1.1 }
        return ranked.prefix(limit).map(\.0)
    }
}
