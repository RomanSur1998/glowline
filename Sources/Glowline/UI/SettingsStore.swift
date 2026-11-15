import Combine
import Foundation
import ScreenCaptureKit

@MainActor
final class SettingsStore: ObservableObject {
    @Published var displayIndex: Int
    @Published var captureWidth: Double
    @Published var targetFPS: Double
    @Published var serialPortOverride: String
    @Published var baudRate: Int
    @Published var zonesTop: Double
    @Published var zonesBottom: Double
    @Published var zonesLeft: Double
    @Published var zonesRight: Double
    @Published var startCorner: Corner
    @Published var clockwise: Bool
    @Published var edgeDepthFraction: Double

    @Published var brightness: Double
    @Published var gamma: Double
    @Published var colorOrder: ColorOrder
    @Published var fixedAdaHeader: Bool
    @Published var letterboxDetection: Bool
    @Published var letterboxThreshold: Double

    @Published var lightingMode: LightingMode
    @Published var primaryColor: LEDColor
    @Published var secondaryColor: LEDColor
    @Published var effectSpeed: Double

    @Published var isEnabled: Bool
    @Published var smoothing: Double
    @Published var saturation: Double
    @Published var whiteBalance: ChannelGains
    @Published var night: NightSchedule
    @Published var autoOff: AutoOffOptions
    @Published var profiles: [LightingProfile]
    @Published var launchAtLogin = LaunchAtLogin.isEnabled
    @Published var launchAtLoginNote: String?

    @Published var statusLine = "Starting"
    @Published var isConnected = false
    @Published var isLit = false

    var onLightingModeChange: ((LightingMode) -> Void)?
    var onEnabledChange: ((Bool) -> Void)?
    var onApplied: (() -> Void)?
    let liveColors: LiveColors
    let previewPoints: [CGPoint]

    var restartRequired: Bool {
        AppConfig.restartRequiredFields(current: currentConfig, runningConfig: restartOnlySnapshot)
    }
    @Published var availableDisplays: [(index: Int, label: String)] = []
    @Published var availableSerialDevices: [SerialDeviceInfo] = []

    let configPath: String
    private let averager: MetalZoneAverager
    private let frameSettings: LiveFrameSettings
    private let effectSettings: LiveEffectSettings
    private let outputSettings: LiveOutputSettings
    private let restartOnlySnapshot: AppConfig
    private var cancellables: Set<AnyCancellable> = []
    private var isApplyingExternally = false

    init(
        config: AppConfig, configPath: String, averager: MetalZoneAverager, frameSettings: LiveFrameSettings,
        effectSettings: LiveEffectSettings, outputSettings: LiveOutputSettings, liveColors: LiveColors
    ) {
        self.outputSettings = outputSettings
        self.liveColors = liveColors
        self.previewPoints = Self.previewPoints(for: config.zones)
        self.configPath = configPath
        self.averager = averager
        self.frameSettings = frameSettings
        self.effectSettings = effectSettings
        self.restartOnlySnapshot = config

        displayIndex = config.displayIndex
        captureWidth = Double(config.captureWidth)
        targetFPS = config.targetFPS
        serialPortOverride = config.serialPort ?? ""
        baudRate = config.baudRate
        zonesTop = Double(config.zones.top)
        zonesBottom = Double(config.zones.bottom)
        zonesLeft = Double(config.zones.left)
        zonesRight = Double(config.zones.right)
        startCorner = config.zones.startCorner
        clockwise = config.zones.clockwise
        edgeDepthFraction = config.zones.edgeDepthFraction
        brightness = config.brightness
        gamma = config.gamma
        colorOrder = config.colorOrder
        fixedAdaHeader = config.fixedAdaHeader
        letterboxDetection = config.letterboxDetection
        letterboxThreshold = config.letterboxThreshold
        lightingMode = config.mode
        primaryColor = config.color
        secondaryColor = config.secondColor
        effectSpeed = config.effectSpeed
        isEnabled = config.enabled
        smoothing = config.smoothing
        saturation = config.saturation
        whiteBalance = config.whiteBalance
        night = config.night
        autoOff = config.autoOff
        profiles = config.profiles

        observeChanges()
        refreshDeviceLists()
    }

    var currentConfig: AppConfig {
        var c = AppConfig()
        c.displayIndex = displayIndex
        c.captureWidth = Int(captureWidth)
        c.targetFPS = targetFPS
        c.serialPort = serialPortOverride.isEmpty ? nil : serialPortOverride
        c.baudRate = baudRate
        c.zones.top = Int(zonesTop)
        c.zones.bottom = Int(zonesBottom)
        c.zones.left = Int(zonesLeft)
        c.zones.right = Int(zonesRight)
        c.zones.startCorner = startCorner
        c.zones.clockwise = clockwise
        c.zones.edgeDepthFraction = edgeDepthFraction
        c.gamma = gamma
        c.brightness = brightness
        c.colorOrder = colorOrder
        c.fixedAdaHeader = fixedAdaHeader
        c.letterboxDetection = letterboxDetection
        c.letterboxThreshold = letterboxThreshold
        c.mode = lightingMode
        c.color = primaryColor
        c.secondColor = secondaryColor
        c.effectSpeed = effectSpeed
        c.enabled = isEnabled
        c.smoothing = smoothing
        c.saturation = saturation
        c.whiteBalance = whiteBalance
        c.night = night
        c.autoOff = autoOff
        c.profiles = profiles
        return c
    }

    private static func previewPoints(for zones: ZoneLayoutConfig) -> [CGPoint] {
        var shallow = zones
        shallow.edgeDepthFraction = 0.001
        let width = 1600, height = 900
        return ZoneLayout(config: shallow).buildZoneRects(frameWidth: width, frameHeight: height).map { r in
            CGPoint(x: Double(r.x + r.z) / 2 / Double(width), y: Double(r.y + r.w) / 2 / Double(height))
        }
    }

    func refreshDeviceLists() {
        availableSerialDevices = SerialDeviceFinder.listSerialDevices()
        Task {
            guard let displays = try? await ScreenCapture.availableDisplays() else { return }
            availableDisplays = displays.enumerated().map { i, d in
                (index: i, label: "[\(i)] \(d.width)×\(d.height)")
            }
        }
    }

    private func applyLiveAndPersist() {
        averager.brightness = Float(brightness)
        averager.gammaExponent = gamma > 0 ? Float(gamma) : 1.0
        averager.letterboxDetection = letterboxDetection
        averager.letterboxThreshold = Float(letterboxThreshold)
        frameSettings.colorOrder = colorOrder
        frameSettings.fixedAdaHeader = fixedAdaHeader
        effectSettings.parameters = currentConfig.effectParameters
        outputSettings.saturation = saturation
        outputSettings.gains = whiteBalance
        outputSettings.smoothing = smoothing
        outputSettings.night = night
        outputSettings.autoOff = autoOff
        onApplied?()

        do {
            try currentConfig.save(to: configPath)
        } catch {
            logError("Failed to save settings to \(configPath): \(error)")
        }
    }

    func toggleEnabled() {
        isEnabled.toggle()
    }

    func apply(_ profile: LightingProfile) {
        let c = profile.applied(to: currentConfig)
        lightingMode = c.mode
        primaryColor = c.color
        secondaryColor = c.secondColor
        effectSpeed = c.effectSpeed
        brightness = c.brightness
        smoothing = c.smoothing
        saturation = c.saturation
        isEnabled = true
    }

    func saveProfile(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        profiles = LightingProfile.upserting(LightingProfile(capturing: currentConfig, name: trimmed), into: profiles)
    }

    func deleteProfile(_ profile: LightingProfile) {
        profiles.removeAll { $0.name == profile.name }
    }

    func activeProfileName() -> String? {
        let config = currentConfig
        return profiles.first { LightingProfile(capturing: config, name: $0.name) == $0 }?.name
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchAtLoginNote = LaunchAtLogin.needsApproval ? "Allow Glowline in System Settings → Login Items" : nil
        } catch {
            launchAtLoginNote = "Could not change login item: \(error.localizedDescription)"
        }
        launchAtLogin = LaunchAtLogin.isEnabled || LaunchAtLogin.needsApproval
    }

    private func observeChanges() {
        $lightingMode
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] mode in
                guard let self else { return }
                self.effectSettings.parameters.mode = mode
                self.onLightingModeChange?(mode)
            }
            .store(in: &cancellables)
        $isEnabled
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in self?.onEnabledChange?(enabled) }
            .store(in: &cancellables)
        objectWillChange
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyLiveAndPersist() }
            .store(in: &cancellables)
        applyLiveAndPersist()
    }
}
