import Foundation

enum SuspendReason: String, CaseIterable {
    case macAsleep = "Mac asleep"
    case displayAsleep = "display asleep"
    case screenLocked = "screen locked"
}

struct LightingState: Equatable {
    var connected = false
    var mode: LightingMode
    var enabled: Bool
    var suspensions: Set<SuspendReason> = []

    var isLit: Bool { connected && enabled && suspensions.isEmpty }

    var statusLine: String {
        if !connected { return "Controller not connected" }
        if !enabled { return "Off" }
        if let reason = SuspendReason.allCases.first(where: suspensions.contains) { return "Paused · \(reason.rawValue)" }
        return mode == .screen ? "On · screen sync" : "On · \(mode.title.lowercased())"
    }
}

final class LightingController: @unchecked Sendable {
    private let capture: CaptureSupervisor
    private let effects: EffectPlayer
    private let smoother: ColorSmoother
    private let sink: FrameSink
    private let lock = NSLock()
    private var state: LightingState
    private var applied: (lit: Bool, screen: Bool)?

    var onStateChange: ((LightingState) -> Void)?

    init(capture: CaptureSupervisor, effects: EffectPlayer, smoother: ColorSmoother, sink: FrameSink, mode: LightingMode, enabled: Bool) {
        self.capture = capture
        self.effects = effects
        self.smoother = smoother
        self.sink = sink
        self.state = LightingState(mode: mode, enabled: enabled)
    }

    var currentState: LightingState {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    func setConnected(_ connected: Bool) {
        update { $0.connected = connected }
    }

    func setMode(_ mode: LightingMode) {
        update { $0.mode = mode }
    }

    func setEnabled(_ enabled: Bool) {
        update { $0.enabled = enabled }
    }

    func setSuspended(_ reason: SuspendReason, _ suspended: Bool) {
        update {
            if suspended {
                $0.suspensions.insert(reason)
            } else {
                $0.suspensions.remove(reason)
            }
        }
    }

    private func update(_ change: (inout LightingState) -> Void) {
        lock.lock()
        change(&state)
        let snapshot = state
        apply(snapshot)
        lock.unlock()
        onStateChange?(snapshot)
    }

    private func apply(_ s: LightingState) {
        let target = (lit: s.isLit, screen: s.mode == .screen)
        if let applied, applied == target { return }
        let wasLit = applied?.lit ?? false
        applied = target

        if target.lit && target.screen {
            effects.stop()
            sink.clear()
            capture.start()
        } else if target.lit {
            capture.stop()
            smoother.reset()
            sink.clear()
            effects.start()
        } else {
            effects.stop()
            capture.stop()
            smoother.reset()
            if s.connected {
                sink.sendBlack()
                if wasLit { print("LED strip off (\(s.statusLine)).") }
            } else {
                sink.clear()
            }
        }
    }
}
