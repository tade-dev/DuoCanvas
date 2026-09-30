import CanvasModel
import SwiftUI

/// Single-line editing drawn in the text element's frame.
///
/// Return, Done, and blur commit. Escape cancels. The first finish wins, so Escape
/// does not also commit when the field resigns focus.
struct CanvasInlineTextField: View {
    var element: CanvasElement
    var scale: Double
    var lineWidth: CGFloat
    @Binding var draft: String
    var onFinish: (Bool) -> Void

    @FocusState private var focused: Bool
    @State private var ending = false

    var body: some View {
        let text = element.text
        TextField("Text", text: $draft, prompt: Text("Text"))
            .focused($focused)
            .textFieldStyle(.plain)
            .submitLabel(.done)
            .font(
                .custom(text?.fontName ?? "Helvetica Neue", size: (text?.fontSize ?? 17) * scale)
                    .weight(text?.fontWeight.swiftUIWeight ?? .regular)
            )
            .foregroundStyle((text?.color ?? .black).swiftUIColor)
            .multilineTextAlignment(text?.alignment.swiftUIAlignment ?? .leading)
            .lineLimit(1)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .frame(
                width: max(abs(element.size.width) * scale, 1),
                height: max(abs(element.size.height) * scale, 1),
                alignment: text?.alignment.frameAlignment ?? .leading
            )
            .opacity(element.opacity)
            .overlay {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: lineWidth)
                    .allowsHitTesting(false)
            }
            .rotationEffect(.degrees(element.rotation.degrees))
            .onSubmit { finish(commit: true) }
            .onKeyPress(.escape) {
                finish(commit: false)
                return .handled
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused {
                    finish(commit: true)
                }
            }
            .onAppear { focused = true }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        finish(commit: true)
                    }
                }
            }
    }

    private func finish(commit: Bool) {
        guard !ending else { return }
        ending = true
        onFinish(commit)
    }
}
