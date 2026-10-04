import XCTest
@testable import GeoAlarm

final class GeoTests: XCTestCase {
    func testOneDegreeOfLatitudeIsAbout111Km() {
        let d = Geo.distanceMeters(from: Coordinate(latitude: 0, longitude: 0),
                                   to: Coordinate(latitude: 1, longitude: 0))
        XCTAssertEqual(d, 111_195, accuracy: 200)
    }

    func testSaoPauloToRioIsAbout357Km() {
        let sp = Coordinate(latitude: -23.5505, longitude: -46.6333)
        let rio = Coordinate(latitude: -22.9068, longitude: -43.1729)
        XCTAssertEqual(Geo.distanceMeters(from: sp, to: rio) / 1000, 357, accuracy: 8)
    }

    func testDistanceToSelfIsZero() {
        let p = Coordinate(latitude: -25.4284, longitude: -49.2733)
        XCTAssertEqual(Geo.distanceMeters(from: p, to: p), 0, accuracy: 0.001)
    }

    func testIsWithinRadius() {
        let c = Coordinate(latitude: 0, longitude: 0)
        let near = Coordinate(latitude: 0.001, longitude: 0)   // ~111 m
        XCTAssertTrue(Geo.isWithin(200, of: c, point: near))
        XCTAssertFalse(Geo.isWithin(100, of: c, point: near))
    }

    func testFormatDistance() {
        XCTAssertEqual(Geo.formatDistance(850), "850 m")
        XCTAssertEqual(Geo.formatDistance(1234), "1,2 km")
        XCTAssertEqual(Geo.formatDistance(15_400), "15 km")
    }

    func testCoordinateValidity() {
        XCTAssertTrue(Coordinate(latitude: -23, longitude: -46).isValid)
        XCTAssertFalse(Coordinate(latitude: 91, longitude: 0).isValid)
        XCTAssertFalse(Coordinate(latitude: 0, longitude: 181).isValid)
    }
}

final class GeoAlarmTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func makeAlarm(_ title: String = "A", lat: Double = 0, lon: Double = 0) -> GeoAlarm {
        GeoAlarm(title: title, coordinate: Coordinate(latitude: lat, longitude: lon))
    }

    func testWeekdayFromDate() {
        // 3 de outubro de 2026 é um sábado.
        XCTAssertEqual(Weekday(date: date(2026, 10, 3), calendar: calendar), .saturday)
        XCTAssertEqual(Weekday(date: date(2026, 10, 5), calendar: calendar), .monday)
    }

    func testIsActiveHonorsDaysAndMasterSwitch() {
        var alarm = makeAlarm()
        alarm.activeDays = Weekday.weekdays
        XCTAssertTrue(alarm.isActive(on: date(2026, 10, 5), calendar: calendar))   // segunda
        XCTAssertFalse(alarm.isActive(on: date(2026, 10, 3), calendar: calendar))  // sábado
        alarm.isEnabled = false
        XCTAssertFalse(alarm.isActive(on: date(2026, 10, 5), calendar: calendar))
    }

    func testEffectiveRadiusIsClamped() {
        var alarm = makeAlarm()
        alarm.radiusMeters = 10
        XCTAssertEqual(alarm.effectiveRadiusMeters, GeoAlarm.minRadiusMeters)
        alarm.radiusMeters = 1_000_000
        XCTAssertEqual(alarm.effectiveRadiusMeters, GeoAlarm.maxRadiusMeters)
        alarm.radiusMeters = 750
        XCTAssertEqual(alarm.effectiveRadiusMeters, 750)
    }

    func testDisplayTitleFallback() {
        var alarm = makeAlarm("   ")
        XCTAssertEqual(alarm.displayTitle, "Alarme")
        alarm.title = "Trabalho"
        XCTAssertEqual(alarm.displayTitle, "Trabalho")
    }

    func testSoundReferenceRoundTrip() {
        XCTAssertEqual(SoundReference(id: "default"), .systemDefault)
        XCTAssertEqual(SoundReference(id: "builtin:sino"), .builtIn("sino"))
        XCTAssertEqual(SoundReference(id: "imported:abc.m4a"), .imported("abc.m4a"))
        XCTAssertEqual(SoundReference.builtIn("sino").id, "builtin:sino")
        XCTAssertEqual(SoundReference.imported("abc.m4a").id, "imported:abc.m4a")
        XCTAssertEqual(SoundReference(id: "lixo"), .systemDefault)
    }

    // MARK: AlarmPolicy

    func testShouldFireRequiresMatchingTransition() {
        var alarm = makeAlarm()
        alarm.transition = .enter
        let day = date(2026, 10, 5)
        XCTAssertTrue(AlarmPolicy.shouldFire(alarm, on: .enter, at: day, calendar: calendar))
        XCTAssertFalse(AlarmPolicy.shouldFire(alarm, on: .exit, at: day, calendar: calendar))
        alarm.transition = .exit
        XCTAssertTrue(AlarmPolicy.shouldFire(alarm, on: .exit, at: day, calendar: calendar))
    }

    func testShouldFireIsFalseOnInactiveDay() {
        var alarm = makeAlarm()
        alarm.activeDays = [.monday]
        XCTAssertFalse(AlarmPolicy.shouldFire(alarm, on: .enter, at: date(2026, 10, 3), calendar: calendar))
    }

    func testDistanceSnoozeRingsAgainOnlyWhenClose() {
        var alarm = makeAlarm()
        alarm.snoozeDistanceMeters = 200
        let near = Coordinate(latitude: 0.001, longitude: 0)   // ~111 m
        let far = Coordinate(latitude: 0.01, longitude: 0)     // ~1,1 km
        XCTAssertTrue(AlarmPolicy.shouldRingAgain(alarm, userLocation: near))
        XCTAssertFalse(AlarmPolicy.shouldRingAgain(alarm, userLocation: far))
    }

    // MARK: RegionSelector

    func testRegionSelectorKeepsEverythingUnderLimit() {
        let alarms = (0..<5).map { makeAlarm("A\($0)", lat: Double($0) * 0.01) }
        XCTAssertEqual(RegionSelector.select(from: alarms, around: nil).count, 5)
    }

    func testRegionSelectorPicksNearestTwenty() {
        // 30 alarmes em linha; o usuário está em lat 0. Os 20 mais próximos são os índices 0..19.
        let alarms = (0..<30).map { makeAlarm("A\($0)", lat: Double($0) * 0.05) }
        let picked = RegionSelector.select(from: alarms, around: Coordinate(latitude: 0, longitude: 0))
        XCTAssertEqual(picked.count, 20)
        XCTAssertEqual(Set(picked.map(\.title)), Set((0..<20).map { "A\($0)" }))
    }

    func testRegionSelectorIgnoresDisabledAlarms() {
        var disabled = makeAlarm("off")
        disabled.isEnabled = false
        let on = makeAlarm("on", lat: 1)
        let picked = RegionSelector.select(from: [disabled, on], around: Coordinate(latitude: 0, longitude: 0))
        XCTAssertEqual(picked.map(\.title), ["on"])
    }

    func testRegionSelectorUsesDistanceToEdgeNotCenter() {
        // "grande" tem o centro mais longe (~11 km) mas a borda mais perto que "pequeno".
        var big = makeAlarm("grande", lat: 0.1)
        big.radiusMeters = 10_000
        var small = makeAlarm("pequeno", lat: 0.05)
        small.radiusMeters = 100
        let picked = RegionSelector.select(from: [small, big],
                                           around: Coordinate(latitude: 0, longitude: 0),
                                           limit: 1)
        XCTAssertEqual(picked.map(\.title), ["grande"])
    }

    func testRegionSelectorRespectsCustomLimit() {
        let alarms = (0..<10).map { makeAlarm("A\($0)", lat: Double($0)) }
        XCTAssertEqual(RegionSelector.select(from: alarms, around: nil, limit: 3).count, 3)
    }
}

final class VibrationTimelineTests: XCTestCase {
    func testNoneHasNoSegments() {
        XCTAssertTrue(VibrationTimeline.segments(for: .none).isEmpty)
    }

    func testEveryPatternStartsWithVibrationAndHasPause() {
        for pattern in VibrationPattern.allCases where pattern != .none {
            let segments = VibrationTimeline.segments(for: pattern)
            XCTAssertFalse(segments.isEmpty, "\(pattern)")
            XCTAssertFalse(segments[0].isPause, "\(pattern) deve começar vibrando")
            XCTAssertTrue(segments.contains { $0.isPause }, "\(pattern) precisa de pausa para o loop")
            XCTAssertTrue(segments.allSatisfy { $0.durationMs > 0 }, "\(pattern)")
            XCTAssertTrue(segments.allSatisfy { (0...1).contains($0.intensity) }, "\(pattern)")
        }
    }

    func testContinuousTiming() {
        XCTAssertEqual(VibrationTimeline.totalDurationMs(for: .continuous), 1500)
    }

    func testSosHasNineVibrations() {
        let vibrations = VibrationTimeline.segments(for: .sos).filter { !$0.isPause }
        XCTAssertEqual(vibrations.count, 9)
        XCTAssertEqual(vibrations.filter { $0.durationMs == 400 }.count, 3)
    }
}
