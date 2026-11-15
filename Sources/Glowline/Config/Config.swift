import Foundation

struct ZoneLayoutConfig: Codable {
    var top: Int = 10
    var bottom: Int = 10
    var left: Int = 6
    var right: Int = 6
    var startCorner: Corner = .topLeft
    var clockwise: Bool = true
    var edgeDepthFraction: Double = 0.15

    init() {}

    private enum CodingKeys: String, CodingKey {
        case top, bottom, left, right, startCorner, clockwise, edgeDepthFraction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        top = try c.decodeIfPresent(Int.self, forKey: .top) ?? 10
        bottom = try c.decodeIfPresent(Int.self, forKey: .bottom) ?? 10
        left = try c.decodeIfPresent(Int.self, forKey: .left) ?? 6
        right = try c.decodeIfPresent(Int.self, forKey: .right) ?? 6
        if let rawCorner = try c.decodeIfPresent(String.self, forKey: .startCorner) {
            if let corner = Corner(rawValue: rawCorner) {
                startCorner = corner
            } else {
                logError("Unknown zones.startCorner \"\(rawCorner)\" -- using topLeft.")
                startCorner = .topLeft
            }
        } else {
            startCorner = .topLeft
        }
        clockwise = try c.decodeIfPresent(Bool.self, forKey: .clockwise) ?? true
        edgeDepthFraction = try c.decodeIfPresent(Double.self, forKey: .edgeDepthFraction) ?? 0.15
    }
}

struct AppConfig: Codable {
    var displayIndex: Int = 0
    var captureWidth: Int = 192
    var targetFPS: Double = 30
    var serialPort: String? = nil
    var baudRate: Int = 500_000
    var zones: ZoneLayoutConfig = ZoneLayoutConfig()
    var gamma: Double = 1.0
    var brightness: Double = 1.0
    var colorOrder: ColorOrder = .rgb
    var fixedAdaHeader: Bool = false
    var letterboxDetection: Bool = true
    var letterboxThreshold: Double = 0.06
    var mode: LightingMode = .screen
    var color: LEDColor = LEDColor(r: 0xFF, g: 0x7A, b: 0x1A)
    var secondColor: LEDColor = LEDColor(r: 0x2B, g: 0x6C, b: 0xFF)
    var effectSpeed: Double = 1.0
    var enabled: Bool = true
    var smoothing: Double = 0.1
    var saturation: Double = 1.0
    var whiteBalance: ChannelGains = ChannelGains()
    var night: NightSchedule = NightSchedule()
    var autoOff: AutoOffOptions = AutoOffOptions()
    var profiles: [LightingProfile] = LightingProfile.defaults

    init() {}

    private enum CodingKeys: String, CodingKey {
        case displayIndex, captureWidth, targetFPS, serialPort, baudRate, zones, gamma, brightness, colorOrder, fixedAdaHeader,
            letterboxDetection, letterboxThreshold, mode, color, secondColor, effectSpeed,
            enabled, smoothing, saturation, whiteBalance, night, autoOff, profiles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        displayIndex = try c.decodeIfPresent(Int.self, forKey: .displayIndex) ?? 0
        captureWidth = try c.decodeIfPresent(Int.self, forKey: .captureWidth) ?? 192
        targetFPS = try c.decodeIfPresent(Double.self, forKey: .targetFPS) ?? 30
        serialPort = try c.decodeIfPresent(String.self, forKey: .serialPort)
        baudRate = try c.decodeIfPresent(Int.self, forKey: .baudRate) ?? 500_000
        zones = try c.decodeIfPresent(ZoneLayoutConfig.self, forKey: .zones) ?? ZoneLayoutConfig()
        gamma = try c.decodeIfPresent(Double.self, forKey: .gamma) ?? 1.0
        brightness = try c.decodeIfPresent(Double.self, forKey: .brightness) ?? 1.0
        if let rawOrder = try c.decodeIfPresent(String.self, forKey: .colorOrder) {
            if let order = ColorOrder(rawValue: rawOrder.uppercased()) {
                colorOrder = order
            } else {
                logError("Unknown colorOrder \"\(rawOrder)\" -- using RGB.")
                colorOrder = .rgb
            }
        } else {
            colorOrder = .rgb
        }
        fixedAdaHeader = try c.decodeIfPresent(Bool.self, forKey: .fixedAdaHeader) ?? false
        letterboxDetection = try c.decodeIfPresent(Bool.self, forKey: .letterboxDetection) ?? true
        letterboxThreshold = try c.decodeIfPresent(Double.self, forKey: .letterboxThreshold) ?? 0.06
        if let rawMode = try c.decodeIfPresent(String.self, forKey: .mode) {
            if let parsed = LightingMode(rawValue: rawMode) {
                mode = parsed
            } else {
                logError("Unknown mode \"\(rawMode)\" -- using screen.")
                mode = .screen
            }
        }
        color = Self.decodeColor(c, .color) ?? color
        secondColor = Self.decodeColor(c, .secondColor) ?? secondColor
        effectSpeed = try c.decodeIfPresent(Double.self, forKey: .effectSpeed) ?? 1.0
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        smoothing = try c.decodeIfPresent(Double.self, forKey: .smoothing) ?? 0.1
        saturation = try c.decodeIfPresent(Double.self, forKey: .saturation) ?? 1.0
        whiteBalance = try c.decodeIfPresent(ChannelGains.self, forKey: .whiteBalance) ?? ChannelGains()
        night = try c.decodeIfPresent(NightSchedule.self, forKey: .night) ?? NightSchedule()
        autoOff = try c.decodeIfPresent(AutoOffOptions.self, forKey: .autoOff) ?? AutoOffOptions()
        if let decoded = try? c.decodeIfPresent([LightingProfile].self, forKey: .profiles) {
            profiles = decoded
        } else {
            if c.contains(.profiles) { logError("Could not read \"profiles\" -- using the built-in profiles.") }
            profiles = LightingProfile.defaults
        }
    }

    private static func decodeColor(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> LEDColor? {
        guard let raw = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let color = LEDColor(hex: raw) else {
            logError("Invalid \(key.stringValue) \"\(raw)\" -- expected a color like \"#FF8800\".")
            return nil
        }
        return color
    }

    var effectParameters: EffectParameters {
        EffectParameters(
            mode: mode, primaryColor: color, secondaryColor: secondColor, speed: effectSpeed, brightness: brightness, gamma: gamma)
    }

    static func load(path: String?) -> AppConfig {
        guard let path else { return AppConfig() }
        let expanded = (path as NSString).expandingTildeInPath
        guard let data = FileManager.default.contents(atPath: expanded) else {
            logError("Config file not found at \(expanded), using defaults")
            return AppConfig()
        }
        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            logError("Failed to parse \(expanded): \(error). Using defaults.")
            return AppConfig()
        }
    }

    static func restartRequiredFields(current: AppConfig, runningConfig: AppConfig) -> Bool {
        current.captureWidth != runningConfig.captureWidth || current.targetFPS != runningConfig.targetFPS
            || current.displayIndex != runningConfig.displayIndex || current.baudRate != runningConfig.baudRate
            || current.serialPort != runningConfig.serialPort || current.zones.top != runningConfig.zones.top
            || current.zones.bottom != runningConfig.zones.bottom || current.zones.left != runningConfig.zones.left
            || current.zones.right != runningConfig.zones.right || current.zones.startCorner != runningConfig.zones.startCorner
            || current.zones.clockwise != runningConfig.zones.clockwise
            || current.zones.edgeDepthFraction != runningConfig.zones.edgeDepthFraction
    }

    func save(to path: String) throws {
        let expanded = (path as NSString).expandingTildeInPath
        let directory = (expanded as NSString).deletingLastPathComponent
        if !directory.isEmpty {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: URL(fileURLWithPath: expanded), options: .atomic)
    }
}
