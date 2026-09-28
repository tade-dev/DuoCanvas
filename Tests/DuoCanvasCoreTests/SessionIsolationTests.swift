import CanvasCommands
import CanvasModel
import Testing

@MainActor
@Suite("Editing sessions")
struct SessionIsolationTests {
    @Test func twoSessionsHaveIndependentUndoStacks() {
        let first = EditingSession()
        let second = EditingSession()
        #expect(first.document.id != second.document.id)

        let box = CanvasElement.rectangle(position: CanvasPoint(x: 1, y: 1))
        let circle = CanvasElement.circle(size: CanvasSize(width: 40, height: 40))
        first.commandManager.insert(box)
        second.commandManager.insert(circle)
        first.commandManager.move(box.id, to: CanvasPoint(x: 4, y: 5))
        second.commandManager.resize(circle.id, to: CanvasSize(width: 20, height: 20))

        first.commandManager.undo()
        #expect(first.document.element(box.id)?.position == CanvasPoint(x: 1, y: 1))
        #expect(first.commandManager.undoActionName == "Insert")
        #expect(first.commandManager.canRedo)
        #expect(second.document.element(circle.id)?.size == CanvasSize(width: 20, height: 20))
        #expect(second.commandManager.undoActionName == "Resize")
        #expect(!second.commandManager.canRedo)

        first.commandManager.undo()
        #expect(first.document.orderedElements.isEmpty)
        #expect(!first.commandManager.canUndo)
        #expect(second.commandManager.canUndo)
        #expect(second.document.element(circle.id) != nil)

        second.commandManager.undo()
        #expect(second.commandManager.undoActionName == "Insert")
        #expect(first.document.orderedElements.isEmpty)
        #expect(second.document.element(circle.id)?.size == CanvasSize(width: 40, height: 40))
    }
}
