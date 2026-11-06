import Foundation

enum ColorOrder: String, Codable, CaseIterable {
    case rgb = "RGB"
    case rbg = "RBG"
    case grb = "GRB"
    case gbr = "GBR"
    case brg = "BRG"
    case bgr = "BGR"
}

enum AdalightFrame {
    static func reorder(_ color: (UInt8, UInt8, UInt8), order: ColorOrder) -> (UInt8, UInt8, UInt8) {
        let (r, g, b) = color
        switch order {
        case .rgb: return (r, g, b)
        case .rbg: return (r, b, g)
        case .grb: return (g, r, b)
        case .gbr: return (g, b, r)
        case .brg: return (b, r, g)
        case .bgr: return (b, g, r)
        }
    }

    static func build(colors: [(UInt8, UInt8, UInt8)], colorOrder: ColorOrder = .rgb, fixedHeader: Bool = false) -> Data {
        precondition(!colors.isEmpty && colors.count <= 65536, "LED count out of Adalight's 16-bit range")
        let hi: UInt8
        let lo: UInt8
        let third: UInt8
        if fixedHeader {
            hi = 0x00
            lo = 0x00
            third = UInt8(truncatingIfNeeded: colors.count)
        } else {
            let n = UInt16(colors.count - 1)
            hi = UInt8((n >> 8) & 0xFF)
            lo = UInt8(n & 0xFF)
            third = hi ^ lo ^ 0x55
        }

        var bytes = [UInt8]()
        bytes.reserveCapacity(6 + colors.count * 3)
        bytes.append(contentsOf: [0x41, 0x64, 0x61, hi, lo, third])
        for color in colors {
            let (a, b, c) = reorder(color, order: colorOrder)
            bytes.append(a)
            bytes.append(b)
            bytes.append(c)
        }
        return Data(bytes)
    }
}
