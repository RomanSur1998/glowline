import XCTest

@testable import Glowline

final class LightingConfigTests: XCTestCase {
    private func decode(_ json: String) throws -> AppConfig {
        try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))
    }

    func testHexRoundTrip() {
        let color = LEDColor(hex: "#ff8800")
        XCTAssertEqual(color, LEDColor(r: 255, g: 136, b: 0))
        XCTAssertEqual(color?.hex, "#FF8800")
        XCTAssertEqual(LEDColor(hex: "00FF7f"), LEDColor(r: 0, g: 255, b: 127))
    }

    func testInvalidHexIsRejected() {
        XCTAssertNil(LEDColor(hex: "#FF88"))
        XCTAssertNil(LEDColor(hex: "#GG0000"))
        XCTAssertNil(LEDColor(hex: ""))
    }

    func testMissingFieldsUseDefaults() throws {
        let config = try decode("{}")
        XCTAssertEqual(config.mode, .screen)
        XCTAssertEqual(config.color, AppConfig().color)
        XCTAssertEqual(config.effectSpeed, 1.0)
    }

    func testModeAndColorsAreDecoded() throws {
        let config = try decode(##"{"mode": "gradient", "color": "#102030", "secondColor": "#AABBCC", "effectSpeed": 2.5}"##)
        XCTAssertEqual(config.mode, .gradient)
        XCTAssertEqual(config.color, LEDColor(r: 0x10, g: 0x20, b: 0x30))
        XCTAssertEqual(config.secondColor, LEDColor(r: 0xAA, g: 0xBB, b: 0xCC))
        XCTAssertEqual(config.effectSpeed, 2.5)
    }

    func testUnknownModeAndBadColorFallBack() throws {
        let config = try decode(##"{"mode": "disco", "color": "orange"}"##)
        XCTAssertEqual(config.mode, .screen)
        XCTAssertEqual(config.color, AppConfig().color)
    }

    func testSavedConfigRoundTrips() throws {
        var config = AppConfig()
        config.mode = .breathing
        config.color = LEDColor(r: 1, g: 2, b: 3)
        let data = try JSONEncoder().encode(config)
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"#010203\""))
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.mode, .breathing)
        XCTAssertEqual(decoded.color, config.color)
    }

    func testLightingChangesDoNotNeedRestart() {
        let running = AppConfig()
        var current = AppConfig()
        current.mode = .rainbow
        current.color = LEDColor(r: 0, g: 0, b: 0)
        current.secondColor = LEDColor(r: 9, g: 9, b: 9)
        current.effectSpeed = 3
        XCTAssertFalse(AppConfig.restartRequiredFields(current: current, runningConfig: running))
    }
}
