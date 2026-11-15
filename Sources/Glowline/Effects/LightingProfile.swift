import Foundation

struct LightingProfile: Codable, Equatable, Identifiable {
    var name: String
    var mode: LightingMode
    var color: LEDColor
    var secondColor: LEDColor
    var effectSpeed: Double
    var brightness: Double
    var smoothing: Double
    var saturation: Double

    var id: String { name }

    static let defaults: [LightingProfile] = [
        LightingProfile(
            name: "Movie", mode: .screen, color: LEDColor(r: 255, g: 122, b: 26), secondColor: LEDColor(r: 43, g: 108, b: 255),
            effectSpeed: 1, brightness: 1.0, smoothing: 0.3, saturation: 1.2),
        LightingProfile(
            name: "Work", mode: .solid, color: LEDColor(r: 255, g: 180, b: 100), secondColor: LEDColor(r: 43, g: 108, b: 255),
            effectSpeed: 1, brightness: 0.6, smoothing: 0.1, saturation: 1.0),
        LightingProfile(
            name: "Gaming", mode: .screen, color: LEDColor(r: 255, g: 122, b: 26), secondColor: LEDColor(r: 43, g: 108, b: 255),
            effectSpeed: 1, brightness: 1.2, smoothing: 0.05, saturation: 1.3),
    ]

    init(
        name: String, mode: LightingMode, color: LEDColor, secondColor: LEDColor, effectSpeed: Double, brightness: Double,
        smoothing: Double, saturation: Double
    ) {
        self.name = name
        self.mode = mode
        self.color = color
        self.secondColor = secondColor
        self.effectSpeed = effectSpeed
        self.brightness = brightness
        self.smoothing = smoothing
        self.saturation = saturation
    }

    init(capturing config: AppConfig, name: String) {
        self.init(
            name: name, mode: config.mode, color: config.color, secondColor: config.secondColor, effectSpeed: config.effectSpeed,
            brightness: config.brightness, smoothing: config.smoothing, saturation: config.saturation)
    }

    func applied(to config: AppConfig) -> AppConfig {
        var c = config
        c.mode = mode
        c.color = color
        c.secondColor = secondColor
        c.effectSpeed = effectSpeed
        c.brightness = brightness
        c.smoothing = smoothing
        c.saturation = saturation
        return c
    }

    static func upserting(_ profile: LightingProfile, into profiles: [LightingProfile]) -> [LightingProfile] {
        var result = profiles
        if let index = result.firstIndex(where: { $0.name.caseInsensitiveCompare(profile.name) == .orderedSame }) {
            result[index] = profile
        } else {
            result.append(profile)
        }
        return result
    }
}
