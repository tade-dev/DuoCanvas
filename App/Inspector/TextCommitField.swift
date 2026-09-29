import SwiftUI

/// A labeled string that commits when editing ends.
struct TextCommitField: View {
    let title: String
    let accessibilityLabel: String
    let value: String
    let onCommit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $draft, axis: .vertical)
            .lineLimit(1...4)
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

    private func commitDraft() {
        guard draft != value else { return }
        onCommit(draft)
    }
}
