import AppKit
import Foundation
import ScreenCaptureKit

struct RuntimeError: Error, CustomStringConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var description: String { message }
}

private func printUsage() {
    print(
        """
        Usage: glowline [options]

          --config <path>          Path to JSON config (default: ~/.config/glowline/config.json, then ./config.json)
          --dry-run                Don't open a serial port; capture and compute frames, logging a summary every 60 frames
          --test-frame [r,g,b]     Send one solid-color frame to the configured serial port and exit
                                   (no screen capture involved -- works without Screen Recording permission)
          --test-ends              Lights zone index 0 red, the last zone blue, everything else dim --
                                   walk the strip to see where index 0 physically is and which way
                                   the index increases, to work out startCorner/clockwise. Ctrl+C to stop.
          --list-displays          List capturable displays and exit
          --list-serial-devices    List /dev/cu.* serial devices (with USB vendor/product IDs) and exit
          --help                   Show this help
        """)
}

private func defaultConfigPath() -> String? {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser.path
    let userConfig = "\(home)/.config/glowline/config.json"
    if fm.fileExists(atPath: userConfig) { return userConfig }
    if fm.fileExists(atPath: "config.json") { return "config.json" }
    return nil
}

func runApp() async throws -> AppRuntime {
    var configPath: String?
    var dryRun = false
    var listDisplays = false
    var listSerial = false
    var testColorArg: String?
    var testEnds = false

    var args = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = args.next() {
        switch arg {
        case "--config":
            configPath = args.next()
        case "--dry-run":
            dryRun = true
        case "--test-frame":
            testColorArg = args.next() ?? "255,0,0"
        case "--test-ends":
            testEnds = true
        case "--list-displays":
            listDisplays = true
        case "--list-serial-devices":
            listSerial = true
        case "--help", "-h":
            printUsage()
            exit(0)
        default:
            logError("Unknown argument: \(arg)")
            printUsage()
            exit(64)
        }
    }

    if listSerial {
        let devices = SerialDeviceFinder.listSerialDevices()
        if devices.isEmpty {
            print("No serial devices found.")
        }
        for d in devices {
            let vid = d.vendorID.map { String(format: "0x%04X", $0) } ?? "?"
            let pid = d.productID.map { String(format: "0x%04X", $0) } ?? "?"
            let known = d.vendorID.map { SerialDeviceFinder.knownVendorIDs.contains($0) } ?? false
            print("\(d.path)  vendor=\(vid) product=\(pid)\(known ? "  [likely LED controller]" : "")")
        }
        exit(0)
    }

    if listDisplays {
        let displays = try await ScreenCapture.availableDisplays()
        for (i, d) in displays.enumerated() {
            print("[\(i)] displayID=\(d.displayID) \(d.width)x\(d.height)")
        }
        exit(0)
    }

    let resolvedConfigPath = configPath ?? defaultConfigPath()
    print("Config: \(resolvedConfigPath ?? "<none found, using built-in defaults>")")
    let config = AppConfig.load(path: resolvedConfigPath)
    let zoneLayout = ZoneLayout(config: config.zones)
    print(
        "Zones: top=\(config.zones.top) bottom=\(config.zones.bottom) left=\(config.zones.left) right=\(config.zones.right) total=\(zoneLayout.totalCount), startCorner=\(config.zones.startCorner), clockwise=\(config.zones.clockwise)"
    )
    guard zoneLayout.totalCount > 0 else {
        throw RuntimeError("Zone layout has 0 total LEDs — check top/bottom/left/right in the config")
    }

    _ = try await runDiagnosticCommandIfRequested(
        testColorArg: testColorArg,
        testEnds: testEnds,
        config: config,
        zoneLayout: zoneLayout
    )

    let averager = try MetalZoneAverager(
        zoneLayout: zoneLayout,
        brightness: config.brightness,
        gamma: config.gamma,
        letterboxDetection: config.letterboxDetection,
        letterboxThreshold: config.letterboxThreshold
    )
    let frameSettings = LiveFrameSettings(colorOrder: config.colorOrder, fixedAdaHeader: config.fixedAdaHeader)

    let settingsSavePath =
        resolvedConfigPath ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.config/glowline/config.json"
    let settingsStore = await SettingsStore(config: config, configPath: settingsSavePath, averager: averager, frameSettings: frameSettings)

    let menuBarController = MenuBarController(settingsStore: settingsStore)

    var serialSupervisor: SerialSupervisor?
    if !dryRun {
        serialSupervisor = SerialSupervisor(configuredPath: config.serialPort, baudRate: config.baudRate)
    } else {
        print("Dry run: \(zoneLayout.totalCount) zones, printing Adalight frames instead of writing to serial.")
        menuBarController.updateStatus(.dryRun)
    }

    let lastFrameBox = LastFrameBox()
    let supervisor = CaptureSupervisor(
        config: config, averager: averager, serial: serialSupervisor, lastFrameBox: lastFrameBox, frameSettings: frameSettings)

    signal(SIGINT) { _ in exit(0) }

    let workspaceNC = NSWorkspace.shared.notificationCenter
    workspaceNC.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
        print("System going to sleep -- capture and the LED strip will resume automatically on wake.")
    }
    workspaceNC.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
        print("System woke up -- resuming capture and reconnecting the serial port.")
        supervisor.restartIfNeeded()
        serialSupervisor?.reconnect()
    }

    if let serialSupervisor {
        serialSupervisor.onConnectionChange = { connected in
            if connected {
                supervisor.start()
            } else {
                supervisor.stop()
            }
            menuBarController.updateStatus(connected ? .connected : .disconnected)
        }

        Task {
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if let frame = lastFrameBox.get() {
                    serialSupervisor.send(frame)
                }
            }
        }

        serialSupervisor.reconnect()
    } else {
        supervisor.start()
    }

    return AppRuntime(menuBar: menuBarController, captureSupervisor: supervisor, serialSupervisor: serialSupervisor)
}
