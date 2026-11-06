import XCTest

@testable import SkydimoAmbient

final class LockedTests: XCTestCase {
    func testReadsBackWhatWasWritten() {
        @Locked var value = 0
        value = 42
        XCTAssertEqual(value, 42)
    }

    func testConcurrentWritesAreNeverTorn() {
        final class Box {
            @Locked var text = ""
        }
        let box = Box()
        let candidates = ["A", "B", "C", "D", "E", "F", "G", "H"].map { String(repeating: $0, count: 512) }

        let iterations = 20_000
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            box.text = candidates[i % candidates.count]
        }

        XCTAssertTrue(candidates.contains(box.text), "value was torn/corrupted by a concurrent write")
    }
}
