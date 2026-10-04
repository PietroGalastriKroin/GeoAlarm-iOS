import SwiftUI
import UIKit

/// Conjunto de cores da interface, derivado inteiramente da cor de destaque escolhida e do
/// esquema (claro/escuro). É o equivalente, usando cores nativas do SwiftUI, ao "dynamic
/// color" do Material 3 do app Android: mudar a cor de destaque recalcula tudo.
struct Palette: Equatable {
    let accent: Color
    let onAccent: Color
    /// Fundo de telas (levemente tingido com o matiz do destaque).
    let background: Color
    /// Fundo de cartões e linhas de lista.
    let surface: Color
    /// Fundo de chips e elementos selecionados.
    let accentSoft: Color
    let onAccentSoft: Color

    init(accentRGB: Int, scheme: ColorScheme) {
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        UIColor(Color(rgb: accentRGB)).getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)
        let dark = scheme == .dark

        // No escuro, o destaque precisa ser mais claro para manter contraste sobre fundo escuro.
        let accentColor = dark
            ? Color(hue: hue, saturation: min(sat, 0.75), brightness: max(bri, 0.9))
            : Color(hue: hue, saturation: sat, brightness: min(bri, 0.92))
        accent = accentColor
        onAccent = Palette.contrastingText(on: UIColor(accentColor))

        background = dark
            ? Color(hue: hue, saturation: 0.30, brightness: 0.09)
            : Color(hue: hue, saturation: 0.05, brightness: 0.97)
        surface = dark
            ? Color(hue: hue, saturation: 0.28, brightness: 0.16)
            : Color(hue: hue, saturation: 0.02, brightness: 1.0)
        let soft = dark
            ? Color(hue: hue, saturation: 0.55, brightness: 0.34)
            : Color(hue: hue, saturation: 0.16, brightness: 1.0)
        accentSoft = soft
        onAccentSoft = Palette.contrastingText(on: UIColor(soft))
    }

    /// Preto ou branco, o que tiver mais contraste (luminância relativa WCAG).
    static func contrastingText(on color: UIColor) -> Color {
        prefersLightText(on: color) ? Color.white : Color.black
    }

    /// `true` quando o fundo é escuro o bastante para pedir texto claro.
    static func prefersLightText(on color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        return luminance <= 0.4
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette(accentRGB: 0x3B6EF6, scheme: .light)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

/// Aplica tema (claro/escuro/automático), cor de destaque e paleta derivada a toda a árvore.
struct ThemedRoot<Content: View>: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.colorScheme) private var systemScheme
    @ViewBuilder var content: () -> Content

    var body: some View {
        let mode = settings.settings.themeMode
        let scheme: ColorScheme = switch mode {
        case .light: .light
        case .dark: .dark
        case .system: systemScheme
        }
        let preferred: ColorScheme? = switch mode {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
        let palette = Palette(accentRGB: settings.settings.accentColorRGB, scheme: scheme)
        content()
            .environment(\.palette, palette)
            .tint(palette.accent)
            .preferredColorScheme(preferred)
    }
}
