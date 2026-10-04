import SwiftData
import XCTest
@testable import GeoAlarm

@MainActor
final class RepositoryTests: XCTestCase {
    private func makeRepository() throws -> SwiftDataGeoAlarmRepository {
        SwiftDataGeoAlarmRepository(container: try SwiftDataGeoAlarmRepository.makeContainer(inMemory: true))
    }

    private func sample() -> GeoAlarm {
        var alarm = GeoAlarm(title: "Trabalho", coordinate: Coordinate(latitude: -25.43, longitude: -49.27))
        alarm.message = "Desça aqui"
        alarm.radiusMeters = 750
        alarm.transition = .exit
        alarm.activeDays = Weekday.weekdays
        alarm.soundID = "builtin:sino"
        alarm.vibrationPattern = .sos
        alarm.volumeFadeInSeconds = 7
        alarm.snoozeType = .distance
        alarm.snoozeDistanceMeters = 321
        alarm.dismissStyle = .hold
        alarm.showClock = false
        alarm.backgroundColorRGB = 0x112233
        return alarm
    }

    func testSaveAndLoadPreservesEveryField() throws {
        let repo = try makeRepository()
        let alarm = sample()
        try repo.save(alarm)
        let loaded = try XCTUnwrap(repo.get(id: alarm.id))
        XCTAssertEqual(loaded, alarm)
    }

    func testSaveTwiceUpdatesInsteadOfDuplicating() throws {
        let repo = try makeRepository()
        var alarm = sample()
        try repo.save(alarm)
        alarm.title = "Casa"
        try repo.save(alarm)
        let all = try repo.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "Casa")
    }

    func testDeleteRemovesAlarm() throws {
        let repo = try makeRepository()
        let alarm = sample()
        try repo.save(alarm)
        try repo.delete(id: alarm.id)
        XCTAssertNil(try repo.get(id: alarm.id))
        XCTAssertTrue(try repo.all().isEmpty)
    }

    func testSetEnabled() throws {
        let repo = try makeRepository()
        let alarm = sample()
        try repo.save(alarm)
        try repo.setEnabled(id: alarm.id, enabled: false)
        XCTAssertEqual(try repo.get(id: alarm.id)?.isEnabled, false)
    }
}

@MainActor
final class SettingsRepositoryTests: XCTestCase {
    func testPersistsThemeAndAccent() throws {
        let suite = "geoalarm.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = UserDefaultsSettingsRepository(defaults: defaults)
        XCTAssertEqual(first.settings, AppSettings.default)
        first.update { $0.themeMode = .dark; $0.accentColorRGB = 0xAA5500; $0.customSoundInSystemAlert = true }

        let second = UserDefaultsSettingsRepository(defaults: defaults)
        XCTAssertEqual(second.settings.themeMode, .dark)
        XCTAssertEqual(second.settings.accentColorRGB, 0xAA5500)
        XCTAssertTrue(second.settings.customSoundInSystemAlert)
    }
}
