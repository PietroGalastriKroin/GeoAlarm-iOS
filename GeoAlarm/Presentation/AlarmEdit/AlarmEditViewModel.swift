import Foundation
import Observation

@MainActor
@Observable
final class AlarmEditViewModel {
    var alarm: GeoAlarm
    let isNew: Bool
    var errorMessage: String?
    /// Se o usuário já escolheu (ou herdou da posição atual) um local para o alarme.
    var hasLocation: Bool

    @ObservationIgnored private let saveAlarm: SaveAlarmUseCase
    @ObservationIgnored private var originalBackgroundImage: String?

    convenience init(existing: GeoAlarm?) {
        self.init(existing: existing, container: AppContainer.shared)
    }

    init(existing: GeoAlarm?, container: AppContainer) {
        saveAlarm = container.saveAlarm
        if let existing {
            alarm = existing
            isNew = false
            hasLocation = true
            originalBackgroundImage = existing.backgroundImageFileName
        } else {
            let start = container.location.lastKnown
            alarm = GeoAlarm(title: "", coordinate: start ?? Coordinate(latitude: -15.7939, longitude: -47.8828))
            isNew = true
            hasLocation = start != nil
        }
    }

    var canSave: Bool {
        hasLocation && alarm.coordinate.isValid && !alarm.activeDays.isEmpty
    }

    var saveBlockedReason: String? {
        if !hasLocation { return "Escolha um local para o alarme." }
        if !alarm.coordinate.isValid { return "Coordenadas inválidas." }
        if alarm.activeDays.isEmpty { return "Selecione pelo menos um dia da semana." }
        return nil
    }

    func save() -> Bool {
        guard canSave else {
            errorMessage = saveBlockedReason
            return false
        }
        alarm.radiusMeters = alarm.effectiveRadiusMeters
        do {
            try saveAlarm(alarm)
            // Se a imagem de fundo foi trocada ou removida, apaga o arquivo antigo.
            if let old = originalBackgroundImage, old != alarm.backgroundImageFileName {
                BackgroundImageStore.delete(old)
            }
            return true
        } catch {
            errorMessage = "Não foi possível salvar: \(error.localizedDescription)"
            return false
        }
    }

    func setBackgroundImage(_ data: Data) {
        do {
            let previous = alarm.backgroundImageFileName
            alarm.backgroundImageFileName = try BackgroundImageStore.save(data)
            // Arquivo recém-criado numa edição anterior ainda não salva: descarta.
            if let previous, previous != originalBackgroundImage { BackgroundImageStore.delete(previous) }
        } catch {
            errorMessage = "Não foi possível usar esta imagem."
        }
    }

    /// Ao cancelar a edição, descarta uma imagem de fundo que foi escolhida mas não salva.
    func clearBackgroundImageIfUnsaved() {
        if let current = alarm.backgroundImageFileName, current != originalBackgroundImage {
            BackgroundImageStore.delete(current)
        }
    }

    func clearBackgroundImage() {
        if let current = alarm.backgroundImageFileName, current != originalBackgroundImage {
            BackgroundImageStore.delete(current)
        }
        alarm.backgroundImageFileName = nil
    }
}
