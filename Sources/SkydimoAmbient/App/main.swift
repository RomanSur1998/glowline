import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: AppRuntime?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                runtime = try await runApp()
            } catch {
                logError("Error: \(error)")
                exit(1)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
