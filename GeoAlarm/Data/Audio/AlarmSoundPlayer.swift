import AVFoundation
import Foundation
import UIKit

/// Toca o som do alarme dentro do app, em loop, com volume crescente (fade-in).
/// Usa a categoria `.playback`, que ignora o botão de silencioso enquanto o app está ativo.
@MainActor
final class AlarmSoundPlayer {
    private var player: AVAudioPlayer?
    private let catalog: SoundCatalog

    init(catalog: SoundCatalog = .shared) {
        self.catalog = catalog
    }

    var isPlaying: Bool { player?.isPlaying ?? false }

    func start(soundID: String, fadeInSeconds: Int) {
        stop()
        guard let url = catalog.url(for: SoundReference(id: soundID)) else {
            EventLog.shared.add("Som não encontrado: \(soundID)")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.prepareToPlay()
            if fadeInSeconds > 0 {
                player.volume = 0.05
                player.play()
                player.setVolume(1.0, fadeDuration: TimeInterval(fadeInSeconds))
            } else {
                player.volume = 1.0
                player.play()
            }
            self.player = player
        } catch {
            EventLog.shared.add("Falha ao tocar som: \(error.localizedDescription)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
