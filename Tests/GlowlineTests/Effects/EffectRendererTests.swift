import XCTest

@testable import Glowline

final class EffectRendererTests: XCTestCase {
    private func params(
        _ mode: LightingMode, primary: LEDColor = LEDColor(r: 200, g: 100, b: 50), secondary: LEDColor = LEDColor(r: 0, g: 0, b: 255),
        speed: Double = 1, brightness: Double = 1, gamma: Double = 1
    ) -> EffectParameters {
        EffectParameters(mode: mode, primaryColor: primary, secondaryColor: secondary, speed: speed, brightness: brightness, gamma: gamma)
    }

    private func assertColor(
        _ actual: (UInt8, UInt8, UInt8), _ expected: (UInt8, UInt8, UInt8), file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual([actual.0, actual.1, actual.2], [expected.0, expected.1, expected.2], file: file, line: line)
    }

    func testSolidFillsEveryLedWithTheColor() {
        let colors = EffectRenderer.colors(for: params(.solid), ledCount: 12, time: 5)
        XCTAssertEqual(colors.count, 12)
        for c in colors { assertColor(c, (200, 100, 50)) }
    }

    func testZeroLedsGivesEmptyFrame() {
        XCTAssertTrue(EffectRenderer.colors(for: params(.rainbow), ledCount: 0, time: 0).isEmpty)
    }

    func testBrightnessScalesAndClamps() {
        let half = EffectRenderer.colors(for: params(.solid, brightness: 0.5), ledCount: 1, time: 0)
        assertColor(half[0], (100, 50, 25))
        let boosted = EffectRenderer.colors(for: params(.solid, brightness: 2), ledCount: 1, time: 0)
        assertColor(boosted[0], (255, 200, 100))
    }

    func testGammaDarkensMidtones() {
        let gray = LEDColor(r: 128, g: 128, b: 128)
        let colors = EffectRenderer.colors(for: params(.solid, primary: gray, gamma: 2.2), ledCount: 1, time: 0)
        XCTAssertLessThan(colors[0].0, 128)
        XCTAssertGreaterThan(colors[0].0, 0)
    }

    func testGradientRunsFromEdgeColorToCenterAndBack() {
        let colors = EffectRenderer.colors(
            for: params(.gradient, primary: LEDColor(r: 255, g: 0, b: 0), secondary: LEDColor(r: 0, g: 0, b: 255)), ledCount: 10, time: 0)
        assertColor(colors[0], (255, 0, 0))
        assertColor(colors[5], (0, 0, 255))
        assertColor(colors[1], colors[9])
    }

    func testGradientIsStatic() {
        let p = params(.gradient)
        let a = EffectRenderer.colors(for: p, ledCount: 20, time: 0)
        let b = EffectRenderer.colors(for: p, ledCount: 20, time: 7.3)
        XCTAssertEqual(a.map { [$0.0, $0.1, $0.2] }, b.map { [$0.0, $0.1, $0.2] })
    }

    func testRainbowStartsRedAndMovesOverTime() {
        let p = params(.rainbow)
        let start = EffectRenderer.colors(for: p, ledCount: 6, time: 0)
        assertColor(start[0], (255, 0, 0))
        assertColor(start[2], (0, 255, 0))
        assertColor(start[4], (0, 0, 255))
        let later = EffectRenderer.colors(for: p, ledCount: 6, time: EffectRenderer.rainbowPeriodSeconds / 3)
        assertColor(later[0], (0, 255, 0))
    }

    func testRainbowSpeedScalesTime() {
        let slow = EffectRenderer.colors(for: params(.rainbow, speed: 1), ledCount: 6, time: 2)
        let fast = EffectRenderer.colors(for: params(.rainbow, speed: 2), ledCount: 6, time: 1)
        XCTAssertEqual(slow.map { [$0.0, $0.1, $0.2] }, fast.map { [$0.0, $0.1, $0.2] })
    }

    func testBreathingGoesFromDimToFullColor() {
        let white = LEDColor(r: 255, g: 255, b: 255)
        let dim = EffectRenderer.colors(for: params(.breathing, primary: white), ledCount: 3, time: 0)
        let peak = EffectRenderer.colors(
            for: params(.breathing, primary: white), ledCount: 3, time: EffectRenderer.breathingPeriodSeconds / 2)
        let expectedDim = UInt8((EffectRenderer.breathingMinLevel * 255).rounded())
        assertColor(dim[0], (expectedDim, expectedDim, expectedDim))
        assertColor(peak[0], (255, 255, 255))
    }

    func testHueWheelPrimaries() {
        XCTAssertEqual(EffectRenderer.hueToRGB(0).0, 1)
        XCTAssertEqual(EffectRenderer.hueToRGB(1.0 / 3).1, 1)
        XCTAssertEqual(EffectRenderer.hueToRGB(2.0 / 3).2, 1)
        XCTAssertEqual(EffectRenderer.hueToRGB(1).0, 1)
    }
}
