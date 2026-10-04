import SwiftUI
import UIKit

/// Tela cheia do alarme: título, mensagem, hora, distância e o controle de descarte escolhido.
/// Aparece com o app aberto (o iOS não permite tela customizada sobre a tela de bloqueio).
struct AlarmTriggerView: View {
    let alarm: GeoAlarm
    let distanceMeters: Double?
    let isPreview: Bool
    let onDismiss: () -> Void
    /// `nil` quando o alarme não tem soneca.
    let onSnooze: (() -> Void)?

    @Environment(\.palette) private var palette
    @State private var pulse = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 18) {
                if isPreview {
                    Text("PRÉ-VISUALIZAÇÃO")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.35), in: Capsule())
                }

                Spacer(minLength: 20)

                if alarm.showClock {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(context.date.formatted(.dateTime.hour().minute()))
                            .font(.system(size: 76, weight: .thin, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                }

                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 54))
                    .symbolEffect(.pulse, isActive: pulse)
                    .padding(.top, 4)

                Text(alarm.displayTitle)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)

                if !alarm.message.isEmpty {
                    Text(alarm.message)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .opacity(0.9)
                }

                if alarm.showDistance {
                    Group {
                        if let distanceMeters {
                            Label("A \(Geo.formatDistance(distanceMeters)) do ponto", systemImage: "location")
                        } else {
                            Label("Calculando distância…", systemImage: "location")
                        }
                    }
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.25), in: Capsule())
                }

                Spacer(minLength: 20)

                if let onSnooze {
                    Button(action: onSnooze) {
                        Text(snoozeTitle)
                            .font(.headline)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                dismissControl
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .foregroundStyle(foreground)
        }
        .onAppear { pulse = true }
    }

    // MARK: Fundo e cores

    private var backgroundColor: Color {
        Color(rgb: alarm.backgroundColorRGB ?? 0x1C3FA8)
    }

    private var hasImage: Bool {
        alarm.backgroundImageFileName.flatMap(BackgroundImageStore.load) != nil
    }

    private var foreground: Color {
        hasImage ? .white : Palette.contrastingText(on: UIColor(backgroundColor))
    }

    @ViewBuilder
    private var background: some View {
        if let name = alarm.backgroundImageFileName, let image = BackgroundImageStore.load(name) {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.4))
            }
            .ignoresSafeArea()
        } else {
            LinearGradient(colors: [backgroundColor, backgroundColor.opacity(0.78)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }

    private var snoozeTitle: String {
        switch alarm.snoozeType {
        case .time: return "Soneca · \(alarm.snoozeMinutes) min"
        case .distance: return "Soneca · até \(Geo.formatDistance(alarm.snoozeDistanceMeters))"
        case .none: return "Soneca"
        }
    }

    // MARK: Descarte

    @ViewBuilder
    private var dismissControl: some View {
        switch alarm.dismissStyle {
        case .button:
            Button(action: onDismiss) {
                Text("Dispensar")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(foreground, in: Capsule())
                    .foregroundStyle(hasImage ? .black : backgroundColor)
            }
            .buttonStyle(.plain)
        case .swipe:
            SlideToDismiss(foreground: foreground, knobTint: hasImage ? .black : backgroundColor, onComplete: onDismiss)
        case .hold:
            HoldToDismiss(foreground: foreground, onComplete: onDismiss)
        }
    }
}

/// Arraste o botão até o fim para dispensar.
private struct SlideToDismiss: View {
    let foreground: Color
    let knobTint: Color
    let onComplete: () -> Void

    @State private var offset: CGFloat = 0
    private let knob: CGFloat = 58

    var body: some View {
        GeometryReader { geo in
            let travel = geo.size.width - knob - 8
            ZStack(alignment: .leading) {
                Capsule().fill(foreground.opacity(0.22))
                Text("Arraste para dispensar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, knob)
                    .opacity(1 - Double(offset / max(travel, 1)))
                Circle()
                    .fill(foreground)
                    .overlay(Image(systemName: "chevron.right").font(.title3.weight(.bold)).foregroundStyle(knobTint))
                    .frame(width: knob, height: knob)
                    .padding(4)
                    .offset(x: offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = min(max(0, value.translation.width), travel)
                            }
                            .onEnded { _ in
                                if offset >= travel * 0.85 {
                                    offset = travel
                                    onComplete()
                                } else {
                                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                                }
                            }
                    )
            }
        }
        .frame(height: knob + 8)
    }
}

/// Segure o botão por 3 segundos para dispensar. Soltar antes zera o progresso.
private struct HoldToDismiss: View {
    let foreground: Color
    let onComplete: () -> Void

    private static let duration: Double = 3
    @State private var progress: CGFloat = 0
    @State private var completed = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(foreground.opacity(0.25), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(foreground, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "hand.tap.fill").font(.system(size: 34))
            }
            .frame(width: 104, height: 104)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: Self.duration, maximumDistance: 80) {
                completed = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
            } onPressingChanged: { pressing in
                guard !completed else { return }
                if pressing {
                    withAnimation(.linear(duration: Self.duration)) { progress = 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
                }
            }
            Text("Segure por 3 segundos para dispensar")
                .font(.subheadline.weight(.medium))
        }
    }
}
