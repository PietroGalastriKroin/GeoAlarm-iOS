import Foundation
import UIKit

/// Guarda as imagens de fundo da tela de alarme em Application Support/Backgrounds.
/// O alarme só guarda o nome do arquivo, nunca os bytes.
enum BackgroundImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Backgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Redimensiona (lado maior até 1600 px) e salva como JPEG. Retorna o nome do arquivo.
    static func save(_ data: Data) throws -> String {
        guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { throw CocoaError(.fileWriteUnknown) }
        let name = "\(UUID().uuidString).jpg"
        try jpeg.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }

    static func load(_ fileName: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    static func delete(_ fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
