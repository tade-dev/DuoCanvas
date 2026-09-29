import CanvasModel
import SwiftUI

/// Font, size, weight, alignment, and colour. Shown only for text elements.
struct TypographyInspector: View {
    var editor: EditorModel
    var element: CanvasElement

    @State private var isPresentingFontPicker = false

    var body: some View {
        let text = element.text ?? TextAttributes(string: "")
        TextCommitField(
            title: "Text",
            accessibilityLabel: "Text",
            value: text.string
        ) { editor.setTextString($0, for: element.id) }
        Button {
            isPresentingFontPicker = true
        } label: {
            LabeledContent("Font", value: text.fontName)
        }
        .accessibilityLabel("Font, \(text.fontName)")
        NumericCommitField(
            title: "Size",
            accessibilityLabel: "Font size",
            value: text.fontSize
        ) { editor.setFontSize($0, for: element.id) }
        Picker("Weight", selection: weight) {
            ForEach(CanvasFontWeight.allCases, id: \.self) { weight in
                Text(weight.title).tag(weight)
            }
        }
        .pickerStyle(.menu)
        Picker("Alignment", selection: alignment) {
            Text("Leading").tag(CanvasTextAlignment.leading)
            Text("Center").tag(CanvasTextAlignment.center)
            Text("Trailing").tag(CanvasTextAlignment.trailing)
        }
        .pickerStyle(.segmented)
        ColorPicker("Color", selection: color, supportsOpacity: false)
        .sheet(isPresented: $isPresentingFontPicker) {
            FontFamilyPicker { family in
                editor.setFontName(family, for: element.id)
                isPresentingFontPicker = false
            } onCancel: {
                isPresentingFontPicker = false
            }
        }
    }

    private var weight: Binding<CanvasFontWeight> {
        Binding(
            get: { element.text?.fontWeight ?? .regular },
            set: { editor.setFontWeight($0, for: element.id) }
        )
    }

    private var alignment: Binding<CanvasTextAlignment> {
        Binding(
            get: { element.text?.alignment ?? .leading },
            set: { editor.setTextAlignment($0, for: element.id) }
        )
    }

    private var color: Binding<Color> {
        Binding(
            get: { (element.text?.color ?? .black).swiftUIColor },
            set: { editor.setTextColor(CanvasColor($0), for: element.id) }
        )
    }
}
