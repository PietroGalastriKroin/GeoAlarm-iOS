import Foundation

/// Sons embutidos no app e sons importados pelo usuário.
///
/// O iOS não expõe a biblioteca de toques do sistema a apps de terceiros (ao contrário do
/// `RingtoneManager` do Android), então o app traz alguns sons próprios e permite importar
/// áudio do aparelho. Os importados são copiados para `Library/Sounds`, a única pasta
/// (além do bundle) de onde o sistema aceita tocar sons de notificação/alarme.
/// Sem estado mutável, então pode ser usado de qualquer contexto de execução.
final class SoundCatalog {
    struct BuiltInSound: Identifiable, Equatable {
        let name: String        // identificador estável: "alvorada"
        let displayName: String // "Alvorada"
        var id: String { name }
        var fileName: String { "\(name).wav" }
    }

    static let shared = SoundCatalog()

    let builtIn: [BuiltInSound] = [
        .init(name: "alvorada", displayName: "Alvorada"),
        .init(name: "sirene", displayName: "Sirene"),
        .init(name: "bip_classico", displayName: "Bip clássico"),
        .init(name: "sino", displayName: "Sino"),
        .init(name: "radar", displayName: "Radar"),
        .init(name: "pulso", displayName: "Pulso"),
    ]

    private let fileManager = FileManager.default

    /// Pasta `Library/Sounds` do app (criada sob demanda).
    var importedSoundsDirectory: URL {
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let dir = library.appendingPathComponent("Sounds", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func displayName(for reference: SoundReference) -> String {
        switch reference {
        case .systemDefault:
            return "Padrão"
        case .builtIn(let name):
            return builtIn.first { $0.name == name }?.displayName ?? name
        case .imported(let file):
            // O arquivo é salvo como "<uuid>__<nome original>"; mostramos só o nome original.
            return file.components(separatedBy: "__").last.map { ($0 as NSString).deletingPathExtension } ?? file
        }
    }

    /// URL do arquivo de áudio para tocar dentro do app. O "Padrão" usa o primeiro som embutido.
    func url(for reference: SoundReference) -> URL? {
        switch reference {
        case .systemDefault:
            return bundleURL(for: builtIn[0])
        case .builtIn(let name):
            guard let sound = builtIn.first(where: { $0.name == name }) else { return bundleURL(for: builtIn[0]) }
            return bundleURL(for: sound)
        case .imported(let file):
            let url = importedSoundsDirectory.appendingPathComponent(file)
            return fileManager.fileExists(atPath: url.path) ? url : bundleURL(for: builtIn[0])
        }
    }

    /// Nome de arquivo que o sistema (notificações/AlarmKit) usa para localizar o som no bundle
    /// ou em `Library/Sounds`. `nil` significa "som padrão do sistema".
    func systemSoundFileName(for reference: SoundReference) -> String? {
        switch reference {
        case .systemDefault:
            return nil
        case .builtIn(let name):
            return builtIn.first { $0.name == name }?.fileName
        case .imported(let file):
            return fileManager.fileExists(atPath: importedSoundsDirectory.appendingPathComponent(file).path) ? file : nil
        }
    }

    /// Copia um áudio escolhido pelo usuário (seletor de documentos) para `Library/Sounds`.
    func importSound(from source: URL) throws -> SoundReference {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let safeName = source.lastPathComponent.replacingOccurrences(of: "/", with: "_")
        let stored = "\(UUID().uuidString.prefix(8))__\(safeName)"
        let destination = importedSoundsDirectory.appendingPathComponent(stored)
        try fileManager.copyItem(at: source, to: destination)
        return .imported(stored)
    }

    func deleteImportedSound(_ reference: SoundReference) {
        guard case .imported(let file) = reference else { return }
        try? fileManager.removeItem(at: importedSoundsDirectory.appendingPathComponent(file))
    }

    private func bundleURL(for sound: BuiltInSound) -> URL? {
        Bundle.main.url(forResource: sound.name, withExtension: "wav")
    }
}
