import Foundation

final class FrameSink {
    let ledCount: Int
    private let frameSettings: LiveFrameSettings
    private let output: LiveOutputSettings
    private let lastFrameBox: LastFrameBox
    private let serial: SerialSupervisor?

    init(
        ledCount: Int, frameSettings: LiveFrameSettings, output: LiveOutputSettings, lastFrameBox: LastFrameBox,
        serial: SerialSupervisor?
    ) {
        self.ledCount = ledCount
        self.frameSettings = frameSettings
        self.output = output
        self.lastFrameBox = lastFrameBox
        self.serial = serial
    }

    func makeFrame(_ colors: [(UInt8, UInt8, UInt8)], forScreen: Bool) -> Data {
        let corrected = output.correction(forScreen: forScreen).apply(colors)
        return AdalightFrame.build(colors: corrected, colorOrder: frameSettings.colorOrder, fixedHeader: frameSettings.fixedAdaHeader)
    }

    func emit(_ frame: Data) {
        lastFrameBox.set(frame)
        serial?.send(frame)
    }

    func send(_ colors: [(UInt8, UInt8, UInt8)], forScreen: Bool) {
        emit(makeFrame(colors, forScreen: forScreen))
    }

    func sendBlack() {
        guard ledCount > 0 else { return }
        let black = Array(repeating: (UInt8(0), UInt8(0), UInt8(0)), count: ledCount)
        emit(AdalightFrame.build(colors: black, colorOrder: frameSettings.colorOrder, fixedHeader: frameSettings.fixedAdaHeader))
    }

    func clear() {
        lastFrameBox.clear()
    }
}
