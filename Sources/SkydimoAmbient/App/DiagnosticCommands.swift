import Foundation

private func describeBytes(_ data: Data) -> String {
    let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
    let ascii = String(data.map { (32...126).contains($0) ? Character(UnicodeScalar($0)) : "." })
    return "hex=[\(hex)] ascii=\"\(ascii)\""
}

func runDiagnosticCommandIfRequested(
    testColorArg: String?,
    testEnds: Bool,
    config: AppConfig,
    zoneLayout: ZoneLayout
) async throws -> Bool {
    if let testColorArg {
        let parts = testColorArg.split(separator: ",").compactMap { UInt8($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 3 else {
            throw RuntimeError("--test-frame expects \"r,g,b\" (0-255 each), got \"\(testColorArg)\"")
        }
        guard let path = config.serialPort ?? SkydimoDeviceFinder.autoDetect() else {
            throw RuntimeError("No serial port configured and none auto-detected. Set \"serialPort\" in config.json.")
        }
        let serial = try SerialPort(path: path, baudRate: config.baudRate)
        print("Opened \(path); waiting for the controller to finish booting...")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        let greeting = serial.drainAvailable(forMs: 1500)
        if !greeting.isEmpty {
            print("Controller greeting (\(greeting.count) bytes): \(describeBytes(greeting))")
        } else {
            print("No greeting bytes received from controller (may not send one, or already past it).")
        }
        let color = (parts[0], parts[1], parts[2])
        let frame = AdalightFrame.build(
            colors: Array(repeating: color, count: zoneLayout.totalCount), colorOrder: config.colorOrder, fixedHeader: config.fixedAdaHeader
        )
        for _ in 0..<20 {
            try serial.write(frame)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        print(
            "Sent \(zoneLayout.totalCount)-LED test frame (\(color.0),\(color.1),\(color.2)) to \(path) at \(config.baudRate) baud (repeated for ~1s)."
        )
        exit(0)
    }

    if testEnds {
        guard let path = config.serialPort ?? SkydimoDeviceFinder.autoDetect() else {
            throw RuntimeError("No serial port configured and none auto-detected. Set \"serialPort\" in config.json.")
        }
        let serial = try SerialPort(path: path, baudRate: config.baudRate)
        print("Opened \(path); waiting for the controller to finish booting...")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        var colors = Array(repeating: (UInt8(10), UInt8(10), UInt8(10)), count: zoneLayout.totalCount)
        colors[0] = (255, 0, 0)
        colors[colors.count - 1] = (0, 0, 255)
        let frame = AdalightFrame.build(colors: colors, colorOrder: config.colorOrder, fixedHeader: config.fixedAdaHeader)
        print("--test-ends: zone 0 = RED, zone \(colors.count - 1) = BLUE, rest dim. Ctrl+C to stop.")
        while true {
            try serial.write(frame)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    return false
}
