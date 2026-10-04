import CoreHaptics
import Foundation
import UIKit

/// Toca os padrões de vibração em loop com CoreHaptics. Em aparelhos sem Taptic Engine
/// avançado (ou se o motor falhar), cai para `UINotificationFeedbackGenerator` em intervalos.
@MainActor
final class HapticPlayer {
    private var engine: CHHapticEngine?
    private var loopPlayer: CHHapticAdvancedPatternPlayer?
    private var fallbackTask: Task<Void, Never>?
    private var currentPattern: VibrationPattern = .none

    var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    func start(_ pattern: VibrationPattern) {
        stop()
        guard pattern != .none else { return }
        currentPattern = pattern

        guard isSupported, startEngine(pattern) else {
            startFallback(pattern)
            return
        }
    }

    func stop() {
        fallbackTask?.cancel()
        fallbackTask = nil
        try? loopPlayer?.stop(atTime: CHHapticTimeImmediate)
        loopPlayer = nil
        engine?.stop(completionHandler: nil)
        engine = nil
        currentPattern = .none
    }

    // MARK: CoreHaptics

    private func startEngine(_ pattern: VibrationPattern) -> Bool {
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = false
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    guard let self, self.currentPattern != .none else { return }
                    _ = self.startEngine(self.currentPattern)
                }
            }
            try engine.start()

            let segments = VibrationTimeline.segments(for: pattern)
            var events: [CHHapticEvent] = []
            var cursor = 0.0
            for segment in segments {
                let duration = Double(segment.durationMs) / 1000
                if !segment.isPause {
                    events.append(CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(segment.intensity)),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                        ],
                        relativeTime: cursor,
                        duration: duration
                    ))
                }
                cursor += duration
            }

            let hapticPattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: hapticPattern)
            player.loopEnabled = true
            player.loopEnd = cursor   // inclui a pausa final do padrão no ciclo
            try player.start(atTime: CHHapticTimeImmediate)
            self.engine = engine
            self.loopPlayer = player
            return true
        } catch {
            EventLog.shared.add("CoreHaptics indisponível: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Fallback

    private func startFallback(_ pattern: VibrationPattern) {
        let segments = VibrationTimeline.segments(for: pattern)
        fallbackTask = Task { [weak self] in
            let generator = UINotificationFeedbackGenerator()
            while !Task.isCancelled {
                for segment in segments {
                    if Task.isCancelled { return }
                    if !segment.isPause { generator.notificationOccurred(.warning) }
                    try? await Task.sleep(nanoseconds: UInt64(segment.durationMs) * 1_000_000)
                }
            }
            _ = self
        }
    }
}
