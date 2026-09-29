import CanvasModel
import Foundation

/// One open project editor. It owns the document, its image bytes, and the only undo stack.
@MainActor
public final class EditingSession {
    public let document: CanvasDocument
    public let imageStore: CanvasImageStore
    public let commandManager: CommandManager

    public init(
        document: CanvasDocument? = nil,
        imageStore: CanvasImageStore? = nil,
        idleInterval: TimeInterval = CommandManager.defaultIdleInterval,
        clock: (any CoalescingClock)? = nil,
        undoRecording: (any UndoRecording)? = nil
    ) {
        let document = document ?? CanvasDocument()
        self.document = document
        self.imageStore = imageStore ?? CanvasImageStore()
        self.commandManager = CommandManager(
            document: document,
            idleInterval: idleInterval,
            clock: clock ?? SystemCoalescingClock(),
            undoRecording: undoRecording
        )
    }
}
