import CanvasModel
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// In-app element payload. Imported, not exported: copy and paste stay inside DuoCanvas.
    static let canvasElements = UTType(
        importedAs: "dev.tade.duocanvas.elements",
        conformingTo: .json
    )
}

/// Transferable wrapper around `CanvasClipboard`. The command stack still performs the paste.
struct CanvasElementsTransfer: Codable, Transferable, Sendable {
    var clipboard: CanvasClipboard

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .canvasElements)
    }
}

struct CanvasEditActions {
    var canDuplicate: Bool
    var duplicate: () -> Void
}

private struct CanvasEditActionsKey: FocusedValueKey {
    typealias Value = CanvasEditActions
}

extension FocusedValues {
    var canvasEditActions: CanvasEditActions? {
        get { self[CanvasEditActionsKey.self] }
        set { self[CanvasEditActionsKey.self] = newValue }
    }
}

struct CanvasEditCommands: Commands {
    @FocusedValue(\.canvasEditActions) private var actions

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Button("Duplicate") {
                actions?.duplicate()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(actions?.canDuplicate != true)
        }
    }
}

/// Copy and paste for the focused canvas. Text fields keep the system pasteboard commands.
struct CanvasClipboardModifier: ViewModifier {
    var clipboard: CanvasClipboard?
    var onPaste: (CanvasClipboard) -> Void

    func body(content: Content) -> some View {
        let destination = content.pasteDestination(for: CanvasElementsTransfer.self) { items in
            guard let clipboard = items.first?.clipboard else { return }
            onPaste(clipboard)
        }
        if let clipboard {
            destination.copyable(CanvasElementsTransfer(clipboard: clipboard))
        } else {
            destination
        }
    }
}
