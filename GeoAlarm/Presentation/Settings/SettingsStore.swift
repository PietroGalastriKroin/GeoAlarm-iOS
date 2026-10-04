import Foundation
import Observation

/// Estado observável das configurações do app (tema, cor de destaque), lido pela raiz da
/// interface para recalcular as cores de tudo quando algo muda.
@MainActor
@Observable
final class SettingsStore {
    private(set) var settings: AppSettings
    @ObservationIgnored private let repository: SettingsRepository

    init(repository: SettingsRepository) {
        self.repository = repository
        self.settings = repository.settings
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        repository.update(transform)
        settings = repository.settings
    }
}
