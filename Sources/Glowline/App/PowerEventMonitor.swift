import AppKit
import Foundation

final class PowerEventMonitor {
    private let lighting: LightingController
    private let options: () -> AutoOffOptions
    private var displayAsleep = false
    private var screenLocked = false
    private var macAsleep = false
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []

    var onWake: (() -> Void)?

    init(lighting: LightingController, options: @escaping () -> AutoOffOptions) {
        self.lighting = lighting
        self.options = options
    }

    func start() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.displayAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.displayAsleep = false }
        observe(workspace, NSWorkspace.willSleepNotification) { monitor in
            print("System going to sleep.")
            monitor.macAsleep = true
        }
        observe(workspace, NSWorkspace.didWakeNotification) { monitor in
            print("System woke up -- resuming.")
            monitor.macAsleep = false
            monitor.onWake?()
        }
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.screenLocked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.screenLocked = false }
    }

    func reevaluate() {
        let o = options()
        lighting.setSuspended(.macAsleep, macAsleep && o.whenMacSleeps)
        lighting.setSuspended(.displayAsleep, displayAsleep && o.whenDisplaySleeps)
        lighting.setSuspended(.screenLocked, screenLocked && o.whenScreenLocked)
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ change: @escaping (PowerEventMonitor) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let wasLit = self.lighting.currentState.isLit
            change(self)
            self.reevaluate()
            if name == NSWorkspace.willSleepNotification, wasLit, !self.lighting.currentState.isLit {
                Thread.sleep(forTimeInterval: 0.15)
            }
        }
        tokens.append((center, token))
    }
}
