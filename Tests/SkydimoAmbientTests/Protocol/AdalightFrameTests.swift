import XCTest

@testable import SkydimoAmbient

final class AdalightFrameTests: XCTestCase {
    func testStandardHeaderEncodesCountMinusOneAndChecksum() {
        let frame = [UInt8](AdalightFrame.build(colors: Array(repeating: (0, 0, 0), count: 64)))
        XCTAssertEqual(Array(frame.prefix(6)), [0x41, 0x64, 0x61, 0x00, 0x3F, 0x6A] as [UInt8])
        XCTAssertEqual(frame.count, 6 + 64 * 3)
    }

    func testStandardHeaderUsesBothCountBytes() {
        let frame = [UInt8](AdalightFrame.build(colors: Array(repeating: (0, 0, 0), count: 300)))
        XCTAssertEqual(Array(frame[3...5]), [0x01, 0x2B, 0x7F] as [UInt8])
    }

    func testFixedHeaderCarriesLiteralLedCount() {
        let frame = [UInt8](AdalightFrame.build(colors: Array(repeating: (0, 0, 0), count: 138), fixedHeader: true))
        XCTAssertEqual(Array(frame.prefix(6)), [0x41, 0x64, 0x61, 0x00, 0x00, 0x8A])
        XCTAssertEqual(frame.count, 6 + 138 * 3)
    }

    func testPayloadFollowsColorOrder() {
        let colors: [(UInt8, UInt8, UInt8)] = [(1, 2, 3), (4, 5, 6)]
        XCTAssertEqual(Array([UInt8](AdalightFrame.build(colors: colors, colorOrder: .rgb)).dropFirst(6)), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(Array([UInt8](AdalightFrame.build(colors: colors, colorOrder: .grb)).dropFirst(6)), [2, 1, 3, 5, 4, 6])
        XCTAssertEqual(Array([UInt8](AdalightFrame.build(colors: colors, colorOrder: .bgr)).dropFirst(6)), [3, 2, 1, 6, 5, 4])
    }

    func testReorderCoversEveryPermutation() {
        let results = Set(
            ColorOrder.allCases.map { order -> [UInt8] in
                let c = AdalightFrame.reorder((1, 2, 3), order: order)
                return [c.0, c.1, c.2]
            })
        XCTAssertEqual(results.count, 6)
    }
}
