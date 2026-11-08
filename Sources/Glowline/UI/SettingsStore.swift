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

    var restartRequired: Bool {
        AppConfig.restartRequiredFields(current: currentConfig, runningConfig: restartOnlySnapshot)
    }
    @Published var availableDisplays: [(index: Int, label: String)] = []
    @Published var availableSerialDevices: [SerialDeviceInfo] = []

    let configPath: String
    private let averager: MetalZoneAverager
    private let frameSettings: LiveFrameSettings
    private let restartOnlySnapshot: AppConfig
    private var cancellables: Set<AnyCancellable> = []
    private var isApplyingExternally = false

    init(config: AppConfig, configPath: String, averager: MetalZoneAverager, frameSettings: LiveFrameSettings) {
        self.configPath = configPath
        self.averager = averager
        self.frameSettings = frameSettings
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
        return c
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

        do {
            try currentConfig.save(to: configPath)
        } catch {
            logError("Failed to save settings to \(configPath): \(error)")
        }
    }

    private func observeChanges() {
        objectWillChange
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyLiveAndPersist() }
            .store(in: &cancellables)
        applyLiveAndPersist()
    }
}
