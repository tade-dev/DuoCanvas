import CanvasCommands
import CanvasModel
import Testing

@MainActor
@Suite("Text commands")
struct TextCommandTests {
    @Test func textUndoRedoRestoresEveryField() {
        let session = EditingSession()
        let element = CanvasElement.text("Hello")
        let commands = session.commandManager
        commands.insert(element)
        let before = session.document.copy()

        commands.updateText(of: element.id) { text in
            text.string = "Edited"
            text.fontName = "Avenir Next"
            text.fontSize = 32
            text.fontWeight = .bold
            text.alignment = .center
            text.color = CanvasColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 1)
        }
        #expect(commands.undoActionName == "Text")
        let edited = session.document.copy()

        commands.undo()
        #expect(session.document == before)
        #expect(commands.redoActionName == "Text")
        commands.redo()
        #expect(session.document == edited)
    }

    @Test func textActionNamesFollowTheChangedField() {
        let session = EditingSession()
        let element = CanvasElement.text("Hello")
        let commands = session.commandManager
        commands.insert(element)

        commands.updateText(of: element.id) { $0.fontName = "Georgia" }
        #expect(commands.undoActionName == "Font")

        commands.updateText(of: element.id) { $0.fontSize = 22 }
        #expect(commands.undoActionName == "Size")

        commands.updateText(of: element.id) { $0.fontWeight = .semibold }
        #expect(commands.undoActionName == "Weight")

        commands.updateText(of: element.id) { $0.alignment = .trailing }
        #expect(commands.undoActionName == "Alignment")

        commands.updateText(of: element.id) { $0.color = .white }
        #expect(commands.undoActionName == "Text Color")

        commands.updateText(of: element.id) { $0.string = "Next" }
        #expect(commands.undoActionName == "Text")

        commands.undo()
        #expect(session.document.element(element.id)?.text?.string == "Hello")
        #expect(session.document.element(element.id)?.text?.color == .white)
    }

    @Test func unchangedTextIsNotAnUndoStep() {
        let session = EditingSession()
        let element = CanvasElement.text("Hello")
        let commands = session.commandManager
        commands.insert(element)
        let revision = session.document.revision

        commands.updateText(of: element.id) { $0.fontSize = 17 }
        #expect(commands.undoActionName == "Insert")
        #expect(session.document.revision == revision)
    }

    @Test func updateTextOnAShapeDoesNothing() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let revision = session.document.revision

        commands.updateText(of: element.id) { $0.string = "No" }
        #expect(session.document.element(element.id)?.text == nil)
        #expect(session.document.revision == revision)
        #expect(commands.undoActionName == "Insert")
    }

    @Test func textColorInsideTheIdleWindowIsOneStep() {
        let clock = ManualClock()
        let session = EditingSession(idleInterval: 0.5, clock: clock)
        let element = CanvasElement.text("Hello")
        let commands = session.commandManager
        commands.insert(element)
        let afterInsert = session.document.copy()
        let red = CanvasColor(red: 1, green: 0, blue: 0, alpha: 1)
        let blue = CanvasColor(red: 0, green: 0, blue: 1, alpha: 1)

        func paint(_ color: CanvasColor, at time: Double) {
            clock.time = time
            commands.recordContinuousEdit(
                key: ContinuousEditKey(elementID: element.id, property: .textColor)
            ) { document in
                document.update(element.id) { element in
                    guard var text = element.text else { return }
                    text.color = color
                    element.text = text
                }
            }
        }

        paint(red, at: 0)
        paint(blue, at: 0.4)
        #expect(commands.undoActionName == "Insert")
        clock.time = 1
        commands.flushExpiredContinuousEdits()
        #expect(commands.undoActionName == "Text Color")

        commands.undo()
        #expect(session.document == afterInsert)
        commands.redo()
        #expect(session.document.element(element.id)?.text?.color == blue)
    }
}
