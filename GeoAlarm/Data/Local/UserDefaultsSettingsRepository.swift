import Foundation

@MainActor
final class UserDefaultsSettingsRepository: SettingsRepository {
    private enum Key {
        static let theme = "settings.themeMode"
        static let accent = "settings.accentColorRGB"
        static let customSystemSound = "settings.customSoundInSystemAlert"
    }

    private let defaults: UserDefaults
    private(set) var settings: AppSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded = AppSettings.default
        if let raw = defaults.string(forKey: Key.theme), let mode = ThemeMode(rawValue: raw) {
            loaded.themeMode = mode
        }
        if defaults.object(forKey: Key.accent) != nil {
            loaded.accentColorRGB = defaults.integer(forKey: Key.accent)
        }
        loaded.customSoundInSystemAlert = defaults.bool(forKey: Key.customSystemSound)
        self.settings = loaded
    }

    func update(_ transform: (inout AppSettings) -> Void) {
        var copy = settings
        transform(&copy)
        settings = copy
        defaults.set(copy.themeMode.rawValue, forKey: Key.theme)
        defaults.set(copy.accentColorRGB, forKey: Key.accent)
        defaults.set(copy.customSoundInSystemAlert, forKey: Key.customSystemSound)
    }
}
