import CanvasModel
import Foundation

/// One open project editor. It owns the document and the only undo stack for that project.
@MainActor
public final class EditingSession {
    public let document: CanvasDocument
    public let commandManager: CommandManager

    public init(
        document: CanvasDocument? = nil,
        idleInterval: TimeInterval = CommandManager.defaultIdleInterval,
        clock: (any CoalescingClock)? = nil,
        undoRecording: (any UndoRecording)? = nil
    ) {
        let document = document ?? CanvasDocument()
        self.document = document
        self.commandManager = CommandManager(
            document: document,
            idleInterval: idleInterval,
            clock: clock ?? SystemCoalescingClock(),
            undoRecording: undoRecording
        )
    }
}
