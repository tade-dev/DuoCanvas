import SwiftData

/// The one store for the app. Previews pass `inMemory: true`.
///
/// `ModelContainer(for:migrationPlan:)` has no `isUndoEnabled` parameter. The convenience
/// `modelContainer(for:isUndoEnabled:)` modifier cannot take this migration plan, so the
/// same choice is applied here: `mainContext.undoManager` stays nil. That is what
/// `isUndoEnabled: false` does. Canvas commands keep the only undo stack.
@MainActor
enum DuoCanvasModelContainer {
    static func make(inMemory: Bool) -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(
                for: schema,
                migrationPlan: DuoCanvasMigrationPlan.self,
                configurations: [configuration]
            )
            container.mainContext.undoManager = nil
            container.mainContext.autosaveEnabled = true
            return container
        } catch {
            fatalError("Could not open the DuoCanvas store: \(error)")
        }
    }
}
