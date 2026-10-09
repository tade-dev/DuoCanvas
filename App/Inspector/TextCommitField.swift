import CanvasModel
import SwiftUI

/// A labeled string that commits when editing ends.
struct TextCommitField: View {
    let title: String
    let accessibilityLabel: String
    let value: String
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TextField(title, text: $draft, axis: .vertical)
            .lineLimit(lineLimit)
            .focused($isFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(commitDraft)
            .accessibilityLabel(accessibilityLabel)
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in
                guard !isFocused else { return }
                draft = newValue
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    draft = value
                } else {
                    commitDraft()
                }
            }
    }

    private var lineLimit: ClosedRange<Int> {
        let chrome = AccessibilityChrome.resolve(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        return chrome.stacksFields ? 1...8 : 1...4
    }

    private func commitDraft() {
        guard draft != value else { return }
        onCommit(draft)
    }
}
