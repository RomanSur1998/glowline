import Foundation

enum LightingMode: String, Codable, CaseIterable {
    case screen
    case solid
    case gradient
    case rainbow
    case breathing

    var title: String {
        switch self {
        case .screen: return "Screen sync"
        case .solid: return "Solid color"
        case .gradient: return "Gradient"
        case .rainbow: return "Rainbow"
        case .breathing: return "Breathing"
        }
    }

    var isAnimated: Bool {
        self == .rainbow || self == .breathing
    }

    var usesPrimaryColor: Bool {
        self == .solid || self == .gradient || self == .breathing
    }

    var usesSecondaryColor: Bool {
        self == .gradient
    }
}

struct LEDColor: Codable, Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        r = UInt8((value >> 16) & 0xFF)
        g = UInt8((value >> 8) & 0xFF)
        b = UInt8(value & 0xFF)
    }

    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.contains(",") {
            let parts = trimmed.split(separator: ",", omittingEmptySubsequences: false).map {
                UInt8($0.trimmingCharacters(in: .whitespaces))
            }
            guard parts.count == 3, let r = parts[0], let g = parts[1], let b = parts[2] else { return nil }
            self.init(r: r, g: g, b: b)
        } else {
            self.init(hex: trimmed)
        }
    }

    var hex: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let color = LEDColor(hex: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a color like \"#FF8800\", got \"\(raw)\"")
        }
        self = color
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}
