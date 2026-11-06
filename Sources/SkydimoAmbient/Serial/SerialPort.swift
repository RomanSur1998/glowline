import Darwin
import Foundation

enum SerialPortError: Error, CustomStringConvertible {
    case openFailed(String)
    case configFailed(String)
    case writeFailed(String)

    var description: String {
        switch self {
        case .openFailed(let p): return "Failed to open serial port \(p): \(String(cString: strerror(errno)))"
        case .configFailed(let step): return "Failed to configure serial port (\(step)): \(String(cString: strerror(errno)))"
        case .writeFailed(let step): return "Serial write failed (\(step)): \(String(cString: strerror(errno)))"
        }
    }
}

private let IOSSIOSPEED: UInt = 0x80085402

final class SerialPort {
    private let fd: Int32
    private let closeLock = NSLock()
    private var isClosed = false

    init(path: String, baudRate: Int) throws {
        let opened = open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard opened >= 0 else { throw SerialPortError.openFailed(path) }
        fd = opened

        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)

        var tty = termios()
        guard tcgetattr(fd, &tty) == 0 else {
            close(fd)
            throw SerialPortError.configFailed("tcgetattr")
        }
        cfmakeraw(&tty)
        tty.c_cflag |= tcflag_t(CLOCAL | CREAD | CSTOPB)
        guard tcsetattr(fd, TCSANOW, &tty) == 0 else {
            close(fd)
            throw SerialPortError.configFailed("tcsetattr")
        }

        var speed = speed_t(baudRate)
        guard ioctl(fd, IOSSIOSPEED, &speed) == 0 else {
            close(fd)
            throw SerialPortError.configFailed("IOSSIOSPEED(\(baudRate))")
        }
    }

    func write(_ data: Data, timeoutMs: Int = 3000) throws {
        let watchdog = DispatchWorkItem { [weak self] in
            logError("Serial write stalled for \(timeoutMs)ms -- forcing the port closed to unblock it.")
            self?.forceClose()
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: watchdog)
        defer { watchdog.cancel() }

        try data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard var pointer = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            var remaining = raw.count
            while remaining > 0 {
                let n = Darwin.write(fd, pointer, remaining)
                if n < 0 {
                    if errno == EINTR { continue }
                    throw SerialPortError.writeFailed("write()")
                }
                pointer += n
                remaining -= n
            }
        }
        guard tcdrain(fd) == 0 else {
            throw SerialPortError.writeFailed("tcdrain")
        }
    }

    private func forceClose() {
        closeLock.lock()
        defer { closeLock.unlock() }
        guard !isClosed else { return }
        isClosed = true
        close(fd)
    }

    @discardableResult
    func readByte(timeoutMs: Int32) -> UInt8? {
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        guard poll(&pfd, 1, timeoutMs) > 0, Int32(pfd.revents) & POLLIN != 0 else { return nil }
        var byte: UInt8 = 0
        let n = Darwin.read(fd, &byte, 1)
        return n == 1 ? byte : nil
    }

    func drainAvailable(forMs durationMs: Int32) -> Data {
        var result = Data()
        let deadline = Date().addingTimeInterval(Double(durationMs) / 1000.0)
        while Date() < deadline {
            let remainingMs = Int32(max(0, deadline.timeIntervalSinceNow * 1000))
            guard let byte = readByte(timeoutMs: min(50, max(1, remainingMs))) else { continue }
            result.append(byte)
        }
        return result
    }

    deinit {
        forceClose()
    }
}

final class AsyncFrameSender {
    private let serial: SerialPort
    private let queue = DispatchQueue(label: "skydimo.serial")
    private let lock = NSLock()
    private var pending: Data?
    private var draining = false
    var onError: ((Error) -> Void)?

    init(serial: SerialPort) {
        self.serial = serial
    }

    func send(_ frame: Data) {
        lock.lock()
        pending = frame
        let alreadyDraining = draining
        draining = true
        lock.unlock()
        guard !alreadyDraining else { return }
        queue.async { [weak self] in self?.drain() }
    }

    private func drain() {
        while true {
            lock.lock()
            guard let frame = pending else {
                draining = false
                lock.unlock()
                return
            }
            pending = nil
            lock.unlock()

            do {
                try serial.write(frame)
                serial.readByte(timeoutMs: 50)
            } catch {
                onError?(error)
            }
        }
    }
}
