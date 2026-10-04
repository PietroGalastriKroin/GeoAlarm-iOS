import Foundation
import SwiftData

/// Registro SwiftData de um `GeoAlarm`. Enums e conjuntos viram tipos simples para que o
/// esquema continue estável se novos casos forem adicionados no futuro.
@Model
final class GeoAlarmRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var message: String
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
    var transitionRaw: String
    var isEnabled: Bool
    var activeDays: [Int]
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    var soundID: String
    var vibrationPatternRaw: String
    var volumeFadeInSeconds: Int
    var snoozeTypeRaw: String
    var snoozeMinutes: Int
    var snoozeDistanceMeters: Double
    var dismissStyleRaw: String
    var showClock: Bool
    var showDistance: Bool
    var backgroundColorRGB: Int?
    var backgroundImageFileName: String?
    var createdAt: Date

    init(_ alarm: GeoAlarm) {
        self.id = alarm.id
        self.title = alarm.title
        self.message = alarm.message
        self.latitude = alarm.coordinate.latitude
        self.longitude = alarm.coordinate.longitude
        self.radiusMeters = alarm.radiusMeters
        self.transitionRaw = alarm.transition.rawValue
        self.isEnabled = alarm.isEnabled
        self.activeDays = alarm.activeDays.map(\.rawValue).sorted()
        self.soundEnabled = alarm.soundEnabled
        self.vibrationEnabled = alarm.vibrationEnabled
        self.soundID = alarm.soundID
        self.vibrationPatternRaw = alarm.vibrationPattern.rawValue
        self.volumeFadeInSeconds = alarm.volumeFadeInSeconds
        self.snoozeTypeRaw = alarm.snoozeType.rawValue
        self.snoozeMinutes = alarm.snoozeMinutes
        self.snoozeDistanceMeters = alarm.snoozeDistanceMeters
        self.dismissStyleRaw = alarm.dismissStyle.rawValue
        self.showClock = alarm.showClock
        self.showDistance = alarm.showDistance
        self.backgroundColorRGB = alarm.backgroundColorRGB
        self.backgroundImageFileName = alarm.backgroundImageFileName
        self.createdAt = Date()
    }

    /// Copia todos os campos do domínio para este registro (usado na edição).
    func apply(_ alarm: GeoAlarm) {
        title = alarm.title
        message = alarm.message
        latitude = alarm.coordinate.latitude
        longitude = alarm.coordinate.longitude
        radiusMeters = alarm.radiusMeters
        transitionRaw = alarm.transition.rawValue
        isEnabled = alarm.isEnabled
        activeDays = alarm.activeDays.map(\.rawValue).sorted()
        soundEnabled = alarm.soundEnabled
        vibrationEnabled = alarm.vibrationEnabled
        soundID = alarm.soundID
        vibrationPatternRaw = alarm.vibrationPattern.rawValue
        volumeFadeInSeconds = alarm.volumeFadeInSeconds
        snoozeTypeRaw = alarm.snoozeType.rawValue
        snoozeMinutes = alarm.snoozeMinutes
        snoozeDistanceMeters = alarm.snoozeDistanceMeters
        dismissStyleRaw = alarm.dismissStyle.rawValue
        showClock = alarm.showClock
        showDistance = alarm.showDistance
        backgroundColorRGB = alarm.backgroundColorRGB
        backgroundImageFileName = alarm.backgroundImageFileName
    }

    var domain: GeoAlarm {
        GeoAlarm(
            id: id,
            title: title,
            message: message,
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            radiusMeters: radiusMeters,
            transition: GeofenceTransition(rawValue: transitionRaw) ?? .enter,
            isEnabled: isEnabled,
            activeDays: Set(activeDays.compactMap(Weekday.init(rawValue:))),
            soundEnabled: soundEnabled,
            vibrationEnabled: vibrationEnabled,
            soundID: soundID,
            vibrationPattern: VibrationPattern(rawValue: vibrationPatternRaw) ?? .continuous,
            volumeFadeInSeconds: volumeFadeInSeconds,
            snoozeType: SnoozeType(rawValue: snoozeTypeRaw) ?? .time,
            snoozeMinutes: snoozeMinutes,
            snoozeDistanceMeters: snoozeDistanceMeters,
            dismissStyle: DismissStyle(rawValue: dismissStyleRaw) ?? .swipe,
            showClock: showClock,
            showDistance: showDistance,
            backgroundColorRGB: backgroundColorRGB,
            backgroundImageFileName: backgroundImageFileName
        )
    }
}
