import Foundation

/// Um trecho de uma vibração: `intensity` 0 significa pausa.
struct VibrationSegment: Equatable, Sendable {
    let durationMs: Int
    let intensity: Double

    var isPause: Bool { intensity <= 0 }
}

/// Descrição pura (sem CoreHaptics) de cada padrão. O padrão inteiro se repete em loop
/// enquanto o alarme toca. A camada Data converte isso em `CHHapticPattern`.
enum VibrationTimeline {
    static func segments(for pattern: VibrationPattern) -> [VibrationSegment] {
        switch pattern {
        case .none:
            return []
        case .continuous:
            return [.init(durationMs: 1000, intensity: 1), .init(durationMs: 500, intensity: 0)]
        case .shortPulse:
            return [.init(durationMs: 150, intensity: 1), .init(durationMs: 150, intensity: 0)]
        case .sos:
            // "···  −−−  ···" em código Morse, com pausa maior entre as letras.
            let dot = [VibrationSegment(durationMs: 150, intensity: 1), .init(durationMs: 150, intensity: 0)]
            let dash = [VibrationSegment(durationMs: 400, intensity: 1), .init(durationMs: 150, intensity: 0)]
            let letterGap = [VibrationSegment(durationMs: 250, intensity: 0)]
            return Array(dot.repeating(3)) + letterGap
                + Array(dash.repeating(3)) + letterGap
                + Array(dot.repeating(3)) + [.init(durationMs: 700, intensity: 0)]
        case .heartbeat:
            return [
                .init(durationMs: 120, intensity: 0.8),
                .init(durationMs: 120, intensity: 0),
                .init(durationMs: 180, intensity: 1),
                .init(durationMs: 700, intensity: 0),
            ]
        }
    }

    static func totalDurationMs(for pattern: VibrationPattern) -> Int {
        segments(for: pattern).reduce(0) { $0 + $1.durationMs }
    }
}

private extension Array {
    func repeating(_ count: Int) -> [Element] {
        Array([[Element]](repeating: self, count: count).joined())
    }
}
