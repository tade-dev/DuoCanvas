import CanvasModel

/// Replaces the whole document content. Coalesced edits use this so one gesture is one undo step.
struct DocumentStateCommand: CanvasCommand {
    let actionName: String
    let previous: CanvasDocumentSnapshot
    let resulting: CanvasDocumentSnapshot

    func apply(to document: CanvasDocument) {
        document.restoreContent(from: resulting)
    }

    func inverse() -> any CanvasCommand {
        DocumentStateCommand(
            actionName: actionName,
            previous: resulting,
            resulting: previous
        )
    }
}
