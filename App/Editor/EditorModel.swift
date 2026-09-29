import CanvasCommands
import CanvasModel
import Foundation
import Observation

/// The in-memory editor for one project: the document, its command stack, and the selection.
@MainActor
@Observable
final class EditorModel {
    let session: EditingSession

    var primarySelection: CanvasElement.ID?
    /// Compact width presents the inspector as a sheet. Regular width ignores this flag.
    var inspectorPresented = false

    private var moveEdit: CoalescedEdit?
    private var moveOrigin: CanvasPoint?
    private var movingID: CanvasElement.ID?
    private var moveEndedNormally = false
    /// The system undo manager this session is recording into, once SwiftUI has provided one.
    private var adoptedUndoManager: UndoManager?

    init() {
        let undoManager = UndoManager()
        // Used until the view can see the system undo manager. `groupsByEvent` matches
        // UndoManager's default, so a run-loop turn is still one step.
        undoManager.groupsByEvent = true
        session = EditingSession(
            document: SampleCanvas.makeDocument(),
            undoRecording: SystemUndoRecording(undoManager: undoManager)
        )
    }

    /// Records later edits on `manager` when the stack is still empty.
    ///
    /// `EnvironmentValues.undoManager` is get-only, so the session uses the instance
    /// SwiftUI already publishes. Shake and the Edit menu then see the same registrations
    /// as the toolbar. A nil value leaves the session on its own manager.
    func adoptSystemUndoManager(_ manager: UndoManager?) {
        guard let manager else { return }
        if adoptedUndoManager === manager { return }
        guard !session.commandManager.canUndo, !session.commandManager.canRedo else { return }
        cancelInFlightEdit()
        guard session.commandManager.replaceUndoRecordingIfEmpty(
            with: SystemUndoRecording(undoManager: manager)
        ) else { return }
        adoptedUndoManager = manager
    }

    var document: CanvasDocument { session.document }

    var selectedElement: CanvasElement? {
        guard let primarySelection else { return nil }
        return document.element(primarySelection)
    }

    var activeMoveID: CanvasElement.ID? { movingID }

    var canUndo: Bool { session.commandManager.canUndo }
    var canRedo: Bool { session.commandManager.canRedo }
    var undoActionName: String { session.commandManager.undoActionName }
    var redoActionName: String { session.commandManager.redoActionName }

    func select(_ id: CanvasElement.ID?) {
        primarySelection = id
    }

    func undo() {
        cancelInFlightEdit()
        session.commandManager.undo()
    }

    func redo() {
        cancelInFlightEdit()
        session.commandManager.redo()
    }

    func setX(_ x: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        commitOpenMove()
        session.commandManager.move(id, to: CanvasPoint(x: x, y: element.position.y))
    }

    func setY(_ y: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        commitOpenMove()
        session.commandManager.move(id, to: CanvasPoint(x: element.position.x, y: y))
    }

    func setWidth(_ width: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        commitOpenMove()
        session.commandManager.resize(id, to: CanvasSize(width: width, height: element.size.height))
    }

    func setHeight(_ height: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        commitOpenMove()
        session.commandManager.resize(id, to: CanvasSize(width: element.size.width, height: height))
    }

    func setRotation(_ degrees: Double, for id: CanvasElement.ID) {
        commitOpenMove()
        session.commandManager.rotate(id, to: CanvasRotation(degrees: degrees))
    }

    /// Live drag. `translation` is in the artboard's view space; `scale` converts it to canvas points.
    func previewMove(of id: CanvasElement.ID, translationX: Double, translationY: Double, scale: Double) {
        guard scale > 0, document.element(id) != nil else { return }
        if moveEdit == nil {
            guard let current = document.element(id) else { return }
            primarySelection = id
            movingID = id
            moveOrigin = current.position
            moveEndedNormally = false
            moveEdit = session.commandManager.beginCoalescedEdit(actionName: "Move")
        }
        guard movingID == id, let origin = moveOrigin else { return }
        let position = CanvasPoint(
            x: origin.x + translationX / scale,
            y: origin.y + translationY / scale
        )
        moveEdit?.preview { document in
            document.update(id) { element in
                element.position = position
            }
        }
    }

    func endMove() {
        guard moveEdit != nil else { return }
        moveEndedNormally = true
        moveEdit?.end()
        clearMove()
    }

    /// Drops a drag that the gesture system cancelled, or that a pose change interrupted.
    func cancelInFlightEdit() {
        guard moveEdit != nil else { return }
        moveEdit?.cancel()
        clearMove()
    }

    /// Called after the gesture resets. A normal end has already cleared the edit.
    func cancelAbandonedMove() {
        guard moveEdit != nil, !moveEndedNormally else { return }
        cancelInFlightEdit()
    }

    private func commitOpenMove() {
        guard moveEdit != nil else { return }
        endMove()
    }

    private func clearMove() {
        moveEdit = nil
        moveOrigin = nil
        movingID = nil
    }
}
