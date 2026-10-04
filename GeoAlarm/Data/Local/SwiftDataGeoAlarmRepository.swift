import Foundation
import SwiftData

@MainActor
final class SwiftDataGeoAlarmRepository: GeoAlarmRepository {
    /// O contexto não mantém o container vivo: se este for liberado, qualquer acesso ao
    /// contexto causa um trap. Por isso o repositório guarda o container junto.
    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        self.context = container.mainContext
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: GeoAlarmRecord.self, configurations: configuration)
    }

    func all() throws -> [GeoAlarm] {
        try context.fetch(FetchDescriptor<GeoAlarmRecord>()).map(\.domain)
    }

    func get(id: UUID) throws -> GeoAlarm? {
        try record(id: id)?.domain
    }

    func save(_ alarm: GeoAlarm) throws {
        if let existing = try record(id: alarm.id) {
            existing.apply(alarm)
        } else {
            context.insert(GeoAlarmRecord(alarm))
        }
        try context.save()
    }

    func delete(id: UUID) throws {
        if let existing = try record(id: id) {
            context.delete(existing)
            try context.save()
        }
    }

    func setEnabled(id: UUID, enabled: Bool) throws {
        guard let existing = try record(id: id) else { return }
        existing.isEnabled = enabled
        try context.save()
    }

    private func record(id: UUID) throws -> GeoAlarmRecord? {
        var descriptor = FetchDescriptor<GeoAlarmRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
