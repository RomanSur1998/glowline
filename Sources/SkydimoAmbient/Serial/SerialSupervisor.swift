import Foundation

enum SerialSupervisorError: Error {
    case noDeviceFound
}

final class SerialSupervisor: @unchecked Sendable {
    private let configuredPath: String?
    private let baudRate: Int
    @Locked private var current: AsyncFrameSender? = nil
    private let resource: RetryingResource

    var onConnectionChange: ((Bool) -> Void)?

    init(configuredPath: String?, baudRate: Int) {
        self.configuredPath = configuredPath
        self.baudRate = baudRate
        var attempt: (() async throws -> Void)!
        self.resource = RetryingResource(backoffNanoseconds: 5_000_000_000) { try await attempt() }
        attempt = { [weak self] in try await self?.connectAttempt() }
    }

    func send(_ frame: Data) {
        current?.send(frame)
    }

    func reconnect() {
        resource.start()
        resource.retryNow()
    }

    private func connectAttempt() async throws {
        guard let path = configuredPath ?? SkydimoDeviceFinder.autoDetect() else {
            print("Skydimo not connected -- waiting (checking every 5s)...")
            onConnectionChange?(false)
            throw SerialSupervisorError.noDeviceFound
        }
        do {
            let serial = try SerialPort(path: path, baudRate: baudRate)
            print("Connected to \(path) at \(baudRate) baud. Waiting for the controller to finish booting...")
            try await Task.sleep(nanoseconds: 2_000_000_000)
            let greeting = serial.drainAvailable(forMs: 1500)
            if !greeting.isEmpty {
                print("Controller greeting (\(greeting.count) bytes)")
            } else {
                print("No greeting bytes received from controller.")
            }
            var loggedError = false
            let newSender = AsyncFrameSender(serial: serial)
            newSender.onError = { [weak self] error in
                if !loggedError {
                    loggedError = true
                    logError("Serial write error: \(error) -- reconnecting.")
                }
                self?.onConnectionChange?(false)
                self?.resource.retryNow()
            }
            current = newSender
            onConnectionChange?(true)
        } catch {
            logError("Failed to open serial port \(path): \(error) -- retrying in 5s.")
            onConnectionChange?(false)
            throw error
        }
    }
}
