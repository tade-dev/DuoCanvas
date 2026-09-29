import CanvasModel

/// A drag or slider gesture: many live updates, then one undo step, or a cancel that restores the start.
///
/// Preview updates change the document immediately and do not record undo or advance `revision`.
@MainActor
public final class CoalescedEdit {
    private unowned let manager: CommandManager
    private let actionName: String
    private let start: CanvasDocumentSnapshot
    private var state: State = .open

    private enum State {
        case open
        case ended
        case cancelled
    }

    init(manager: CommandManager, actionName: String, start: CanvasDocumentSnapshot) {
        self.manager = manager
        self.actionName = actionName
        self.start = start
    }

    public func preview(_ body: (CanvasDocument) -> Void) {
        precondition(state == .open, "This edit has already finished.")
        manager.document.withoutRecordingRevision {
            body(manager.document)
        }
    }

    /// Records one undo step when the document differs from the start of the edit.
    public func end() {
        guard state == .open else { return }
        state = .ended
        manager.finishCoalescedEdit(self, start: start, actionName: actionName)
    }

    /// Restores the document to the start of the edit and records nothing.
    public func cancel() {
        guard state == .open else { return }
        state = .cancelled
        manager.discardCoalescedEdit(self, restoring: start)
    }
}
