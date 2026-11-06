import Foundation

actor RetryingResource {
    private let backoffNanoseconds: UInt64
    private let attempt: () async throws -> Void

    private var isRunning = false
    private var attemptInFlight = false

    init(backoffNanoseconds: UInt64, attempt: @escaping () async throws -> Void) {
        self.backoffNanoseconds = backoffNanoseconds
        self.attempt = attempt
    }

    nonisolated func start() {
        Task { await self.beginRunning() }
    }

    nonisolated func stop(_ onStop: @escaping () -> Void) {
        Task {
            if await self.endRunning() {
                onStop()
            }
        }
    }

    nonisolated func retryNow() {
        Task { await self.kickOff(afterBackoff: false) }
    }

    nonisolated func scheduleRestart() {
        Task { await self.kickOff(afterBackoff: true) }
    }

    private func beginRunning() async {
        guard !isRunning else { return }
        isRunning = true
        await kickOff(afterBackoff: false)
    }

    private func endRunning() -> Bool {
        guard isRunning else { return false }
        isRunning = false
        return true
    }

    private func kickOff(afterBackoff: Bool) async {
        guard isRunning, !attemptInFlight else { return }
        attemptInFlight = true
        if afterBackoff {
            try? await Task.sleep(nanoseconds: backoffNanoseconds)
            guard isRunning else {
                attemptInFlight = false
                return
            }
        }
        do {
            try await attempt()
            attemptInFlight = false
        } catch {
            attemptInFlight = false
            scheduleRestart()
        }
    }
}
