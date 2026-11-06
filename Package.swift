// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SkydimoAmbient",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SkydimoAmbient",
            path: "Sources/SkydimoAmbient",
            resources: []
        ),
        .testTarget(
            name: "SkydimoAmbientTests",
            dependencies: ["SkydimoAmbient"],
            path: "Tests/SkydimoAmbientTests"
        ),
    ]
)
