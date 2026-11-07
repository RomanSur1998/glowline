struct AckPacer {
    static let ackTimeoutMs: Int32 = 50
    static let interFrameGapMs: Int32 = 5
    static let missedAcksBeforeFallback = 3

    private(set) var consecutiveMissedAcks = 0

    var controllerSendsAcks: Bool {
        consecutiveMissedAcks < Self.missedAcksBeforeFallback
    }

    var waitTimeoutMs: Int32 {
        controllerSendsAcks ? Self.ackTimeoutMs : Self.interFrameGapMs
    }

    mutating func record(ackReceived: Bool) {
        if ackReceived {
            consecutiveMissedAcks = 0
        } else if controllerSendsAcks {
            consecutiveMissedAcks += 1
        }
    }
}
