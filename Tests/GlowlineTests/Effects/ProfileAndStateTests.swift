import XCTest

@testable import Glowline

final class ProfileAndStateTests: XCTestCase {
    func testProfileCapturesAndAppliesLookSettingsOnly() {
        var source = AppConfig()
        source.mode = .breathing
        source.color = LEDColor(r: 1, g: 2, b: 3)
        source.brightness = 0.7
        source.smoothing = 0.4
        source.saturation = 1.5
        source.baudRate = 115_200
        let profile = LightingProfile(capturing: source, name: "Night")

        var target = AppConfig()
        target.baudRate = 921_600
        let applied = profile.applied(to: target)
        XCTAssertEqual(applied.mode, .breathing)
        XCTAssertEqual(applied.color, LEDColor(r: 1, g: 2, b: 3))
        XCTAssertEqual(applied.brightness, 0.7)
        XCTAssertEqual(applied.smoothing, 0.4)
        XCTAssertEqual(applied.saturation, 1.5)
        XCTAssertEqual(applied.baudRate, 921_600)
    }

    func testUpsertReplacesByNameCaseInsensitively() {
        let a = LightingProfile(capturing: AppConfig(), name: "Movie")
        var b = LightingProfile(capturing: AppConfig(), name: "movie")
        b.brightness = 0.2
        let list = LightingProfile.upserting(b, into: [a])
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].brightness, 0.2)
        XCTAssertEqual(LightingProfile.upserting(LightingProfile(capturing: AppConfig(), name: "Work"), into: list).count, 2)
    }

    func testNewConfigFieldsDefaultAndRoundTrip() throws {
        let empty = try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8))
        XCTAssertTrue(empty.enabled)
        XCTAssertEqual(empty.profiles.map(\.name), ["Movie", "Work", "Gaming"])
        XCTAssertTrue(empty.autoOff.whenDisplaySleeps)
        XCTAssertFalse(empty.night.enabled)

        var config = AppConfig()
        config.enabled = false
        config.whiteBalance = ChannelGains(r: 1, g: 0.9, b: 0.7)
        config.night.enabled = true
        config.autoOff.whenScreenLocked = true
        config.profiles = []
        let decoded = try JSONDecoder().decode(AppConfig.self, from: JSONEncoder().encode(config))
        XCTAssertFalse(decoded.enabled)
        XCTAssertEqual(decoded.whiteBalance, config.whiteBalance)
        XCTAssertTrue(decoded.night.enabled)
        XCTAssertTrue(decoded.autoOff.whenScreenLocked)
        XCTAssertTrue(decoded.profiles.isEmpty)
    }

    func testBrokenProfilesFallBackToDefaults() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"profiles": [{"name": 5}], "enabled": false}"#.utf8))
        XCTAssertEqual(config.profiles.count, LightingProfile.defaults.count)
        XCTAssertFalse(config.enabled)
    }

    func testLightingStateStatus() {
        var state = LightingState(mode: .rainbow, enabled: true)
        XCTAssertFalse(state.isLit)
        XCTAssertEqual(state.statusLine, "Controller not connected")
        state.connected = true
        XCTAssertTrue(state.isLit)
        XCTAssertEqual(state.statusLine, "On · rainbow")
        state.suspensions = [.screenLocked]
        XCTAssertFalse(state.isLit)
        XCTAssertEqual(state.statusLine, "Paused · screen locked")
        state.enabled = false
        XCTAssertEqual(state.statusLine, "Off")
    }
}
