import CanvasModel
import PersistenceMapping
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
    @State private var openMessage = CanvasFailureCopy.projectOpenGeneric
    @State private var saveError: String?
    @State private var imageWarning: String?

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
                ContentUnavailableView {
                    Label("Couldn't Open Project", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(openMessage)
                }
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
            Text(saveError ?? CanvasFailureCopy.projectSave)
        }
        .alert(
            "Image Unavailable",
            isPresented: imageWarningIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageWarning ?? "")
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

    private var imageWarningIsPresented: Binding<Bool> {
        Binding(
            get: { imageWarning != nil },
            set: { isPresented in
                if !isPresented { imageWarning = nil }
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
            editor.warmDisplayImages()
            editor.adoptSystemUndoManager(systemUndoManager)
            let missing = CanvasImageAudit.missingIDs(in: loaded.document.orderedElements) { id in
                loaded.imageDataByID[id] != nil
            }
            let notDrawn = missing.count + editor.displayImages.undecodableIDs.count
            if notDrawn > 0 {
                imageWarning = CanvasImageAudit.notDrawnMessage(count: notDrawn)
            }
            self.store = store
            self.editor = editor
        } catch {
            openMessage = ProjectOpenMessage.text(for: error)
            failedToOpen = true
            CanvasInstrumentation.log.error("Project open failed: \(error.localizedDescription, privacy: .public)")
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

enum ProjectOpenMessage {
    static func text(for error: Error) -> String {
        if let mapping = error as? CanvasRecordMappingError {
            return mapping.openingMessage
        }
        if error is ProjectStoreError {
            return CanvasFailureCopy.projectMissing
        }
        return CanvasFailureCopy.projectOpenGeneric
    }
}
