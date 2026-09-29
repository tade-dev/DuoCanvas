import CanvasCommands
import CanvasModel
import Testing

@MainActor
@Suite("Coalescing")
struct CoalescingTests {
    @Test func dragPreviewsBecomeOneMoveStep() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(position: CanvasPoint(x: 1, y: 2))
        let commands = session.commandManager
        commands.insert(element)
        let afterInsert = session.document.copy()
        let revisionAfterInsert = session.document.revision
        let points = [
            CanvasPoint(x: 10, y: 10),
            CanvasPoint(x: 20, y: 15),
            CanvasPoint(x: 30, y: 18),
            CanvasPoint(x: 40, y: 22),
            CanvasPoint(x: 48, y: 25),
        ]

        let edit = commands.beginCoalescedEdit(actionName: "Move")
        for point in points {
            edit.preview { document in
                document.update(element.id) { $0.position = point }
            }
            #expect(commands.undoActionName == "Insert")
            #expect(!commands.canRedo)
            #expect(session.document.revision == revisionAfterInsert)
        }
        #expect(session.document.element(element.id)?.position == points[points.count - 1])

        edit.end()
        #expect(commands.undoActionName == "Move")
        #expect(commands.canUndo)
        #expect(!commands.canRedo)
        #expect(session.document.revision == revisionAfterInsert + 1)

        commands.undo()
        #expect(session.document == afterInsert)
        #expect(commands.redoActionName == "Move")

        commands.redo()
        #expect(session.document.element(element.id)?.position == CanvasPoint(x: 48, y: 25))
        #expect(commands.undoActionName == "Move")

        commands.undo()
        commands.undo()
        #expect(!commands.canUndo)
        #expect(session.document.orderedElements.isEmpty)
    }

    @Test func sliderSessionCoalescesToOneStep() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let afterInsert = session.document.copy()

        let edit = commands.beginCoalescedEdit(actionName: "Opacity")
        for opacity in [0.9, 0.7, 0.4, 0.25] {
            edit.preview { document in
                document.update(element.id) { $0.opacity = opacity }
            }
            #expect(commands.undoActionName == "Insert")
            #expect(session.document.element(element.id)?.opacity == opacity)
        }
        edit.end()

        #expect(commands.undoActionName == "Opacity")
        #expect(session.document.element(element.id)?.opacity == 0.25)
        commands.undo()
        #expect(session.document == afterInsert)
        commands.undo()
        #expect(!commands.canUndo)
    }

    @Test func cancelledEditRestoresStartAndLeavesNoStep() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(position: CanvasPoint(x: 5, y: 6))
        let commands = session.commandManager
        commands.insert(element)
        commands.move(element.id, to: CanvasPoint(x: 8, y: 8))
        commands.undo()
        #expect(commands.canRedo)
        let before = session.document.copy()
        let revision = session.document.revision

        let edit = commands.beginCoalescedEdit(actionName: "Move")
        edit.preview { document in
            document.update(element.id) { $0.position = CanvasPoint(x: 100, y: 140) }
        }
        #expect(session.document.element(element.id)?.position == CanvasPoint(x: 100, y: 140))
        edit.cancel()

        #expect(session.document == before)
        #expect(session.document.revision == revision)
        #expect(commands.undoActionName == "Insert")
        #expect(commands.canRedo)
        #expect(commands.redoActionName == "Move")

        commands.redo()
        #expect(session.document.element(element.id)?.position == CanvasPoint(x: 8, y: 8))
    }

    @Test func endingAnUnchangedEditRecordsNothing() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(position: CanvasPoint(x: 1, y: 1))
        let commands = session.commandManager
        commands.insert(element)
        let revision = session.document.revision

        let edit = commands.beginCoalescedEdit(actionName: "Move")
        edit.preview { document in
            document.update(element.id) { $0.position = CanvasPoint(x: 30, y: 30) }
        }
        edit.preview { document in
            document.update(element.id) { $0.position = CanvasPoint(x: 1, y: 1) }
        }
        edit.end()

        #expect(commands.undoActionName == "Insert")
        #expect(session.document.revision == revision)
    }

    @Test func committedEditClearsRedo() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        commands.move(element.id, to: CanvasPoint(x: 4, y: 4))
        commands.undo()
        #expect(commands.canRedo)

        let edit = commands.beginCoalescedEdit(actionName: "Move")
        edit.preview { document in
            document.update(element.id) { $0.position = CanvasPoint(x: 7, y: 1) }
        }
        edit.end()
        #expect(!commands.canRedo)
        #expect(commands.undoActionName == "Move")
    }

    @Test func updatesInsideTheIdleWindowAreOneFillStep() {
        let clock = ManualClock()
        let session = EditingSession(idleInterval: 0.5, clock: clock)
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let afterInsert = session.document.copy()
        let revision = session.document.revision
        let red = Paint(color: CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))
        let green = Paint(color: CanvasColor(red: 0, green: 1, blue: 0, alpha: 1))
        let blue = Paint(color: CanvasColor(red: 0, green: 0, blue: 1, alpha: 1))

        func paint(_ fill: Paint, at time: Double) {
            clock.time = time
            commands.recordContinuousEdit(
                key: ContinuousEditKey(elementID: element.id, property: .fill)
            ) { document in
                document.update(element.id) { $0.fill = fill }
            }
        }

        paint(red, at: 0)
        paint(green, at: 0.25)
        paint(blue, at: 0.5)
        #expect(commands.undoActionName == "Insert")
        #expect(session.document.revision == revision)
        #expect(session.document.element(element.id)?.fill == blue)

        clock.time = 0.5
        commands.flushExpiredContinuousEdits()
        #expect(commands.undoActionName == "Insert")

        clock.time = 1
        commands.flushExpiredContinuousEdits()
        #expect(commands.undoActionName == "Fill")
        #expect(session.document.revision == revision + 1)

        commands.undo()
        #expect(session.document == afterInsert)
        #expect(commands.redoActionName == "Fill")
        commands.redo()
        #expect(session.document.element(element.id)?.fill == blue)

        commands.undo()
        commands.undo()
        #expect(!commands.canUndo)
    }

    @Test func idleBoundaryStartsASecondStep() {
        let clock = ManualClock()
        let session = EditingSession(idleInterval: 0.5, clock: clock)
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let red = Paint(color: CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))
        let blue = Paint(color: CanvasColor(red: 0, green: 0, blue: 1, alpha: 1))

        clock.time = 0
        commands.recordContinuousEdit(
            key: ContinuousEditKey(elementID: element.id, property: .fill)
        ) { document in
            document.update(element.id) { $0.fill = red }
        }
        clock.time = 0.5
        commands.recordContinuousEdit(
            key: ContinuousEditKey(elementID: element.id, property: .fill)
        ) { document in
            document.update(element.id) { $0.fill = blue }
        }

        #expect(commands.undoActionName == "Fill")
        #expect(session.document.element(element.id)?.fill == blue)
        commands.flushExpiredContinuousEdits()
        #expect(session.document.element(element.id)?.fill == blue)

        clock.time = 1
        commands.flushExpiredContinuousEdits()
        commands.undo()
        #expect(session.document.element(element.id)?.fill == red)
        commands.undo()
        #expect(session.document.element(element.id)?.fill == Paint(color: .black))
        #expect(commands.undoActionName == "Insert")
    }

    @Test func differentPropertiesDoNotCoalesce() {
        let clock = ManualClock()
        let session = EditingSession(idleInterval: 0.5, clock: clock)
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let red = Paint(color: CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))

        commands.recordContinuousEdit(
            key: ContinuousEditKey(elementID: element.id, property: .fill)
        ) { document in
            document.update(element.id) { $0.fill = red }
        }
        commands.recordContinuousEdit(
            key: ContinuousEditKey(elementID: element.id, property: .opacity)
        ) { document in
            document.update(element.id) { $0.opacity = 0.25 }
        }

        #expect(commands.undoActionName == "Fill")
        #expect(session.document.element(element.id)?.opacity == 0.25)
        commands.flushContinuousEdits()
        #expect(commands.undoActionName == "Opacity")

        commands.undo()
        #expect(session.document.element(element.id)?.opacity == 1)
        #expect(session.document.element(element.id)?.fill == red)
        commands.undo()
        #expect(session.document.element(element.id)?.fill == Paint(color: .black))
    }

    @Test func returningToTheStartInsideTheWindowRecordsNothing() {
        let clock = ManualClock()
        let session = EditingSession(idleInterval: 0.5, clock: clock)
        let element = CanvasElement.rectangle()
        let commands = session.commandManager
        commands.insert(element)
        let revision = session.document.revision
        let red = Paint(color: CanvasColor(red: 1, green: 0, blue: 0, alpha: 1))

        clock.time = 0
        commands.recordContinuousEdit(
            key: ContinuousEditKey(elementID: element.id, property: .fill)
        ) { document in
            document.update(element.id) { $0.fill = red }
        }
        clock.time = 0.25
        commands.recordContinuousEdit(
            key: ContinuousEditKey(elementID: element.id, property: .fill)
        ) { document in
            document.update(element.id) { $0.fill = Paint(color: .black) }
        }
        clock.time = 10
        commands.flushExpiredContinuousEdits()

        #expect(commands.undoActionName == "Insert")
        #expect(session.document.revision == revision)
        #expect(session.document.element(element.id)?.fill == Paint(color: .black))
    }
}
