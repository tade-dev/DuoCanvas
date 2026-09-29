import CanvasModel
import SwiftData
import SwiftUI

/// Opens one saved project in the existing editor and writes the document when a command commits.
struct ProjectEditorHost: View {
    let projectID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.undoManager) private var systemUndoManager

    @State private var editor: EditorModel?
    @State private var store: ProjectStore?
    @State private var failedToOpen = false
    @State private var saveError: String?

    var body: some View {
        Group {
            if let editor, let store {
                EditorView(
                    editor: editor,
                    navigationTitle: store.projectName,
                    onCommittedRevision: {
                        persist(editor: editor, store: store)
                    }
                )
            } else if failedToOpen {
                ContentUnavailableView(
                    "Couldn't Open Project",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This project is missing or its canvas could not be read.")
                )
            } else {
                ProgressView("Opening")
            }
        }
        .task(id: projectID) {
            openIfNeeded()
        }
        .task(id: undoAdoptionID) {
            editor?.adoptSystemUndoManager(systemUndoManager)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            settleAndPersist()
        }
        .onDisappear {
            settleAndPersist()
        }
        .alert(
            "Couldn't Save",
            isPresented: saveErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "The last edit is still on the canvas, but it was not written to the project.")
        }
    }

    private var undoAdoptionID: UndoAdoptionID {
        UndoAdoptionID(
            manager: systemUndoManager.map(ObjectIdentifier.init),
            editor: editor.map(ObjectIdentifier.init)
        )
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { isPresented in
                if !isPresented { saveError = nil }
            }
        )
    }

    private func openIfNeeded() {
        guard editor == nil, !failedToOpen else { return }
        do {
            let store = try ProjectStore(context: modelContext, projectID: projectID)
            let loaded = try store.load()
            let imageStore = CanvasImageStore()
            for (id, data) in loaded.imageDataByID {
                imageStore.store(data, for: id)
            }
            let editor = EditorModel(document: loaded.document, imageStore: imageStore)
            editor.adoptSystemUndoManager(systemUndoManager)
            self.store = store
            self.editor = editor
        } catch {
            failedToOpen = true
        }
    }

    private func settleAndPersist() {
        guard let editor, let store else { return }
        editor.commitOpenEdits()
        persist(editor: editor, store: store)
    }

    private func persist(editor: EditorModel, store: ProjectStore) {
        store.saveCommitted(document: editor.document, images: editor.imageStore)
        if let message = store.lastErrorMessage {
            saveError = message
        }
    }
}

private struct UndoAdoptionID: Equatable {
    var manager: ObjectIdentifier?
    var editor: ObjectIdentifier?
}
