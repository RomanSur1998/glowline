import AppKit
import SwiftUI

enum ConnectionStatus {
    case connected
    case disconnected
    case dryRun
}

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        super.init()
        if Thread.isMainThread {
            setUp()
        } else {
            DispatchQueue.main.sync { setUp() }
        }
    }

    private func setUp() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "⏳"

        statusMenuItem = NSMenuItem(title: "Status: starting…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false

        let menu = NSMenu()
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let restartItem = NSMenuItem(title: "Restart", action: #selector(restart), keyEquivalent: "r")
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func updateStatus(_ status: ConnectionStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch status {
            case .connected:
                self.statusItem.button?.title = "💡"
                self.statusMenuItem.title = "Status: controller connected, capturing"
            case .disconnected:
                self.statusItem.button?.title = "🌑"
                self.statusMenuItem.title = "Status: controller not connected, capture paused"
            case .dryRun:
                self.statusItem.button?.title = "🧪"
                self.statusMenuItem.title = "Status: dry run (--dry-run), serial port not used"
            }
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeSettingsWindow()
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func restart() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        do {
            try task.run()
        } catch {
            logError("Restart failed: could not launch a new instance (\(error)) -- not quitting the current one.")
            return
        }
        NSApp.terminate(nil)
    }

    private func makeSettingsWindow() -> NSWindow {
        let hosting = NSHostingController(
            rootView: SettingsView(store: settingsStore, onRestart: { [weak self] in self?.restart() })
        )

        let window = NSWindow(contentViewController: hosting)
        window.title = "SkydimoAmbient — Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
