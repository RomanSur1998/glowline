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
        statusItem.button?.image = StatusIcon.image(.off)

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
            let line: String
            let connected: Bool
            switch status {
            case .connected(let mode):
                line = "Connected · \(Self.describe(mode))"
                connected = true
                self.statusItem.button?.image = StatusIcon.image(.lit)
            case .disconnected:
                line = "Controller not connected"
                connected = false
                self.statusItem.button?.image = StatusIcon.image(.off)
            case .dryRun(let mode):
                line = "Dry run · \(Self.describe(mode))"
                connected = true
                self.statusItem.button?.image = StatusIcon.image(.half)
            }
            self.statusMenuItem.title = "Status: \(line)"
            MainActor.assumeIsolated {
                self.settingsStore.statusLine = line
                self.settingsStore.isConnected = connected
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
        window.title = "Glowline"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = .black
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}

enum StatusIcon {
    enum Style {
        case lit, off, half
    }

    static func image(_ style: Style) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 16), flipped: true) { _ in
            let columns = 5, rows = 4
            let originX: CGFloat = 2, originY: CGFloat = 2
            let pitchX: CGFloat = 4, pitchY: CGFloat = 4
            var index = 0
            for row in 0..<rows {
                for column in 0..<columns where row == 0 || row == rows - 1 || column == 0 || column == columns - 1 {
                    let center = NSPoint(x: originX + CGFloat(column) * pitchX, y: originY + CGFloat(row) * pitchY)
                    let filled: Bool
                    switch style {
                    case .lit: filled = true
                    case .off: filled = false
                    case .half: filled = index % 2 == 0
                    }
                    let radius: CGFloat = filled ? 1.6 : 1.2
                    let path = NSBezierPath(
                        ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                    NSColor.black.setFill()
                    NSColor.black.setStroke()
                    if filled {
                        path.fill()
                    } else {
                        path.lineWidth = 0.8
                        path.stroke()
                    }
                    index += 1
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
