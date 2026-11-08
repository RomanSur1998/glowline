import Foundation
import os

private let logger = Logger(subsystem: "com.surkovroman.glowline", category: "app")

func logError(_ message: String) {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    logger.error("\(message, privacy: .public)")
}
