import Foundation
import QuartzCore

final class ColorSmoother {
    static let tickInterval: TimeInterval = 1.0 / 30
    static let settleThreshold = 0.5

    private let timeConstant: () -> Double
    private let emit: ([(UInt8, UInt8, UInt8)]) -> Void
    private let queue = DispatchQueue(label: "glowline.smoothing")
    private var current: [Double] = []
    private var target: [Double] = []
    private var timer: DispatchSourceTimer?
    private var lastTick: CFTimeInterval = 0

    init(timeConstant: @escaping () -> Double, emit: @escaping ([(UInt8, UInt8, UInt8)]) -> Void) {
        self.timeConstant = timeConstant
        self.emit = emit
    }

    static func step(current: [Double], target: [Double], dt: Double, timeConstant: Double) -> [Double] {
        guard timeConstant > 0, current.count == target.count else { return target }
        let alpha = 1 - exp(-max(dt, 0) / timeConstant)
        return zip(current, target).map { c, t in c + (t - c) * alpha }
    }

    static func flatten(_ colors: [(UInt8, UInt8, UInt8)]) -> [Double] {
        colors.flatMap { [Double($0.0), Double($0.1), Double($0.2)] }
    }

    static func unflatten(_ values: [Double]) -> [(UInt8, UInt8, UInt8)] {
        stride(from: 0, to: values.count - 2, by: 3).map { i in
            (byte(values[i]), byte(values[i + 1]), byte(values[i + 2]))
        }
    }

    private static func byte(_ v: Double) -> UInt8 {
        UInt8(min(max(v, 0), 255).rounded())
    }

    func push(_ colors: [(UInt8, UInt8, UInt8)]) {
        queue.async { [self] in
            target = Self.flatten(colors)
            if timeConstant() <= 0 || current.count != target.count {
                current = target
                stopTimer()
                emit(colors)
                return
            }
            if timer == nil {
                lastTick = CACurrentMediaTime()
                let t = DispatchSource.makeTimerSource(queue: queue)
                t.schedule(deadline: .now(), repeating: Self.tickInterval)
                t.setEventHandler { [weak self] in self?.tick() }
                timer = t
                t.resume()
            }
        }
    }

    func reset() {
        queue.sync {
            stopTimer()
            current = []
            target = []
        }
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = now - lastTick
        lastTick = now
        current = Self.step(current: current, target: target, dt: dt, timeConstant: timeConstant())
        let settled = zip(current, target).allSatisfy { abs($0 - $1) < Self.settleThreshold }
        if settled {
            current = target
            stopTimer()
        }
        emit(Self.unflatten(current))
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
