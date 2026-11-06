import Foundation
import os

private let logger = Logger(subsystem: "com.surkovroman.skydimoambient", category: "app")

func logError(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    logger.error("\(message, privacy: .public)")
}
