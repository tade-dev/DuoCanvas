// swift-tools-version: 6.0

import PackageDescription

// In-memory canvas and command stack for DuoCanvas.
// The app target, when it exists, is iOS 27.1. This package does not import
// SwiftUI, Duo APIs, or SwiftData, so `swift test` runs on Linux.
let package = Package(
    name: "DuoCanvasCore",
    platforms: [
        .iOS("27.1"),
    ],
    products: [
        .library(name: "DuoCanvasCore", targets: ["CanvasModel", "CanvasCommands"]),
    ],
    targets: [
        .target(name: "CanvasModel"),
        .target(
            name: "CanvasCommands",
            dependencies: ["CanvasModel"]
        ),
        .testTarget(
            name: "DuoCanvasCoreTests",
            dependencies: ["CanvasModel", "CanvasCommands"]
        ),
    ]
)
