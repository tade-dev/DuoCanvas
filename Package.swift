// swift-tools-version: 6.0

import PackageDescription

// In-memory canvas, command stack, layout decision, and the plain project mapping.
// The iOS app is the Xcode target next to this package. It is iOS 27.1.
// This package does not import SwiftUI, Duo APIs, or SwiftData, so `swift test` runs on Linux.
let package = Package(
    name: "DuoCanvasCore",
    platforms: [
        .iOS("27.1"),
    ],
    products: [
        .library(
            name: "DuoCanvasCore",
            targets: ["CanvasModel", "CanvasCommands", "AdaptiveLayout", "PersistenceMapping"]
        ),
    ],
    targets: [
        .target(name: "CanvasModel"),
        .target(
            name: "CanvasCommands",
            dependencies: ["CanvasModel"]
        ),
        .target(
            name: "AdaptiveLayout",
            dependencies: ["CanvasModel"]
        ),
        .target(
            name: "PersistenceMapping",
            dependencies: ["CanvasModel"]
        ),
        .testTarget(
            name: "DuoCanvasCoreTests",
            dependencies: ["CanvasModel", "CanvasCommands", "AdaptiveLayout", "PersistenceMapping"]
        ),
    ]
)
