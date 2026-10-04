import SwiftUI
import UIKit

extension Color {
    /// Cria uma cor a partir de um inteiro 0xRRGGBB.
    init(rgb: Int) {
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    /// Converte para 0xRRGGBB (ignora transparência).
    var rgbValue: Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int((r * 255).rounded()), gi = Int((g * 255).rounded()), bi = Int((b * 255).rounded())
        return (ri << 16) | (gi << 8) | bi
    }
}
