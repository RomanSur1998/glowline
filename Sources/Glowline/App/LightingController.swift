import Foundation

final class LightingController: @unchecked Sendable {
    private let capture: CaptureSupervisor
    private let effects: EffectPlayer
    private let lastFrameBox: LastFrameBox
    private let lock = NSLock()
    private var connected = false
    private var mode: LightingMode
    private var appliedState: (connected: Bool, mode: LightingMode)?

    var onStateChange: ((Bool, LightingMode) -> Void)?

    init(capture: CaptureSupervisor, effects: EffectPlayer, lastFrameBox: LastFrameBox, mode: LightingMode) {
        self.capture = capture
        self.effects = effects
        self.lastFrameBox = lastFrameBox
        self.mode = mode
    }

    func setConnected(_ connected: Bool) {
        lock.lock()
        self.connected = connected
        apply()
        lock.unlock()
    }

    func setMode(_ mode: LightingMode) {
        lock.lock()
        self.mode = mode
        apply()
        lock.unlock()
    }

    private func apply() {
        let screenMode = mode == .screen
        if let applied = appliedState, applied.connected == connected, (applied.mode == .screen) == screenMode {
            appliedState = (connected, mode)
            onStateChange?(connected, mode)
            return
        }
        appliedState = (connected, mode)

        if connected && screenMode {
            effects.stop()
            lastFrameBox.clear()
            capture.start()
        } else if connected {
            capture.stop()
            lastFrameBox.clear()
            effects.start()
        } else {
            effects.stop()
            capture.stop()
        }
        onStateChange?(connected, mode)
    }
}
