import AdaptiveLayout
import CanvasModel
import SwiftUI

/// Regular width shows the system split. Compact width keeps the canvas and presents the inspector as a sheet.
struct AdaptiveEditorLayout: View {
    @Bindable var editor: EditorModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if arrangement == .split {
                DuoSplit {
                    canvas
                } secondary: {
                    InspectorView(editor: editor)
                }
            } else {
                canvas
                    .sheet(isPresented: $editor.inspectorPresented) {
                        NavigationStack {
                            InspectorView(editor: editor)
                                .navigationTitle("Inspector")
                                .toolbarTitleDisplayMode(.inline)
                                .toolbar {
                                    ToolbarItem(placement: .confirmationAction) {
                                        Button("Done") {
                                            editor.inspectorPresented = false
                                        }
                                    }
                                }
                        }
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    }
            }
        }
        .cancelInFlightEditsWhenHingeChanges(editor)
        .onChange(of: horizontalSizeClass) { _, newValue in
            editor.cancelInFlightEdit()
            if CanvasSizeClass(newValue) == .regular {
                editor.inspectorPresented = false
            }
        }
    }

    private var arrangement: EditorArrangement {
        EditorArrangement.forHorizontalSizeClass(CanvasSizeClass(horizontalSizeClass))
    }

    private var canvas: some View {
        CanvasLayoutReader { context in
            CanvasView(editor: editor, layoutContext: context)
        }
    }
}
