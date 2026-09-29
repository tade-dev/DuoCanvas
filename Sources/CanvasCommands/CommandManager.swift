import CanvasModel
import Foundation

/// Identifies a continuous control that has no end callback, such as a colour picker.
public struct ContinuousEditKey: Equatable, Hashable, Sendable {
    public var elementID: CanvasElement.ID
    public var property: Property

    public init(elementID: CanvasElement.ID, property: Property) {
        self.elementID = elementID
        self.property = property
    }

    public enum Property: Equatable, Hashable, Sendable {
        case fill
        case stroke
        case strokeWidth
        case opacity
        case cornerRadius
        case textColor

        public var defaultActionName: String {
            switch self {
            case .fill: "Fill"
            case .stroke: "Stroke"
            case .strokeWidth: "Stroke Width"
            case .opacity: "Opacity"
            case .cornerRadius: "Corner Radius"
            case .textColor: "Text Color"
            }
        }
    }
}

/// Supplies `now` for the idle coalescing window. Tests pass a clock they can move.
@MainActor
public protocol CoalescingClock: AnyObject {
    func now() -> TimeInterval
}

@MainActor
public final class SystemCoalescingClock: CoalescingClock {
    public init() {}

    public func now() -> TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }
}

@MainActor
public final class ManualClock: CoalescingClock {
    public var time: TimeInterval

    public init(time: TimeInterval = 0) {
        self.time = time
    }

    public func now() -> TimeInterval {
        time
    }
}

/// Elements a duplicate or paste inserted, and the map from each source id to its copy.
public struct ElementReplication: Equatable, Sendable {
    public var insertedIDs: [CanvasElement.ID]
    public var idMap: [CanvasElement.ID: CanvasElement.ID]

    public init(insertedIDs: [CanvasElement.ID], idMap: [CanvasElement.ID: CanvasElement.ID]) {
        self.insertedIDs = insertedIDs
        self.idMap = idMap
    }

    public static let none = ElementReplication(insertedIDs: [], idMap: [:])
}

/// Applies commands and owns the single undo stack for one editing session.
@MainActor
public final class CommandManager {
    /// Idle gap after which a continuous edit becomes one undo step. Colour pickers use this.
    public static let defaultIdleInterval: TimeInterval = 0.5

    public let document: CanvasDocument
    public let idleInterval: TimeInterval

    private let clock: any CoalescingClock
    private var undoRecording: any UndoRecording
    private var coalescedEdit: CoalescedEdit?
    private var pendingContinuous: PendingContinuousEdit?

    public init(
        document: CanvasDocument,
        idleInterval: TimeInterval = CommandManager.defaultIdleInterval,
        clock: any CoalescingClock = SystemCoalescingClock(),
        undoRecording: (any UndoRecording)? = nil
    ) {
        self.document = document
        self.idleInterval = idleInterval
        self.clock = clock
        self.undoRecording = undoRecording ?? SessionUndoManager()
    }

    /// Points later registrations at `recording` when nothing has been recorded yet.
    ///
    /// Returns false if an edit is open or a step is already on the stack, so one session
    /// does not split its history across two managers.
    @discardableResult
    public func replaceUndoRecordingIfEmpty(with recording: any UndoRecording) -> Bool {
        guard coalescedEdit == nil, pendingContinuous == nil, !canUndo, !canRedo else {
            return false
        }
        undoRecording = recording
        return true
    }

    public var canUndo: Bool { undoRecording.canUndo }
    public var canRedo: Bool { undoRecording.canRedo }
    public var undoActionName: String { undoRecording.undoActionName }
    public var redoActionName: String { undoRecording.redoActionName }

    public func undo() {
        precondition(coalescedEdit == nil, "End or cancel the open edit before undo.")
        commitPendingContinuousEdit()
        undoRecording.undo()
    }

    public func redo() {
        precondition(coalescedEdit == nil, "End or cancel the open edit before redo.")
        commitPendingContinuousEdit()
        undoRecording.redo()
    }

    public func perform(_ command: any CanvasCommand) {
        prepareForCommand()
        performNew(command)
    }

    public func insert(_ element: CanvasElement, at zIndex: Int? = nil) {
        prepareForCommand()
        let index = zIndex ?? document.order.count
        performNew(InsertElementCommand(element: element, zIndex: index))
    }

    public func delete(_ elementID: CanvasElement.ID) {
        delete([elementID])
    }

    /// Removes the roots of `ids` and their descendants as one Delete step.
    ///
    /// A child taken out of a group is removed from that group's `childIDs`. An unknown id
    /// records nothing.
    public func delete(_ ids: [CanvasElement.ID]) {
        commitChange(actionName: "Delete") { document in
            CanvasEditing.remove(ids, from: document)
        }
    }

    /// Inserts copies of `ids` and their descendants in front of the current elements.
    ///
    /// One Duplicate step. Copies keep the source `ImageRef` so the existing bytes still draw.
    /// An empty selection records nothing.
    @discardableResult
    public func duplicate(
        _ ids: [CanvasElement.ID],
        offset: CanvasPoint = CanvasDuplication.offset,
        makeID: @escaping () -> UUID = { UUID() }
    ) -> ElementReplication {
        let copies = CanvasDuplication.copies(
            of: ids,
            order: document.order,
            elements: document.elements,
            offset: offset,
            makeID: makeID
        )
        guard !copies.elements.isEmpty else { return .none }
        let recorded = commitChange(actionName: "Duplicate") { document in
            for element in copies.elements {
                document.insert(element, at: nil)
            }
        }
        guard recorded else { return .none }
        return ElementReplication(insertedIDs: copies.elements.map(\.id), idMap: copies.idMap)
    }

    /// Inserts retargeted clipboard elements in front. Image bytes stay the caller's job.
    ///
    /// One Paste step. `ImageRef` ids are unchanged. An empty clipboard records nothing.
    @discardableResult
    public func paste(
        _ clipboard: CanvasClipboard,
        offset: CanvasPoint = CanvasDuplication.offset,
        makeID: @escaping () -> UUID = { UUID() }
    ) -> ElementReplication {
        let copies = CanvasDuplication.retarget(clipboard.elements, offset: offset, makeID: makeID)
        guard !copies.elements.isEmpty else { return .none }
        let recorded = commitChange(actionName: "Paste") { document in
            for element in copies.elements {
                document.insert(element, at: nil)
            }
        }
        guard recorded else { return .none }
        return ElementReplication(insertedIDs: copies.elements.map(\.id), idMap: copies.idMap)
    }

    /// Wraps the roots of `ids` in one new group. Fewer than two members records nothing.
    @discardableResult
    public func group(
        _ ids: [CanvasElement.ID],
        groupID: CanvasElement.ID = UUID()
    ) -> CanvasElement.ID? {
        var created: CanvasElement.ID?
        let recorded = commitChange(actionName: "Group") { document in
            created = CanvasEditing.group(ids, in: document, groupID: groupID)
        }
        return recorded ? created : nil
    }

    /// Dissolves groups in `ids` as one Ungroup step. The result is the released children, back to front.
    @discardableResult
    public func ungroup(_ ids: [CanvasElement.ID]) -> [CanvasElement.ID] {
        var released: [CanvasElement.ID] = []
        let recorded = commitChange(actionName: "Ungroup") { document in
            released = CanvasEditing.ungroup(ids, in: document)
        }
        return recorded ? released : []
    }

    /// Moves the roots of `ids` and their descendants by `delta` as one Move step.
    public func translate(_ ids: [CanvasElement.ID], by delta: CanvasPoint) {
        commitChange(actionName: "Move") { document in
            CanvasEditing.translate(ids, by: delta, in: document)
        }
    }

    public func move(_ elementID: CanvasElement.ID, to position: CanvasPoint) {
        guard let current = document.element(elementID) else { return }
        let delta = CanvasPoint(
            x: position.x - current.position.x,
            y: position.y - current.position.y
        )
        if CanvasStructure.descendants(of: elementID, in: document.elements).isEmpty {
            prepareForCommand()
            performNew(MoveElementCommand(elementID: elementID, from: current.position, to: position))
        } else {
            translate([elementID], by: delta)
        }
    }

    public func resize(_ elementID: CanvasElement.ID, to size: CanvasSize) {
        prepareForCommand()
        guard let current = document.element(elementID) else { return }
        performNew(ResizeElementCommand(elementID: elementID, from: current.size, to: size))
    }

    public func rotate(_ elementID: CanvasElement.ID, to rotation: CanvasRotation) {
        prepareForCommand()
        guard let current = document.element(elementID) else { return }
        performNew(RotateElementCommand(elementID: elementID, from: current.rotation, to: rotation))
    }

    public func updateStyle(of elementID: CanvasElement.ID, _ mutate: (inout ElementStyle) -> Void) {
        prepareForCommand()
        guard let current = document.element(elementID) else { return }
        var style = current.style
        let original = style
        mutate(&style)
        performNew(UpdateStyleCommand(elementID: elementID, from: original, to: style))
    }

    public func updateText(of elementID: CanvasElement.ID, _ mutate: (inout TextAttributes) -> Void) {
        prepareForCommand()
        guard let current = document.element(elementID)?.text else { return }
        var text = current
        mutate(&text)
        performNew(UpdateTextCommand(elementID: elementID, from: current, to: text))
    }

    /// Opens a drag or slider edit. Preview updates are live and are not undo entries.
    public func beginCoalescedEdit(actionName: String) -> CoalescedEdit {
        precondition(coalescedEdit == nil, "An edit is already open.")
        commitPendingContinuousEdit()
        let edit = CoalescedEdit(manager: self, actionName: actionName, start: document.snapshot())
        coalescedEdit = edit
        return edit
    }

    /// Applies `change` immediately. Matching keys inside the idle window share one undo step.
    ///
    /// The step is recorded when the window expires, when a different key arrives, or when
    /// `flushExpiredContinuousEdits()`, `flushContinuousEdits()`, `perform`, `undo`, or `redo` runs.
    /// A sequence that returns to its start value records nothing.
    public func recordContinuousEdit(
        key: ContinuousEditKey,
        actionName: String? = nil,
        _ change: (CanvasDocument) -> Void
    ) {
        precondition(coalescedEdit == nil, "End or cancel the open edit before a continuous edit.")
        let now = clock.now()
        flushIfIdle(at: now)
        if var pending = pendingContinuous, pending.key == key {
            document.withoutRecordingRevision {
                change(document)
            }
            pending.lastEvent = now
            if document.snapshot() == pending.start {
                pendingContinuous = nil
            } else {
                pendingContinuous = pending
            }
            return
        }

        commitPendingContinuousEdit()
        let start = document.snapshot()
        document.withoutRecordingRevision {
            change(document)
        }
        guard document.snapshot() != start else { return }
        pendingContinuous = PendingContinuousEdit(
            key: key,
            actionName: actionName ?? key.property.defaultActionName,
            start: start,
            lastEvent: now
        )
    }

    /// Records the open continuous edit when the idle window has elapsed.
    public func flushExpiredContinuousEdits() {
        flushIfIdle(at: clock.now())
    }

    /// Records the open continuous edit now, even if the window has not elapsed.
    public func flushContinuousEdits() {
        commitPendingContinuousEdit()
    }

    func finishCoalescedEdit(
        _ edit: CoalescedEdit,
        start: CanvasDocumentSnapshot,
        actionName: String
    ) {
        if coalescedEdit === edit {
            coalescedEdit = nil
        }
        let end = document.snapshot()
        guard end != start else { return }
        document.withoutRecordingRevision {
            document.restoreContent(from: start)
        }
        performNew(
            DocumentStateCommand(actionName: actionName, previous: start, resulting: end)
        )
    }

    func discardCoalescedEdit(_ edit: CoalescedEdit, restoring start: CanvasDocumentSnapshot) {
        if coalescedEdit === edit {
            coalescedEdit = nil
        }
        document.withoutRecordingRevision {
            document.restoreContent(from: start)
        }
    }

    /// Applies `body` as one undo step named `actionName`. Returns false when the document is unchanged.
    @discardableResult
    private func commitChange(
        actionName: String,
        _ body: (CanvasDocument) -> Void
    ) -> Bool {
        prepareForCommand()
        let start = document.snapshot()
        document.withoutRecordingRevision {
            body(document)
        }
        let end = document.snapshot()
        guard end != start else { return false }
        document.withoutRecordingRevision {
            document.restoreContent(from: start)
        }
        performNew(DocumentStateCommand(actionName: actionName, previous: start, resulting: end))
        return true
    }

    private func prepareForCommand() {
        precondition(coalescedEdit == nil, "End or cancel the open edit before performing a command.")
        commitPendingContinuousEdit()
    }

    private func performNew(_ command: any CanvasCommand) {
        let before = document.snapshot()
        command.apply(to: document)
        guard document.snapshot() != before else { return }
        let inverse = command.inverse()
        let actionName = command.actionName
        undoRecording.registerUndo(withTarget: self) { manager in
            manager.applyRegistered(inverse, actionName: actionName)
        }
        undoRecording.setActionName(actionName)
    }

    private func applyRegistered(_ command: any CanvasCommand, actionName: String) {
        let before = document.snapshot()
        let redo = command.inverse()
        command.apply(to: document)
        precondition(
            document.snapshot() != before,
            "A registered command did not change the document."
        )
        undoRecording.registerUndo(withTarget: self) { manager in
            manager.applyRegistered(redo, actionName: actionName)
        }
        undoRecording.setActionName(actionName)
    }

    private func flushIfIdle(at now: TimeInterval) {
        guard let pending = pendingContinuous, now - pending.lastEvent >= idleInterval else { return }
        commitPendingContinuousEdit()
    }

    private func commitPendingContinuousEdit() {
        guard let pending = pendingContinuous else { return }
        pendingContinuous = nil
        let end = document.snapshot()
        guard end != pending.start else { return }
        document.withoutRecordingRevision {
            document.restoreContent(from: pending.start)
        }
        performNew(
            DocumentStateCommand(
                actionName: pending.actionName,
                previous: pending.start,
                resulting: end
            )
        )
    }
}

private struct PendingContinuousEdit {
    var key: ContinuousEditKey
    var actionName: String
    var start: CanvasDocumentSnapshot
    var lastEvent: TimeInterval
}
