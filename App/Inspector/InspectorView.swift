import CanvasModel
import SwiftUI
import UIKit

struct InspectorView: View {
    var editor: EditorModel

    var body: some View {
        Form {
            if let element = editor.selectedElement {
                let fields = InspectorFieldSet.forType(element.type)
                Group {
                    Section {
                        NumericCommitField(
                            title: "X",
                            accessibilityLabel: "X position",
                            value: element.position.x
                        ) { editor.setX($0, for: element.id) }
                        NumericCommitField(
                            title: "Y",
                            accessibilityLabel: "Y position",
                            value: element.position.y
                        ) { editor.setY($0, for: element.id) }
                        NumericCommitField(
                            title: "W",
                            accessibilityLabel: "Width",
                            value: element.size.width
                        ) { editor.setWidth($0, for: element.id) }
                        NumericCommitField(
                            title: "H",
                            accessibilityLabel: "Height",
                            value: element.size.height
                        ) { editor.setHeight($0, for: element.id) }
                        NumericCommitField(
                            title: "Rotation",
                            accessibilityLabel: "Rotation",
                            value: element.rotation.degrees
                        ) { editor.setRotation($0, for: element.id) }
                    } header: {
                        Text(element.type.displayName)
                    } footer: {
                        if editor.additionalSelectionCount == 1 {
                            Text("Rotation is in degrees, clockwise. This is the primary selection. 1 more element is selected.")
                        } else if editor.additionalSelectionCount > 1 {
                            Text("Rotation is in degrees, clockwise. This is the primary selection. \(editor.additionalSelectionCount) more elements are selected.")
                        } else {
                            Text("Rotation is in degrees, clockwise.")
                        }
                    }
                    Section("Appearance") {
                        AppearanceInspector(editor: editor, element: element, fields: fields)
                    }
                    if fields.typography {
                        Section("Typography") {
                            TypographyInspector(editor: editor, element: element)
                        }
                    }
                }
                .id(element.id)
            } else {
                Section {
                    LabeledContent("Width", value: CanvasFormatting.number(editor.document.canvasConfig.size.width))
                    LabeledContent("Height", value: CanvasFormatting.number(editor.document.canvasConfig.size.height))
                    LabeledContent("Background") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(editor.document.canvasConfig.background.swiftUIColor)
                                .frame(width: 12, height: 12)
                                .accessibilityHidden(true)
                            Text(CanvasFormatting.backgroundDescription(editor.document.canvasConfig.background))
                        }
                    }
                } header: {
                    Text("Document")
                } footer: {
                    Text("Select an element to edit it.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismissKeyboard() }
            }
        }
    }

    /// The decimal pad has no Return key. Resigning first responder commits the focused field.
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
