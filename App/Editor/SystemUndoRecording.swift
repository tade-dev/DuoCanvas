import CanvasCommands
import Foundation

/// Forwards the session's undo stack to a real `UndoManager`.
///
/// One editor owns one `UndoManager`. The view installs that same object as the
/// environment undo manager, so toolbar buttons and the system gestures share one history.
@MainActor
final class SystemUndoRecording: UndoRecording {
    let undoManager: UndoManager

    init(undoManager: UndoManager) {
        self.undoManager = undoManager
    }

    var canUndo: Bool { undoManager.canUndo }
    var canRedo: Bool { undoManager.canRedo }
    var undoActionName: String { undoManager.undoActionName }
    var redoActionName: String { undoManager.redoActionName }

    func undo() {
        undoManager.undo()
    }

    func redo() {
        undoManager.redo()
    }

    func registerUndo(withTarget target: CommandManager, handler: @escaping (CommandManager) -> Void) {
        undoManager.registerUndo(withTarget: target, handler: handler)
    }

    func setActionName(_ actionName: String) {
        undoManager.setActionName(actionName)
    }
}
