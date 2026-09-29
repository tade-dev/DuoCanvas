import CanvasCommands
import CanvasModel
import Testing

@MainActor
final class UndoRecordingSpy: UndoRecording {
    var canUndo = false
    var canRedo = false
    var undoActionName = ""
    var redoActionName = ""
    var registrations = 0
    var actionNames: [String] = []
    var undoCalls = 0

    func undo() {
        undoCalls += 1
    }

    func redo() {}

    func registerUndo(withTarget target: CommandManager, handler: @escaping (CommandManager) -> Void) {
        registrations += 1
        _ = target
        _ = handler
    }

    func setActionName(_ actionName: String) {
        actionNames.append(actionName)
    }
}

@MainActor
@Suite("Undo recording")
struct UndoRecordingTests {
    @Test func injectedRecorderReplacesTheSessionStack() {
        let spy = UndoRecordingSpy()
        let session = EditingSession(undoRecording: spy)
        let element = CanvasElement.rectangle()
        let commands = session.commandManager

        commands.insert(element)
        commands.rotate(element.id, to: CanvasRotation(degrees: 15))

        #expect(spy.registrations == 2)
        #expect(spy.actionNames == ["Insert", "Rotate"])
        #expect(!commands.canUndo)
        #expect(session.document.element(element.id)?.rotation.degrees == 15)

        commands.undo()
        #expect(spy.undoCalls == 1)
        #expect(session.document.element(element.id)?.rotation.degrees == 15)
    }

    @Test func unchangedRotateDoesNotRegister() {
        let spy = UndoRecordingSpy()
        let element = CanvasElement.circle(position: CanvasPoint(x: 1, y: 1))
        let session = EditingSession(
            document: CanvasDocument(elements: [element]),
            undoRecording: spy
        )

        session.commandManager.rotate(element.id, to: .zero)
        #expect(spy.registrations == 0)
        #expect(spy.actionNames.isEmpty)
    }

    @Test func anEmptyStackCanTakeANewRecorder() {
        let session = EditingSession()
        let spy = UndoRecordingSpy()
        #expect(session.commandManager.replaceUndoRecordingIfEmpty(with: spy))

        session.commandManager.insert(CanvasElement.rectangle())
        #expect(spy.registrations == 1)
        #expect(spy.actionNames == ["Insert"])
    }

    @Test func aRecordedStepBlocksReplacingTheRecorder() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        session.commandManager.insert(element)
        let before = session.document.copy()
        let spy = UndoRecordingSpy()

        #expect(!session.commandManager.replaceUndoRecordingIfEmpty(with: spy))
        session.commandManager.undo()
        #expect(session.document != before)
        #expect(session.document.element(element.id) == nil)
        #expect(spy.registrations == 0)
        #expect(spy.undoCalls == 0)
    }
}
