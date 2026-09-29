import Foundation

/// One undo stack for one editing session.
///
/// `Foundation.UndoManager` is not in the Swift 6.4 Linux Foundation, so this type is the
/// equivalent used everywhere the core is tested. Registration follows
/// `UndoManager.registerUndo(withTarget:handler:)`: the handler receives the target, a call
/// made while undoing is recorded as redo, a call made while redoing is recorded as undo,
/// and a new registration at rest clears the redo stack. Each registration is one step.
/// Run-loop grouping is not used.
@MainActor
final class SessionUndoManager {
    private struct Entry {
        unowned let target: CommandManager
        var actionName: String
        let handler: (CommandManager) -> Void
    }

    private var undoStack: [Entry] = []
    private var redoStack: [Entry] = []
    private var phase: Phase = .idle
    private var pendingActionName: String?

    private enum Phase {
        case idle
        case undoing
        case redoing
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var undoCount: Int { undoStack.count }
    var redoCount: Int { redoStack.count }
    var undoActionName: String { undoStack.last?.actionName ?? "" }
    var redoActionName: String { redoStack.last?.actionName ?? "" }
    var isUndoing: Bool { phase == .undoing }
    var isRedoing: Bool { phase == .redoing }

    func registerUndo(
        withTarget target: CommandManager,
        handler: @escaping (CommandManager) -> Void
    ) {
        let name = pendingActionName ?? ""
        pendingActionName = nil
        let entry = Entry(target: target, actionName: name, handler: handler)
        switch phase {
        case .undoing:
            redoStack.append(entry)
        case .redoing:
            undoStack.append(entry)
        case .idle:
            redoStack.removeAll()
            undoStack.append(entry)
        }
    }

    /// Names the registration just recorded, or the next one if nothing is recorded yet.
    func setActionName(_ actionName: String) {
        switch phase {
        case .undoing:
            assign(actionName, on: &redoStack)
        case .redoing, .idle:
            assign(actionName, on: &undoStack)
        }
    }

    func undo() {
        guard phase == .idle, let entry = undoStack.popLast() else { return }
        phase = .undoing
        defer { phase = .idle }
        entry.handler(entry.target)
    }

    func redo() {
        guard phase == .idle, let entry = redoStack.popLast() else { return }
        phase = .redoing
        defer { phase = .idle }
        entry.handler(entry.target)
    }

    private func assign(_ actionName: String, on stack: inout [Entry]) {
        if stack.isEmpty {
            pendingActionName = actionName
        } else {
            stack[stack.count - 1].actionName = actionName
        }
    }
}

extension SessionUndoManager: UndoRecording {}
