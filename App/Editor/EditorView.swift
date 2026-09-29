import AdaptiveLayout
import CanvasModel
import SwiftUI

struct EditorRoot: View {
    @Environment(\.undoManager) private var systemUndoManager
    @State private var editor = EditorModel()

    var body: some View {
        NavigationStack {
            EditorView(editor: editor)
        }
        .task(id: systemUndoManager.map(ObjectIdentifier.init)) {
            editor.adoptSystemUndoManager(systemUndoManager)
        }
    }
}

struct EditorView: View {
    @Bindable var editor: EditorModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        AdaptiveEditorLayout(editor: editor)
            .navigationTitle("Untitled")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        editor.undo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!editor.canUndo)
                    .accessibilityLabel(undoTitle)
                    Button {
                        editor.redo()
                    } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!editor.canRedo)
                    .accessibilityLabel(redoTitle)
                }
                if showsInspectorToggle {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            editor.inspectorPresented.toggle()
                        } label: {
                            Label("Inspector", systemImage: "sidebar.trailing")
                        }
                        .accessibilityAddTraits(editor.inspectorPresented ? .isSelected : [])
                    }
                }
            }
    }

    private var showsInspectorToggle: Bool {
        EditorArrangement.forHorizontalSizeClass(CanvasSizeClass(horizontalSizeClass)) == .sheet
    }

    /// Reads the document revision so the buttons refresh. The command stack itself is not observable.
    private var undoTitle: String {
        _ = editor.document.revision
        guard editor.canUndo, !editor.undoActionName.isEmpty else { return "Undo" }
        return "Undo \(editor.undoActionName)"
    }

    private var redoTitle: String {
        guard editor.canRedo, !editor.redoActionName.isEmpty else { return "Redo" }
        return "Redo \(editor.redoActionName)"
    }
}
