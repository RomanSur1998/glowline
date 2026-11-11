import AppKit
import SwiftUI

enum ConnectionStatus {
    case connected(LightingMode)
    case disconnected
    case dryRun(LightingMode)
}

final class MenuBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var modeItems: [LightingMode: NSMenuItem] = [:]
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

        for mode in LightingMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            modeItems[mode] = item
            menu.addItem(item)
        }
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

        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let current = MainActor.assumeIsolated { settingsStore.lightingMode }
        for (mode, item) in modeItems {
            item.state = mode == current ? .on : .off
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let mode = LightingMode(rawValue: raw) else { return }
        MainActor.assumeIsolated { settingsStore.lightingMode = mode }
    }

    private static func describe(_ mode: LightingMode) -> String {
        mode == .screen ? "mirroring the screen" : mode.title.lowercased()
    }

    func updateStatus(_ status: ConnectionStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch status {
            case .connected(let mode):
                self.statusItem.button?.title = "💡"
                self.statusMenuItem.title = "Status: connected, \(Self.describe(mode))"
            case .disconnected:
                self.statusItem.button?.title = "🌑"
                self.statusMenuItem.title = "Status: controller not connected"
            case .dryRun(let mode):
                self.statusItem.button?.title = "🧪"
                self.statusMenuItem.title = "Status: dry run, \(Self.describe(mode))"
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
        window.title = "Glowline — Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
