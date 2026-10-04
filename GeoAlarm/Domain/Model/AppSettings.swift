import Foundation

struct AppSettings: Equatable, Sendable {
    var themeMode: ThemeMode = .system
    /// Cor de destaque no formato 0xRRGGBB. Todas as cores da interface derivam dela.
    var accentColorRGB: Int = 0x3B6EF6
    /// Experimental: usa o som escolhido (em vez do padrão do sistema) no alerta do AlarmKit.
    /// Desligado por padrão, porque se o sistema não achar o arquivo o alarme pode ficar mudo.
    var customSoundInSystemAlert: Bool = false

    static let `default` = AppSettings()
}
