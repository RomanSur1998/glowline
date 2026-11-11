import Foundation

struct EffectParameters: Equatable {
    var mode: LightingMode
    var primaryColor: LEDColor
    var secondaryColor: LEDColor
    var speed: Double
    var brightness: Double
    var gamma: Double
}

enum EffectRenderer {
    static let rainbowPeriodSeconds = 10.0
    static let breathingPeriodSeconds = 4.0
    static let breathingMinLevel = 0.08

    static func colors(for p: EffectParameters, ledCount: Int, time: Double) -> [(UInt8, UInt8, UInt8)] {
        guard ledCount > 0 else { return [] }
        let raw: [(Double, Double, Double)]
        switch p.mode {
        case .screen, .solid:
            raw = Array(repeating: unit(p.primaryColor), count: ledCount)
        case .gradient:
            let a = unit(p.primaryColor)
            let b = unit(p.secondaryColor)
            raw = (0..<ledCount).map { i in
                let position = Double(i) / Double(ledCount)
                let t = 1 - abs(2 * position - 1)
                return mix(a, b, t)
            }
        case .rainbow:
            let shift = fraction(time * p.speed / rainbowPeriodSeconds)
            raw = (0..<ledCount).map { i in
                hueToRGB(fraction(Double(i) / Double(ledCount) + shift))
            }
        case .breathing:
            let phase = fraction(time * p.speed / breathingPeriodSeconds)
            let wave = 0.5 - 0.5 * cos(2 * Double.pi * phase)
            let level = breathingMinLevel + (1 - breathingMinLevel) * wave
            let c = unit(p.primaryColor)
            raw = Array(repeating: (c.0 * level, c.1 * level, c.2 * level), count: ledCount)
        }
        return raw.map { correct($0, gamma: p.gamma, brightness: p.brightness) }
    }

    static func correct(_ c: (Double, Double, Double), gamma: Double, brightness: Double) -> (UInt8, UInt8, UInt8) {
        let exponent = gamma > 0 ? gamma : 1
        func channel(_ v: Double) -> UInt8 {
            let corrected = pow(max(v, 0), exponent) * brightness
            return UInt8((min(max(corrected, 0), 1) * 255).rounded())
        }
        return (channel(c.0), channel(c.1), channel(c.2))
    }

    static func hueToRGB(_ hue: Double) -> (Double, Double, Double) {
        let h = fraction(hue) * 6
        let x = 1 - abs(h.truncatingRemainder(dividingBy: 2) - 1)
        switch Int(h) {
        case 0: return (1, x, 0)
        case 1: return (x, 1, 0)
        case 2: return (0, 1, x)
        case 3: return (0, x, 1)
        case 4: return (x, 0, 1)
        default: return (1, 0, x)
        }
    }

    private static func unit(_ c: LEDColor) -> (Double, Double, Double) {
        (Double(c.r) / 255, Double(c.g) / 255, Double(c.b) / 255)
    }

    private static func mix(_ a: (Double, Double, Double), _ b: (Double, Double, Double), _ t: Double) -> (Double, Double, Double) {
        (a.0 + (b.0 - a.0) * t, a.1 + (b.1 - a.1) * t, a.2 + (b.2 - a.2) * t)
    }

    private static func fraction(_ v: Double) -> Double {
        v - v.rounded(.down)
    }
}
