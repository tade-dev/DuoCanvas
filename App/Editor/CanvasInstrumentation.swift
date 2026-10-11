import os

/// Instruments intervals for the editing hot path.
///
/// Profile with the Points of Interest instrument. Subsystem `dev.tade.DuoCanvas`,
/// category `Editing`. Intervals: `DragPreview`, `CommandCommit`, `ProjectSave`, `PNGExport`.
enum CanvasInstrumentation {
    static let subsystem = "dev.tade.DuoCanvas"
    static let log = Logger(subsystem: subsystem, category: "Editing")

    static let dragPreview: StaticString = "DragPreview"
    static let commandCommit: StaticString = "CommandCommit"
    static let projectSave: StaticString = "ProjectSave"
    static let pngExport: StaticString = "PNGExport"

    private static let signposter = OSSignposter(subsystem: subsystem, category: "Editing")

    static func begin(_ name: StaticString) -> OSSignpostIntervalState {
        signposter.beginInterval(name, id: signposter.makeSignpostID())
    }

    static func end(_ name: StaticString, _ state: OSSignpostIntervalState) {
        signposter.endInterval(name, state)
    }
}
