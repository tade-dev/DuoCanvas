import Foundation
import Testing

struct SourceIsolationTests {
    private static let forbidden = [
        "ArrangementView",
        "arrangementViewStyle",
        "splitArrangement",
        "overlayArrangement",
        "ReservedRegion",
        "reservedRegions",
        "DeviceHinge",
        "onHingeChange",
        "UserInterfaceSizeClass",
        "SwiftData",
        "ModelContext",
        "VersionedSchema",
        "SchemaMigrationPlan",
    ]

    @Test func canvasAndCoreDoNotNameDuoOrPersistenceApis() throws {
        let root = try repositoryRoot()
        let directories = [
            "Sources/CanvasModel",
            "Sources/CanvasCommands",
            "Sources/AdaptiveLayout",
            "Sources/PersistenceMapping",
            "App/Canvas",
        ]
        for directory in directories {
            let files = try swiftFiles(in: root.appendingPathComponent(directory))
            #expect(!files.isEmpty, "Expected Swift sources in \(directory)")
            for file in files {
                let source = try String(contentsOf: file, encoding: .utf8)
                for symbol in Self.forbidden {
                    #expect(
                        !source.contains(symbol),
                        "\(directory)/\(file.lastPathComponent) names \(symbol)"
                    )
                }
            }
        }
    }

    @Test func duoLayerCallsTheSystemApisAndDoesNotDefineThem() throws {
        let root = try repositoryRoot()
        let files = try swiftFiles(in: root.appendingPathComponent("App/Duo"))
        let source = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        #expect(source.contains("ArrangementView"))
        #expect(source.contains("arrangementViewStyle(.split)"))
        #expect(source.contains("splitArrangementLayoutSize"))
        #expect(source.contains("reservedRegions"))
        #expect(source.contains("onHingeChange"))
        #expect(!source.contains("struct ArrangementView"))
        #expect(!source.contains("func reservedRegions"))
        #expect(!source.contains("func onHingeChange"))
    }

    private func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let manager = FileManager.default
        while url.path != "/" {
            if manager.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        Issue.record("Package.swift was not found above the test file")
        throw CocoaError(.fileNoSuchFile)
    }

    private func swiftFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "swift" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
