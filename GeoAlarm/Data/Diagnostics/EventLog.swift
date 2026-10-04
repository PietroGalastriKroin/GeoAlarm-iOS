import Foundation
import Observation

/// Registro curto e persistente dos eventos de geofencing e de alarme. Existe para o usuário
/// (e para quem for depurar) saber o que aconteceu com o app fechado, já que no iOS não há
/// como anexar um depurador a um disparo em segundo plano.
@MainActor
@Observable
final class EventLog {
    struct Entry: Identifiable, Codable, Equatable {
        var id = UUID()
        var date: Date
        var text: String
    }

    static let shared = EventLog()

    private static let storageKey = "diagnostics.eventLog"
    private static let capacity = 80

    private(set) var entries: [Entry] = []

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([Entry].self, from: data) {
            entries = decoded
        }
    }

    func add(_ text: String) {
        entries.insert(Entry(date: Date(), text: text), at: 0)
        if entries.count > Self.capacity {
            entries.removeLast(entries.count - Self.capacity)
        }
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: Self.storageKey)
    }
}
