/// The undo stack an editing session records into.
///
/// The default is `SessionUndoManager`, because `Foundation.UndoManager` is not in the
/// Swift toolchain this package is tested with. An app target can pass a recorder that
/// forwards to a real `UndoManager`, and system undo gestures then hit the same history.
@MainActor
public protocol UndoRecording: AnyObject {
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    var undoActionName: String { get }
    var redoActionName: String { get }

    func undo()
    func redo()
    func registerUndo(withTarget target: CommandManager, handler: @escaping (CommandManager) -> Void)
    func setActionName(_ actionName: String)
}
