import Foundation

struct ChannelGains: Codable, Equatable {
    var r = 1.0
    var g = 1.0
    var b = 1.0

    init(r: Double = 1, g: Double = 1, b: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        r = try c.decodeIfPresent(Double.self, forKey: .r) ?? 1
        g = try c.decodeIfPresent(Double.self, forKey: .g) ?? 1
        b = try c.decodeIfPresent(Double.self, forKey: .b) ?? 1
    }

    var isIdentity: Bool { r == 1 && g == 1 && b == 1 }
}

struct NightSchedule: Codable, Equatable {
    var enabled = false
    var startHour = 23
    var endHour = 7
    var brightness = 0.4

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        startHour = try c.decodeIfPresent(Int.self, forKey: .startHour) ?? 23
        endHour = try c.decodeIfPresent(Int.self, forKey: .endHour) ?? 7
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.4
    }

    func isNight(hour: Int) -> Bool {
        let start = ((startHour % 24) + 24) % 24
        let end = ((endHour % 24) + 24) % 24
        if start == end { return false }
        return start < end ? (hour >= start && hour < end) : (hour >= start || hour < end)
    }

    func dimFactor(at date: Date, calendar: Calendar = .current) -> Double {
        guard enabled, isNight(hour: calendar.component(.hour, from: date)) else { return 1 }
        return min(max(brightness, 0), 1)
    }
}

struct AutoOffOptions: Codable, Equatable {
    var whenDisplaySleeps = true
    var whenScreenLocked = false
    var whenMacSleeps = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        whenDisplaySleeps = try c.decodeIfPresent(Bool.self, forKey: .whenDisplaySleeps) ?? true
        whenScreenLocked = try c.decodeIfPresent(Bool.self, forKey: .whenScreenLocked) ?? false
        whenMacSleeps = try c.decodeIfPresent(Bool.self, forKey: .whenMacSleeps) ?? true
    }
}

struct OutputCorrection: Equatable {
    var saturation = 1.0
    var gains = ChannelGains()
    var dim = 1.0

    var isIdentity: Bool { saturation == 1 && gains.isIdentity && dim == 1 }

    func apply(_ colors: [(UInt8, UInt8, UInt8)]) -> [(UInt8, UInt8, UInt8)] {
        guard !isIdentity else { return colors }
        let gr = gains.r * dim, gg = gains.g * dim, gb = gains.b * dim
        return colors.map { c in
            var r = Double(c.0), g = Double(c.1), b = Double(c.2)
            if saturation != 1 {
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
                r = luma + (r - luma) * saturation
                g = luma + (g - luma) * saturation
                b = luma + (b - luma) * saturation
            }
            return (Self.byte(r * gr), Self.byte(g * gg), Self.byte(b * gb))
        }
    }

    private static func byte(_ v: Double) -> UInt8 {
        UInt8(min(max(v, 0), 255).rounded())
    }
}

final class LiveOutputSettings {
    @Locked var saturation: Double
    @Locked var gains: ChannelGains
    @Locked var smoothing: Double
    @Locked var night: NightSchedule
    @Locked var autoOff: AutoOffOptions

    init(config: AppConfig) {
        saturation = config.saturation
        gains = config.whiteBalance
        smoothing = config.smoothing
        night = config.night
        autoOff = config.autoOff
    }

    func correction(forScreen: Bool, at date: Date = Date()) -> OutputCorrection {
        OutputCorrection(saturation: forScreen ? saturation : 1, gains: gains, dim: night.dimFactor(at: date))
    }
}
