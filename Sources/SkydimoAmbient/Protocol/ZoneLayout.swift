import simd

enum Corner: String, Codable, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct ZoneLayout {
    let config: ZoneLayoutConfig

    var totalCount: Int { config.top + config.right + config.bottom + config.left }

    func buildZoneRects(frameWidth: Int, frameHeight: Int, contentTop: Int = 0, contentBottom: Int? = nil) -> [SIMD4<UInt32>] {
        let w = Double(frameWidth)
        let cTop = Double(min(max(contentTop, 0), frameHeight - 1))
        let cBottom = Double(min(max(contentBottom ?? frameHeight, contentTop + 1), frameHeight))
        let contentHeight = max(1.0, cBottom - cTop)
        let depthX = max(1, Int((w * config.edgeDepthFraction).rounded()))
        let depthY = max(1, Int((contentHeight * config.edgeDepthFraction).rounded()))

        func rect(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> SIMD4<UInt32> {
            let cx0 = min(max(x0, 0), w - 1)
            let cy0 = min(max(y0, cTop), cBottom - 1)
            let cx1 = min(max(x1, cx0 + 1), w)
            let cy1 = min(max(y1, cy0 + 1), cBottom)
            return SIMD4<UInt32>(UInt32(cx0), UInt32(cy0), UInt32(cx1), UInt32(cy1))
        }

        var top: [SIMD4<UInt32>] = []
        if config.top > 0 {
            let step = w / Double(config.top)
            for i in 0..<config.top {
                top.append(rect(Double(i) * step, cTop, Double(i + 1) * step, cTop + Double(depthY)))
            }
        }

        var bottomLTR: [SIMD4<UInt32>] = []
        if config.bottom > 0 {
            let step = w / Double(config.bottom)
            for i in 0..<config.bottom {
                bottomLTR.append(rect(Double(i) * step, cBottom - Double(depthY), Double(i + 1) * step, cBottom))
            }
        }

        let sideTop = cTop + Double(depthY)
        let sideBottom = cBottom - Double(depthY)
        let sideSpan = max(1.0, sideBottom - sideTop)

        var right: [SIMD4<UInt32>] = []
        if config.right > 0 {
            let step = sideSpan / Double(config.right)
            for i in 0..<config.right {
                right.append(rect(w - Double(depthX), sideTop + Double(i) * step, w, sideTop + Double(i + 1) * step))
            }
        }

        var leftBTT: [SIMD4<UInt32>] = []
        if config.left > 0 {
            let step = sideSpan / Double(config.left)
            for i in 0..<config.left {
                leftBTT.append(rect(0, sideTop + Double(i) * step, Double(depthX), sideTop + Double(i + 1) * step))
            }
        }

        var canonical = top + right + bottomLTR.reversed() + leftBTT.reversed()
        guard !canonical.isEmpty else { return [] }

        let topCount = config.top, rightCount = config.right, bottomCount = config.bottom
        let cornerOffsetCW: [Corner: Int] = [
            .topLeft: 0,
            .topRight: topCount,
            .bottomRight: topCount + rightCount,
            .bottomLeft: topCount + rightCount + bottomCount,
        ]
        let offsetCW = cornerOffsetCW[config.startCorner] ?? 0

        if !config.clockwise {
            canonical.reverse()
            let n = canonical.count
            let rotation = ((n - offsetCW) % n + n) % n
            return Array(canonical[rotation...] + canonical[..<rotation])
        } else {
            let rotation = ((offsetCW % canonical.count) + canonical.count) % canonical.count
            return Array(canonical[rotation...] + canonical[..<rotation])
        }
    }
}
