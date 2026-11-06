import CoreMedia
import ScreenCaptureKit

enum ScreenCaptureError: Error {
    case noDisplays
}

final class ScreenCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let onFrame: (CVPixelBuffer) -> Void
    private let onStop: (Error?) -> Void

    init(onFrame: @escaping (CVPixelBuffer) -> Void, onStop: @escaping (Error?) -> Void = { _ in }) {
        self.onFrame = onFrame
        self.onStop = onStop
    }

    static func availableDisplays() async throws -> [SCDisplay] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.displays
    }

    func start(display: SCDisplay, captureWidth: Int, targetFPS: Double) async throws {
        let aspect = Double(display.height) / Double(display.width)
        let width = max(16, captureWidth)
        let height = max(9, Int((Double(width) * aspect).rounded()))

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(1, targetFPS)))
        configuration.showsCursor = true
        configuration.queueDepth = 3
        configuration.scalesToFit = true

        let newStream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "skydimo.capture"))
        try await newStream.startCapture()
        self.stream = newStream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        onFrame(pixelBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onStop(error)
    }
}
