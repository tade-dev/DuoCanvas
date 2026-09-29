import CanvasCommands
import CanvasModel
import Foundation
import Testing

@MainActor
@Suite("Commands")
struct CommandTests {
    @Test func insertUndoRedoRestoresTheSameDocument() {
        let session = EditingSession()
        let original = session.document.copy()
        let element = CanvasElement.rectangle(
            position: CanvasPoint(x: 10, y: 20),
            size: CanvasSize(width: 30, height: 40),
            rotation: CanvasRotation(degrees: 15)
        )

        session.commandManager.insert(element)
        let inserted = session.document.copy()
        #expect(session.document.element(element.id) == element)
        #expect(session.document.order == [element.id])

        session.commandManager.undo()
        #expect(session.document == original)

        session.commandManager.redo()
        #expect(session.document == inserted)
    }

    @Test func moveUndoRedoRestoresTheSameDocument() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(position: CanvasPoint(x: 1, y: 2))
        let commands = session.commandManager
        commands.insert(element)
        let placed = session.document.copy()

        commands.move(element.id, to: CanvasPoint(x: 80, y: 90))
        let moved = session.document.copy()
        #expect(commands.undoActionName == "Move")

        commands.undo()
        #expect(session.document == placed)

        commands.redo()
        #expect(session.document == moved)
        #expect(session.document.element(element.id)?.position == CanvasPoint(x: 80, y: 90))
    }

    @Test func deleteUndoRestoresElementAndZOrder() {
        let session = EditingSession()
        let back = CanvasElement.rectangle(position: CanvasPoint(x: 1, y: 1))
        let middle = CanvasElement.roundedRectangle(
            position: CanvasPoint(x: 2, y: 2),
            cornerRadius: 8,
            fill: Paint(color: CanvasColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        )
        let front = CanvasElement.circle(position: CanvasPoint(x: 3, y: 3))
        let commands = session.commandManager
        commands.insert(back)
        commands.insert(middle)
        commands.insert(front)
        let beforeDelete = session.document.copy()

        commands.delete(middle.id)
        #expect(session.document.order == [back.id, front.id])
        #expect(session.document.element(middle.id) == nil)
        #expect(commands.undoActionName == "Delete")

        commands.undo()
        #expect(session.document == beforeDelete)
        #expect(session.document.order == [back.id, middle.id, front.id])
        #expect(session.document.element(middle.id) == middle)

        commands.redo()
        #expect(session.document.order == [back.id, front.id])

        commands.undo()
        commands.delete(back.id)
        #expect(session.document.order == [middle.id, front.id])
        commands.undo()
        #expect(session.document.order == [back.id, middle.id, front.id])
    }

    @Test func insertAtIndexSurvivesUndo() {
        let session = EditingSession()
        let back = CanvasElement.rectangle()
        let front = CanvasElement.circle()
        let middle = CanvasElement.text("Label")
        let commands = session.commandManager
        commands.insert(back)
        commands.insert(front)
        commands.insert(middle, at: 1)

        #expect(session.document.order == [back.id, middle.id, front.id])
        commands.undo()
        #expect(session.document.order == [back.id, front.id])
        commands.redo()
        #expect(session.document.order == [back.id, middle.id, front.id])
        #expect(session.document.element(middle.id)?.text?.string == "Label")
    }

    @Test func resizeUndoRedoRestoresSize() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(size: CanvasSize(width: 40, height: 50))
        let commands = session.commandManager
        commands.insert(element)
        let before = session.document.copy()

        commands.resize(element.id, to: CanvasSize(width: 200, height: 80))
        #expect(commands.undoActionName == "Resize")
        let resized = session.document.copy()

        commands.undo()
        #expect(session.document == before)
        commands.redo()
        #expect(session.document == resized)
    }

    @Test func styleUndoRedoRestoresAppearance() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let before = session.document.copy()
        let red = Paint(color: CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))

        commands.updateStyle(of: element.id) { style in
            style.fill = red
        }
        #expect(commands.undoActionName == "Fill")
        let filled = session.document.copy()

        commands.undo()
        #expect(session.document == before)
        #expect(commands.redoActionName == "Fill")
        commands.redo()
        #expect(session.document == filled)
        #expect(session.document.element(element.id)?.fill == red)
    }

    @Test func styleActionNamesFollowTheChangedFields() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)

        commands.updateStyle(of: element.id) { style in
            style.stroke = Stroke(color: .black, width: 1)
        }
        #expect(commands.undoActionName == "Stroke")

        commands.updateStyle(of: element.id) { style in
            var stroke = style.stroke ?? Stroke(color: .black, width: 1)
            stroke.width = 4
            style.stroke = stroke
        }
        #expect(commands.undoActionName == "Stroke Width")

        commands.updateStyle(of: element.id) { style in
            style.opacity = 0.5
        }
        #expect(commands.undoActionName == "Opacity")

        commands.updateStyle(of: element.id) { style in
            style.cornerRadius = 6
        }
        #expect(commands.undoActionName == "Corner Radius")

        commands.updateStyle(of: element.id) { style in
            style.fill = Paint(color: .white)
            style.opacity = 0.25
        }
        #expect(commands.undoActionName == "Style")

        commands.undo()
        #expect(session.document.element(element.id)?.opacity == 0.5)
        #expect(session.document.element(element.id)?.fill == Paint(color: .black))
    }

    @Test func everyElementTypeRoundTrips() {
        let image = ImageRef()
        let elements = [
            CanvasElement.rectangle(),
            CanvasElement.roundedRectangle(cornerRadius: 4),
            CanvasElement.circle(),
            CanvasElement.text("Hello"),
            CanvasElement.image(image),
            CanvasElement.line(from: CanvasPoint(x: 0, y: 0), to: CanvasPoint(x: 12, y: 3)),
            CanvasElement.group(childIDs: [UUID(), UUID()]),
        ]
        let session = EditingSession()
        for element in elements {
            session.commandManager.insert(element)
        }
        let filled = session.document.copy()

        for _ in elements {
            session.commandManager.undo()
        }
        #expect(session.document.orderedElements.isEmpty)
        #expect(!session.commandManager.canUndo)

        for _ in elements {
            session.commandManager.redo()
        }
        #expect(session.document == filled)
    }

    @Test func undoAndRedoAvailabilityAtEachStage() {
        let session = EditingSession()
        let commands = session.commandManager
        let element = CanvasElement.rectangle()

        #expect(!commands.canUndo)
        #expect(!commands.canRedo)
        #expect(commands.undoActionName == "")
        #expect(commands.redoActionName == "")

        commands.insert(element)
        #expect(commands.canUndo)
        #expect(!commands.canRedo)
        #expect(commands.undoActionName == "Insert")

        commands.undo()
        #expect(!commands.canUndo)
        #expect(commands.canRedo)
        #expect(commands.redoActionName == "Insert")

        commands.redo()
        #expect(commands.canUndo)
        #expect(!commands.canRedo)
        #expect(commands.undoActionName == "Insert")

        commands.move(element.id, to: CanvasPoint(x: 2, y: 3))
        #expect(commands.canUndo)
        #expect(!commands.canRedo)
        #expect(commands.undoActionName == "Move")

        commands.undo()
        #expect(commands.canUndo)
        #expect(commands.canRedo)
        #expect(commands.undoActionName == "Insert")
        #expect(commands.redoActionName == "Move")
    }

    @Test func newCommandClearsTheRedoStack() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(size: CanvasSize(width: 100, height: 100))
        let commands = session.commandManager
        commands.insert(element)
        commands.move(element.id, to: CanvasPoint(x: 9, y: 9))
        commands.undo()
        #expect(commands.canRedo)
        #expect(commands.redoActionName == "Move")

        commands.resize(element.id, to: CanvasSize(width: 10, height: 12))
        #expect(!commands.canRedo)
        #expect(commands.undoActionName == "Resize")

        commands.undo()
        #expect(session.document.element(element.id)?.size == CanvasSize(width: 100, height: 100))
        #expect(session.document.element(element.id)?.position == .zero)
        #expect(commands.undoActionName == "Insert")
        #expect(commands.canRedo)
        #expect(commands.redoActionName == "Resize")
    }

    @Test func rotateUndoRedoRestoresRotation() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(rotation: CanvasRotation(degrees: 5))
        let commands = session.commandManager
        commands.insert(element)
        let before = session.document.copy()

        commands.rotate(element.id, to: CanvasRotation(degrees: 45))
        #expect(commands.undoActionName == "Rotate")
        let rotated = session.document.copy()

        commands.undo()
        #expect(session.document == before)
        commands.redo()
        #expect(session.document == rotated)
        #expect(session.document.element(element.id)?.rotation == CanvasRotation(degrees: 45))
    }

    @Test func unchangedRotationIsNotAnUndoStep() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(rotation: CanvasRotation(degrees: 12))
        let commands = session.commandManager
        commands.insert(element)
        let revision = session.document.revision
        commands.rotate(element.id, to: CanvasRotation(degrees: 12))
        #expect(commands.undoActionName == "Insert")
        #expect(session.document.revision == revision)
    }

    @Test func unchangedMoveIsNotAnUndoStep() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(position: CanvasPoint(x: 3, y: 3))
        let commands = session.commandManager
        commands.insert(element)
        let revision = session.document.revision
        commands.move(element.id, to: CanvasPoint(x: 3, y: 3))
        #expect(commands.undoActionName == "Insert")
        #expect(session.document.revision == revision)
    }
}
