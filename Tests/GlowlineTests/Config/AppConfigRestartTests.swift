import XCTest

@testable import Glowline

final class AppConfigRestartTests: XCTestCase {
    func testIdenticalConfigsDoNotNeedRestart() {
        let a = AppConfig()
        let b = AppConfig()
        XCTAssertFalse(AppConfig.restartRequiredFields(current: a, runningConfig: b))
    }

    func testCaptureWidthChangeNeedsRestart() {
        let running = AppConfig()
        var current = AppConfig()
        current.captureWidth = running.captureWidth + 1
        XCTAssertTrue(AppConfig.restartRequiredFields(current: current, runningConfig: running))
    }

    func testSerialPortChangeNeedsRestart() {
        let running = AppConfig()
        var current = AppConfig()
        current.serialPort = "/dev/cu.usbserial-999"
        XCTAssertTrue(AppConfig.restartRequiredFields(current: current, runningConfig: running))
    }

    func testZoneCountChangeNeedsRestart() {
        let running = AppConfig()
        var current = AppConfig()
        current.zones.top = running.zones.top + 1
        XCTAssertTrue(AppConfig.restartRequiredFields(current: current, runningConfig: running))
    }

    func testStartCornerChangeNeedsRestart() {
        let running = AppConfig()
        var current = AppConfig()
        current.zones.startCorner = .bottomRight
        XCTAssertTrue(AppConfig.restartRequiredFields(current: current, runningConfig: running))
    }

    func testLiveTunableFieldsAloneDoNotNeedRestart() {
        let running = AppConfig()
        var current = AppConfig()
        current.brightness = running.brightness + 0.5
        current.gamma = running.gamma + 0.5
        current.colorOrder = .grb
        current.fixedAdaHeader = !running.fixedAdaHeader
        current.letterboxDetection = !running.letterboxDetection
        current.letterboxThreshold = running.letterboxThreshold + 0.05
        XCTAssertFalse(AppConfig.restartRequiredFields(current: current, runningConfig: running))
    }
}
