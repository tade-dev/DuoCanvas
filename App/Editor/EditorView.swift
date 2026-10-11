import AdaptiveLayout
import CanvasModel
import PhotosUI
import SwiftUI

struct EditorView: View {
    @Bindable var editor: EditorModel
    var navigationTitle: String
    /// Called after a command, undo, or redo changes the document. Previews do not call it.
    var onCommittedRevision: () -> Void = {}
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var photoItem: PhotosPickerItem?
    @State private var exportPage = CanvasPageExport(
        canvasSize: .zero,
        background: .white,
        elements: [],
        images: [:]
    )
    @State private var notice: EditorNotice?

    var body: some View {
        AdaptiveEditorLayout(editor: editor)
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    addMenu
                    arrangeMenu
                    exportControl
                    Button {
                        editor.undo()
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!editor.canUndo)
                    .accessibilityLabel(undoTitle)
                    .toolbarAccessibility()
                    Button {
                        editor.redo()
                    } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                    .disabled(!editor.canRedo)
                    .accessibilityLabel(redoTitle)
                    .toolbarAccessibility()
                }
                if showsInspectorToggle {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            editor.inspectorPresented.toggle()
                        } label: {
                            Label("Inspector", systemImage: "sidebar.trailing")
                        }
                        .accessibilityAddTraits(editor.inspectorPresented ? .isSelected : [])
                        .accessibilityHint(editor.inspectorPresented ? "Closes the inspector." : "Opens the inspector.")
                        .toolbarAccessibility()
                    }
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    await importPhoto(item)
                    photoItem = nil
                }
            }
            .onChange(of: editor.document.revision) { _, _ in
                onCommittedRevision()
                captureExportPage()
            }
            .onAppear {
                captureExportPage()
                CanvasExportReporting.report = { problem in
                    notice = EditorNotice(title: "Couldn't Export PNG", message: problem.message)
                }
            }
            .onDisappear {
                CanvasExportReporting.report = nil
            }
            .onChange(of: editor.imageProblem) { _, problem in
                guard let problem else { return }
                notice = EditorNotice(title: "Couldn't Add Image", message: problem.message)
                editor.imageProblem = nil
            }
            .alert(
                notice?.title ?? "Couldn't Complete That",
                isPresented: noticeIsPresented
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notice?.message ?? "")
            }
    }

    private var arrangeMenu: some View {
        Menu {
            Button {
                editor.duplicateSelection()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .disabled(!editor.canDuplicate)
            Button {
                editor.groupSelection()
            } label: {
                Label("Group", systemImage: "square.on.square")
            }
            .disabled(!editor.canGroup)
            Button {
                editor.ungroupSelection()
            } label: {
                Label("Ungroup", systemImage: "square.slash")
            }
            .disabled(!editor.canUngroup)
        } label: {
            Label("Arrange", systemImage: "square.on.square")
        }
        .toolbarAccessibility()
    }

    private var addMenu: some View {
        Menu {
            Button {
                editor.addRectangle()
            } label: {
                Label("Rectangle", systemImage: "rectangle")
            }
            Button {
                editor.addRoundedRectangle()
            } label: {
                Label("Rounded Rectangle", systemImage: "rectangle.roundedtop")
            }
            Button {
                editor.addCircle()
            } label: {
                Label("Circle", systemImage: "circle")
            }
            Button {
                editor.addText()
            } label: {
                Label("Text", systemImage: "textformat")
            }
            Button {
                editor.addLine()
            } label: {
                Label("Line", systemImage: "line.diagonal")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Image", systemImage: "photo")
            }
        } label: {
            Label("Add", systemImage: "plus")
        }
        .toolbarAccessibility()
    }

    private var exportControl: some View {
        let label = Label("Export PNG", systemImage: "square.and.arrow.up")
        return Group {
            if let problem = CanvasExportCheck.problem(
                width: exportPage.canvasSize.width,
                height: exportPage.canvasSize.height
            ) {
                Button {
                    notice = EditorNotice(title: "Couldn't Export PNG", message: problem.message)
                } label: {
                    label
                }
            } else {
                ShareLink(item: exportPage, preview: SharePreview(navigationTitle)) {
                    label
                }
            }
        }
        .toolbarAccessibility()
    }

    private var noticeIsPresented: Binding<Bool> {
        Binding(
            get: { notice != nil },
            set: { isPresented in
                if !isPresented { notice = nil }
            }
        )
    }

    /// Copies the document after a commit. A live drag does not change `revision`, so the
    /// shared PNG stays on the last committed page.
    private func captureExportPage() {
        exportPage = CanvasPageExport(
            canvasSize: editor.document.canvasConfig.size,
            background: editor.document.canvasConfig.background,
            elements: editor.document.orderedElements,
            images: editor.imageStore.dataByID
        )
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let imported = try await item.loadTransferable(type: ImportedCanvasImage.self) else {
                notice = EditorNotice(title: "Couldn't Add Image", message: CanvasImageProblem.empty.message)
                return
            }
            switch CanvasImagePreparation.prepare(imported.data) {
            case .success(let prepared):
                editor.insertImage(
                    data: prepared.data,
                    pixelWidth: prepared.pixelWidth,
                    pixelHeight: prepared.pixelHeight,
                    displayImage: prepared.image
                )
            case .failure(let problem):
                notice = EditorNotice(title: "Couldn't Add Image", message: problem.message)
            }
        } catch {
            notice = EditorNotice(title: "Couldn't Add Image", message: CanvasImageProblem.undecodable.message)
            CanvasInstrumentation.log.error("Image import failed: \(error.localizedDescription, privacy: .public)")
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

private struct EditorNotice: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

#Preview("Sample editor") {
    NavigationStack {
        EditorView(
            editor: EditorModel(document: SampleCanvas.makeDocument()),
            navigationTitle: "Sample"
        )
    }
}
