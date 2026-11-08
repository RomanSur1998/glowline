// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Glowline",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Glowline",
            path: "Sources/Glowline",
            resources: []
        ),
        .testTarget(
            name: "GlowlineTests",
            dependencies: ["Glowline"],
            path: "Tests/GlowlineTests"
        ),
    ]
)
