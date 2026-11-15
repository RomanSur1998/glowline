import Foundation
import QuartzCore

final class LiveEffectSettings {
    @Locked var parameters: EffectParameters

    init(parameters: EffectParameters) {
        self.parameters = parameters
    }
}

final class EffectPlayer {
    private static let animatedInterval: TimeInterval = 1.0 / 30
    private static let staticInterval: TimeInterval = 0.1

    private let settings: LiveEffectSettings
    private let sink: FrameSink
    private let queue = DispatchQueue(label: "glowline.effects")
    private var timer: DispatchSourceTimer?
    private var startTime: CFTimeInterval = 0
    private var lastSentFrame: Data?
    private var lastTickWasAnimated = false

    init(settings: LiveEffectSettings, sink: FrameSink) {
        self.settings = settings
        self.sink = sink
    }

    func start() {
        queue.sync {
            guard timer == nil else { return }
            startTime = CACurrentMediaTime()
            lastSentFrame = nil
            lastTickWasAnimated = settings.parameters.mode.isAnimated
            schedule(animated: lastTickWasAnimated)
            print("Playing effect: \(settings.parameters.mode.title).")
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            lastSentFrame = nil
        }
    }

    private func schedule(animated: Bool) {
        timer?.cancel()
        let interval = animated ? Self.animatedInterval : Self.staticInterval
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval)
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func tick() {
        let parameters = settings.parameters
        guard parameters.mode != .screen else { return }
        if parameters.mode.isAnimated != lastTickWasAnimated {
            lastTickWasAnimated = parameters.mode.isAnimated
            schedule(animated: lastTickWasAnimated)
            return
        }
        let time = CACurrentMediaTime() - startTime
        let colors = EffectRenderer.colors(for: parameters, ledCount: sink.ledCount, time: time)
        let frame = sink.makeFrame(colors, forScreen: false)
        guard frame != lastSentFrame else { return }
        lastSentFrame = frame
        sink.emit(frame)
    }
}
