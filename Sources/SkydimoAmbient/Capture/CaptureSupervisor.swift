import CoreMedia
import Foundation
import ScreenCaptureKit

final class LastFrameBox {
    @Locked private var frame: Data? = nil

    func set(_ frame: Data) {
        self.frame = frame
    }

    func get() -> Data? {
        frame
    }
}

final class CaptureSupervisor: @unchecked Sendable {
    private let config: AppConfig
    private let averager: MetalZoneAverager
    private let serial: SerialSupervisor?
    private let lastFrameBox: LastFrameBox
    private let frameSettings: LiveFrameSettings
    private let resource: RetryingResource
    private var frameCounter = 0
    @Locked private var currentCapture: ScreenCapture? = nil

    init(
        config: AppConfig, averager: MetalZoneAverager, serial: SerialSupervisor?, lastFrameBox: LastFrameBox,
        frameSettings: LiveFrameSettings
    ) {
        self.config = config
        self.averager = averager
        self.serial = serial
        self.lastFrameBox = lastFrameBox
        self.frameSettings = frameSettings
        var attempt: (() async throws -> Void)!
        self.resource = RetryingResource(backoffNanoseconds: 3_000_000_000) { try await attempt() }
        attempt = { [weak self] in try await self?.beginCapture() }
    }

    func start() {
        resource.start()
    }

    func stop() {
        resource.stop { [self] in
            let capture = currentCapture
            currentCapture = nil
            print("Skydimo not connected -- pausing screen capture until it is.")
            Task { await capture?.stop() }
        }
    }

    private func beginCapture() async throws {
        frameCounter = 0
        let capture = ScreenCapture(
            onFrame: { [weak self] pixelBuffer in self?.handleFrame(pixelBuffer) },
            onStop: { [weak self] error in self?.handleStop(error: error) }
        )
        currentCapture = capture

        do {
            let displays = try await ScreenCapture.availableDisplays()
            guard !displays.isEmpty else { throw ScreenCaptureError.noDisplays }
            var resolvedIndex = config.displayIndex
            if resolvedIndex < 0 || resolvedIndex >= displays.count {
                logError(
                    "displayIndex \(config.displayIndex) out of range (0..<\(displays.count)) -- falling back to display 0 until it's back."
                )
                resolvedIndex = 0
            }
            let display = displays[resolvedIndex]
            try await capture.start(display: display, captureWidth: config.captureWidth, targetFPS: config.targetFPS)
            print(
                "Capturing display [\(resolvedIndex)] \(display.width)x\(display.height) -> ~\(config.captureWidth)px wide. Ctrl+C to stop."
            )
        } catch {
            logError("Failed to start capture: \(error) -- retrying.")
            throw error
        }
    }

    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let colors = averager.averageZoneColors(pixelBuffer: pixelBuffer) else { return }
        let frame = AdalightFrame.build(colors: colors, colorOrder: frameSettings.colorOrder, fixedHeader: frameSettings.fixedAdaHeader)
        frameCounter += 1
        if frameCounter % 60 == 1 {
            let preview = colors.prefix(4).map { "(\($0.0),\($0.1),\($0.2))" }.joined(separator: " ")
            print("frame #\(frameCounter): \(frame.count) bytes, zones[0..<4]=\(preview)")
        }
        lastFrameBox.set(frame)
        serial?.send(frame)
    }

    private func handleStop(error: Error?) {
        logError("Capture stopped\(error.map { ": \($0)" } ?? "") -- retrying in 3s (this is expected on display/system sleep).")
        resource.scheduleRestart()
    }

    func restartIfNeeded() {
        resource.scheduleRestart()
    }
}
