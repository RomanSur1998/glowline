import XCTest

@testable import Glowline

final class ZoneLayoutTests: XCTestCase {
    private func layout(top: Int = 10, bottom: Int = 10, left: Int = 6, right: Int = 6, start: Corner = .topLeft, clockwise: Bool = true)
        -> ZoneLayout
    {
        var config = ZoneLayoutConfig()
        config.top = top
        config.bottom = bottom
        config.left = left
        config.right = right
        config.startCorner = start
        config.clockwise = clockwise
        config.edgeDepthFraction = 0.15
        return ZoneLayout(config: config)
    }

    func testRectCountMatchesTotalCount() {
        let l = layout(top: 44, bottom: 44, left: 25, right: 25)
        XCTAssertEqual(l.totalCount, 138)
        XCTAssertEqual(l.buildZoneRects(frameWidth: 192, frameHeight: 108).count, 138)
    }

    func testRectsStayInsideFrame() {
        for start in Corner.allCases {
            for clockwise in [true, false] {
                let rects = layout(start: start, clockwise: clockwise).buildZoneRects(frameWidth: 192, frameHeight: 108)
                for r in rects {
                    XCTAssertLessThan(r.x, r.z)
                    XCTAssertLessThan(r.y, r.w)
                    XCTAssertLessThanOrEqual(r.z, 192)
                    XCTAssertLessThanOrEqual(r.w, 108)
                }
            }
        }
    }

    func testClockwiseFromTopLeftStartsAtTopLeftAndWalksRight() {
        let rects = layout().buildZoneRects(frameWidth: 192, frameHeight: 108)
        XCTAssertEqual(rects[0].x, 0)
        XCTAssertEqual(rects[0].y, 0)
        XCTAssertGreaterThan(rects[1].x, rects[0].x)
        XCTAssertEqual(rects[1].y, 0)
    }

    func testCounterClockwiseFromTopLeftWalksDownTheLeftSide() {
        let rects = layout(clockwise: false).buildZoneRects(frameWidth: 192, frameHeight: 108)
        XCTAssertEqual(rects[0].x, 0)
        XCTAssertEqual(rects[1].x, 0)
        XCTAssertGreaterThan(rects[1].y, rects[0].y)
    }

    func testCounterClockwiseFromBottomRightWalksUpTheRightSide() {
        let rects = layout(start: .bottomRight, clockwise: false).buildZoneRects(frameWidth: 192, frameHeight: 108)
        XCTAssertEqual(rects[0].z, 192)
        XCTAssertEqual(rects[1].z, 192)
        XCTAssertLessThan(rects[1].y, rects[0].y)
    }

    func testDirectionsAreMirrorImages() {
        let cw = layout().buildZoneRects(frameWidth: 192, frameHeight: 108)
        let ccw = layout(clockwise: false).buildZoneRects(frameWidth: 192, frameHeight: 108)
        XCTAssertEqual(Set(cw.map { [$0.x, $0.y, $0.z, $0.w] }), Set(ccw.map { [$0.x, $0.y, $0.z, $0.w] }))
        XCTAssertEqual(Array(cw.reversed()), ccw)
    }

    func testLetterboxBoundsConfineTopAndBottomZones() {
        let rects = layout().buildZoneRects(frameWidth: 192, frameHeight: 108, contentTop: 14, contentBottom: 94)
        for r in rects {
            XCTAssertGreaterThanOrEqual(r.y, 14)
            XCTAssertLessThanOrEqual(r.w, 94)
        }
    }
}
