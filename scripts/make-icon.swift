import AppKit
import Foundation

let canvas: CGFloat = 1024
let tileInset: CGFloat = 100
let tileRadius: CGFloat = 185
let gridCount = 11
let ringColumns = 1...9
let ringRows = 3...7
let ledZero = (column: 9, row: 7)

func render(to url: URL) throws {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard
        let ctx = CGContext(
            data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { throw NSError(domain: "icon", code: 1) }

    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    let tile = CGRect(x: tileInset, y: tileInset, width: canvas - 2 * tileInset, height: canvas - 2 * tileInset)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 28, color: CGColor(gray: 0, alpha: 0.45))
    ctx.addPath(tilePath)
    ctx.setFillColor(CGColor(gray: 0.02, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [CGColor(gray: 0.12, alpha: 1), CGColor(gray: 0.02, alpha: 1)] as CFArray,
        locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: tile.midX, y: tile.minY), end: CGPoint(x: tile.midX, y: tile.maxY), options: [])

    let pitch = tile.width / CGFloat(gridCount + 1)
    func center(_ column: Int, _ row: Int) -> CGPoint {
        CGPoint(x: tile.minX + pitch * CGFloat(column + 1), y: tile.minY + pitch * CGFloat(row + 1))
    }
    func isRing(_ column: Int, _ row: Int) -> Bool {
        guard ringColumns.contains(column), ringRows.contains(row) else { return false }
        return column == ringColumns.lowerBound || column == ringColumns.upperBound || row == ringRows.lowerBound
            || row == ringRows.upperBound
    }
    func dot(_ point: CGPoint, radius: CGFloat, color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    let off = CGColor(gray: 1, alpha: 0.09)
    let lit = CGColor(gray: 0.97, alpha: 1)
    let accent = CGColor(srgbRed: 0.93, green: 0.13, blue: 0.16, alpha: 1)

    for row in 0..<gridCount {
        for column in 0..<gridCount where !isRing(column, row) {
            dot(center(column, row), radius: pitch * 0.17, color: off)
        }
    }

    let screen = CGRect(
        x: center(ringColumns.lowerBound, 0).x + pitch * 0.75, y: center(0, ringRows.lowerBound).y + pitch * 0.75,
        width: pitch * CGFloat(ringColumns.count - 1) - pitch * 1.5, height: pitch * CGFloat(ringRows.count - 1) - pitch * 1.5)
    ctx.addPath(CGPath(roundedRect: screen, cornerWidth: pitch * 0.25, cornerHeight: pitch * 0.25, transform: nil))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.22))
    ctx.setLineWidth(pitch * 0.09)
    ctx.strokePath()

    for row in ringRows {
        for column in ringColumns where isRing(column, row) {
            let isZero = column == ledZero.column && row == ledZero.row
            let color = isZero ? accent : lit
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: pitch * 0.9, color: isZero ? accent.copy(alpha: 0.9) : CGColor(gray: 1, alpha: 0.55))
            dot(center(column, row), radius: pitch * (isZero ? 0.3 : 0.24), color: color)
            ctx.restoreGState()
        }
    }
    ctx.restoreGState()

    ctx.addPath(tilePath)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.10))
    ctx.setLineWidth(3)
    ctx.strokePath()

    guard let image = ctx.makeImage() else { throw NSError(domain: "icon", code: 2) }
    let rep = NSBitmapImageRep(cgImage: image)
    guard let png = rep.representation(using: .png, properties: [:]) else { throw NSError(domain: "icon", code: 3) }
    try png.write(to: url)
}

let output = CommandLine.arguments.dropFirst().first ?? "icon-1024.png"
try render(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
