import AdaptiveLayout
import CanvasModel
import PhotosUI
import SwiftUI
import UIKit

struct EditorView: View {
    @Bindable var editor: EditorModel
    var navigationTitle: String
    /// Called after a command, undo, or redo changes the document. Previews do not call it.
    var onCommittedRevision: () -> Void = {}
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var photoItem: PhotosPickerItem?
    @State private var exportPNG: Data?

    var body: some View {
        AdaptiveEditorLayout(editor: editor)
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    addMenu
                    arrangeMenu
                    if let exportPNG {
                        ShareLink(
                            item: CanvasPNG(data: exportPNG),
                            preview: SharePreview(navigationTitle)
                        ) {
                            Label("Export PNG", systemImage: "square.and.arrow.up")
                        }
                    }
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
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    await importPhoto(item)
                    photoItem = nil
                }
            }
            .onChange(of: editor.document.revision) { _, _ in
                onCommittedRevision()
            }
            .task(id: editor.document.revision) {
                exportPNG = CanvasPNGRenderer.pngData(
                    canvasSize: editor.document.canvasConfig.size,
                    background: editor.document.canvasConfig.background,
                    elements: editor.document.orderedElements,
                    images: editor.imageStore.dataByID
                )
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
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let imported = try await item.loadTransferable(type: ImportedCanvasImage.self) else { return }
            let pixelSize = UIImage(data: imported.data)?.size
            editor.insertImage(
                data: imported.data,
                pixelWidth: Double(pixelSize?.width ?? 0),
                pixelHeight: Double(pixelSize?.height ?? 0)
            )
        } catch {
            return
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

#Preview("Sample editor") {
    NavigationStack {
        EditorView(
            editor: EditorModel(document: SampleCanvas.makeDocument()),
            navigationTitle: "Sample"
        )
    }
}
