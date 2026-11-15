import XCTest

@testable import Glowline

final class OutputCorrectionTests: XCTestCase {
    private func flat(_ colors: [(UInt8, UInt8, UInt8)]) -> [UInt8] {
        colors.flatMap { [$0.0, $0.1, $0.2] }
    }

    func testIdentityLeavesColorsUntouched() {
        let colors: [(UInt8, UInt8, UInt8)] = [(10, 200, 30), (255, 0, 128)]
        XCTAssertEqual(flat(OutputCorrection().apply(colors)), flat(colors))
    }

    func testWhiteBalanceScalesEachChannel() {
        let c = OutputCorrection(gains: ChannelGains(r: 1, g: 0.5, b: 0.8))
        XCTAssertEqual(flat(c.apply([(200, 200, 200)])), [200, 100, 160])
    }

    func testDimMultipliesAfterGains() {
        let c = OutputCorrection(gains: ChannelGains(r: 0.5, g: 1, b: 1), dim: 0.5)
        XCTAssertEqual(flat(c.apply([(200, 200, 200)])), [50, 100, 100])
    }

    func testSaturationZeroGivesGrayAndKeepsGrayUnchanged() {
        let gray = OutputCorrection(saturation: 0).apply([(255, 0, 0)])[0]
        XCTAssertEqual(gray.0, gray.1)
        XCTAssertEqual(gray.1, gray.2)
        XCTAssertEqual(flat(OutputCorrection(saturation: 1.8).apply([(90, 90, 90)])), [90, 90, 90])
    }

    func testSaturationBoostPushesChannelsApartAndClamps() {
        let boosted = OutputCorrection(saturation: 2).apply([(200, 100, 100)])[0]
        XCTAssertGreaterThan(boosted.0, 200)
        XCTAssertLessThan(boosted.1, 100)
        let clamped = OutputCorrection(saturation: 3).apply([(255, 0, 0)])[0]
        XCTAssertEqual([clamped.0, clamped.1, clamped.2], [255, 0, 0])
    }

    func testNightWindowWrapsPastMidnight() {
        var night = NightSchedule()
        night.startHour = 23
        night.endHour = 7
        XCTAssertTrue(night.isNight(hour: 23))
        XCTAssertTrue(night.isNight(hour: 0))
        XCTAssertTrue(night.isNight(hour: 6))
        XCTAssertFalse(night.isNight(hour: 7))
        XCTAssertFalse(night.isNight(hour: 15))
    }

    func testNightWindowWithinOneDay() {
        var night = NightSchedule()
        night.startHour = 13
        night.endHour = 15
        XCTAssertTrue(night.isNight(hour: 14))
        XCTAssertFalse(night.isNight(hour: 15))
        night.endHour = 13
        XCTAssertFalse(night.isNight(hour: 13))
    }

    func testDimFactorOnlyWhenEnabledAndInWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let midnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 0)))
        let noon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12)))
        var night = NightSchedule()
        night.brightness = 0.3
        XCTAssertEqual(night.dimFactor(at: midnight, calendar: calendar), 1)
        night.enabled = true
        XCTAssertEqual(night.dimFactor(at: midnight, calendar: calendar), 0.3)
        XCTAssertEqual(night.dimFactor(at: noon, calendar: calendar), 1)
    }

    func testSmootherStepMovesPartWayAndSettlesWithoutTimeConstant() {
        let next = ColorSmoother.step(current: [0], target: [100], dt: 0.1, timeConstant: 0.1)
        XCTAssertEqual(next[0], 100 * (1 - exp(-1)), accuracy: 0.001)
        XCTAssertEqual(ColorSmoother.step(current: [0], target: [100], dt: 0.1, timeConstant: 0), [100])
    }

    func testSmootherIsFrameRateIndependent() {
        let oneStep = ColorSmoother.step(current: [0], target: [255], dt: 0.2, timeConstant: 0.3)
        var twoSteps = [0.0]
        twoSteps = ColorSmoother.step(current: twoSteps, target: [255], dt: 0.1, timeConstant: 0.3)
        twoSteps = ColorSmoother.step(current: twoSteps, target: [255], dt: 0.1, timeConstant: 0.3)
        XCTAssertEqual(oneStep[0], twoSteps[0], accuracy: 0.001)
    }

    func testSmootherFlattenRoundTrip() {
        let colors: [(UInt8, UInt8, UInt8)] = [(1, 2, 3), (250, 128, 0)]
        XCTAssertEqual(flat(ColorSmoother.unflatten(ColorSmoother.flatten(colors))), flat(colors))
    }
}
