import CanvasModel
import SwiftUI

/// Fill, stroke, corner radius, and opacity. Hidden fields are decided by `InspectorFieldSet`.
struct AppearanceInspector: View {
    var editor: EditorModel
    var element: CanvasElement
    var fields: InspectorFieldSet

    var body: some View {
        if fields.fill {
            fillControl
        }
        if fields.stroke {
            strokeControl
        }
        if fields.cornerRadius {
            radiusControl
        }
        if fields.opacity {
            opacityControl
        }
    }

    @ViewBuilder
    private var fillControl: some View {
        if element.fill == nil {
            Button("Add Fill") {
                editor.addFill(for: element.id)
            }
        } else {
            ColorPicker("Fill", selection: fillColor, supportsOpacity: false)
        }
    }

    @ViewBuilder
    private var strokeControl: some View {
        if element.type != .line, element.stroke == nil {
            Button("Add Stroke") {
                editor.addStroke(for: element.id)
            }
        } else {
            ColorPicker("Stroke", selection: strokeColor, supportsOpacity: false)
            NumericCommitField(
                title: "Stroke width",
                accessibilityLabel: "Stroke width",
                value: element.stroke?.width ?? 1
            ) { editor.setStrokeWidth($0, for: element.id) }
            Slider(
                value: strokeWidth,
                in: 0...40,
                onEditingChanged: { editing in
                    if editing {
                        editor.beginStyleSlider(for: element.id, actionName: "Stroke Width")
                    } else {
                        editor.endStyleAdjustment()
                    }
                }
            )
            .accessibilityLabel("Stroke width")
            if element.type != .line {
                Button("Remove Stroke") {
                    editor.removeStroke(for: element.id)
                }
            }
        }
    }

    private var radiusControl: some View {
        let limit = max(abs(element.size.width), abs(element.size.height), 1)
        return Group {
            NumericCommitField(
                title: "Corner radius",
                accessibilityLabel: "Corner radius",
                value: element.cornerRadius
            ) { editor.setCornerRadius($0, for: element.id) }
            Slider(
                value: cornerRadius,
                in: 0...limit,
                onEditingChanged: { editing in
                    if editing {
                        editor.beginStyleSlider(for: element.id, actionName: "Corner Radius")
                    } else {
                        editor.endStyleAdjustment()
                    }
                }
            )
            .accessibilityLabel("Corner radius")
        }
    }

    private var opacityControl: some View {
        Group {
            NumericCommitField(
                title: "Opacity",
                accessibilityLabel: "Opacity",
                value: element.opacity,
                step: 0.1
            ) { editor.setOpacity($0, for: element.id) }
            Slider(
                value: opacity,
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        editor.beginStyleSlider(for: element.id, actionName: "Opacity")
                    } else {
                        editor.endStyleAdjustment()
                    }
                }
            )
            .accessibilityLabel("Opacity")
        }
    }

    private var fillColor: Binding<Color> {
        Binding(
            get: { (element.fill?.color ?? .black).swiftUIColor },
            set: { editor.setFillColor(CanvasColor($0), for: element.id) }
        )
    }

    private var strokeColor: Binding<Color> {
        Binding(
            get: { (element.stroke?.color ?? .black).swiftUIColor },
            set: { editor.setStrokeColor(CanvasColor($0), for: element.id) }
        )
    }

    private var opacity: Binding<Double> {
        Binding(
            get: { element.opacity },
            set: { editor.previewOpacity($0, for: element.id) }
        )
    }

    private var strokeWidth: Binding<Double> {
        Binding(
            get: { element.stroke?.width ?? 1 },
            set: { editor.previewStrokeWidth($0, for: element.id) }
        )
    }

    private var cornerRadius: Binding<Double> {
        Binding(
            get: { element.cornerRadius },
            set: { editor.previewCornerRadius($0, for: element.id) }
        )
    }
}
