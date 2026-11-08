import XCTest

@testable import Glowline

final class RetryingResourceTests: XCTestCase {
    private final class AttemptCounter {
        @Locked var count = 0
        func record() { count += 1 }
    }

    func testStartFiresOneAttemptImmediately() {
        let counter = AttemptCounter()
        let expectation = expectation(description: "attempt ran")
        let resource = RetryingResource(backoffNanoseconds: 1_000_000_000) {
            counter.record()
            expectation.fulfill()
        }
        resource.start()
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(counter.count, 1)
    }

    func testStartTwiceOnlyFiresOneAttempt() {
        let counter = AttemptCounter()
        let ran = expectation(description: "attempt ran")
        let resource = RetryingResource(backoffNanoseconds: 1_000_000_000) {
            counter.record()
            ran.fulfill()
        }
        resource.start()
        resource.start()
        wait(for: [ran], timeout: 1)

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 0.5)
        XCTAssertEqual(counter.count, 1)
    }

    func testFailedAttemptRetriesAfterBackoffUntilSuccess() {
        struct Boom: Error {}
        let counter = AttemptCounter()
        let succeeded = expectation(description: "eventually succeeded")
        let resource = RetryingResource(backoffNanoseconds: 50_000_000) {
            counter.record()
            if counter.count < 3 {
                throw Boom()
            }
            succeeded.fulfill()
        }
        resource.start()
        wait(for: [succeeded], timeout: 2)
        XCTAssertEqual(counter.count, 3)
    }

    func testStopPreventsFurtherRetries() {
        struct Boom: Error {}
        let counter = AttemptCounter()
        let firstAttempt = expectation(description: "first attempt ran")
        let resource = RetryingResource(backoffNanoseconds: 100_000_000) {
            counter.record()
            firstAttempt.fulfill()
            throw Boom()
        }
        resource.start()
        wait(for: [firstAttempt], timeout: 1)
        resource.stop {}

        let settled = expectation(description: "settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { settled.fulfill() }
        wait(for: [settled], timeout: 0.5)
        XCTAssertEqual(counter.count, 1)
    }

    func testRetryNowCoalescesConcurrentCalls() {
        struct Boom: Error {}
        let counter = AttemptCounter()
        let resource = RetryingResource(backoffNanoseconds: 200_000_000) {
            counter.record()
            throw Boom()
        }
        resource.start()
        resource.retryNow()
        resource.retryNow()
        resource.scheduleRestart()

        let settled = expectation(description: "settled before the 200ms backoff elapses")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { settled.fulfill() }
        wait(for: [settled], timeout: 0.15)
        XCTAssertEqual(counter.count, 1)
    }
}
