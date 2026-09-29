import CanvasModel
import Foundation
import SwiftData

/// Create, rename, delete, and recency updates for the home list.
///
/// These are project records, not canvas commands, so they do not enter the editor undo stack.
@MainActor
struct ProjectLibrary {
    var context: ModelContext

    func createProject(name: String, now: Date = .now) throws -> UUID {
        let id = UUID()
        let background = CanvasColor.white
        let size = CanvasSize.defaultArtboard
        let project = ProjectRecord(
            id: id,
            name: Self.resolvedName(name),
            createdAt: now,
            modifiedAt: now,
            lastOpenedAt: now,
            canvasWidth: size.width,
            canvasHeight: size.height,
            backgroundRed: background.red,
            backgroundGreen: background.green,
            backgroundBlue: background.blue,
            backgroundAlpha: background.alpha
        )
        context.insert(project)
        try context.save()
        return id
    }

    func rename(_ project: ProjectRecord, to name: String, now: Date = .now) throws {
        project.name = Self.resolvedName(name)
        project.modifiedAt = now
        try context.save()
    }

    func delete(_ project: ProjectRecord) throws {
        context.delete(project)
        try context.save()
    }

    func markOpened(_ project: ProjectRecord, now: Date = .now) throws {
        project.lastOpenedAt = now
        try context.save()
    }

    static func resolvedName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
