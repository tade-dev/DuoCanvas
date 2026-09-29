import SwiftUI

/// A labeled number that commits through `onCommit` when editing ends or the stepper moves.
///
/// Keystrokes stay in the field. The decimal pad has no Return key, so the inspector also
/// offers a keyboard Done button that resigns first responder and lands here as a focus loss.
struct NumericCommitField: View {
    let title: String
    let accessibilityLabel: String
    let value: Double
    var step: Double = 1
    let onCommit: (Double) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(title, text: $draft)
                    .focused($isFocused)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(commitDraft)
                    .accessibilityLabel(accessibilityLabel)
                Stepper(accessibilityLabel, onIncrement: { step(by: step) }, onDecrement: { step(by: -step) })
                    .labelsHidden()
                    .accessibilityLabel(accessibilityLabel)
            }
        } label: {
            Text(title)
        }
        .onAppear { draft = Self.format(value) }
        .onChange(of: value) { _, newValue in
            guard !isFocused else { return }
            draft = Self.format(newValue)
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                draft = Self.format(value)
            } else {
                commitDraft()
            }
        }
    }

    private func step(by delta: Double) {
        let base = parsedDraft ?? value
        draft = Self.format(base + delta)
        isFocused = false
        onCommit(base + delta)
    }

    private func commitDraft() {
        guard let parsed = parsedDraft else {
            draft = Self.format(value)
            return
        }
        if parsed != value {
            onCommit(parsed)
        }
    }

    private var parsedDraft: Double? {
        try? Double(draft, format: .number)
    }

    private static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
