import XCTest

@testable import SkydimoAmbient

final class AckPacerTests: XCTestCase {
    func testStartsByWaitingForAcks() {
        let pacer = AckPacer()
        XCTAssertTrue(pacer.controllerSendsAcks)
        XCTAssertEqual(pacer.waitTimeoutMs, AckPacer.ackTimeoutMs)
    }

    func testFallsBackToShortGapAfterRepeatedMissedAcks() {
        var pacer = AckPacer()
        for _ in 0..<AckPacer.missedAcksBeforeFallback {
            pacer.record(ackReceived: false)
        }
        XCTAssertFalse(pacer.controllerSendsAcks)
        XCTAssertEqual(pacer.waitTimeoutMs, AckPacer.interFrameGapMs)
    }

    func testOccasionalMissedAckDoesNotTriggerFallback() {
        var pacer = AckPacer()
        for _ in 0..<10 {
            pacer.record(ackReceived: false)
            pacer.record(ackReceived: true)
        }
        XCTAssertTrue(pacer.controllerSendsAcks)
    }

    func testAckAfterFallbackRestoresAckMode() {
        var pacer = AckPacer()
        for _ in 0..<AckPacer.missedAcksBeforeFallback {
            pacer.record(ackReceived: false)
        }
        pacer.record(ackReceived: true)
        XCTAssertTrue(pacer.controllerSendsAcks)
        XCTAssertEqual(pacer.waitTimeoutMs, AckPacer.ackTimeoutMs)
    }
}
