import CanvasModel
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var stacksFields: Bool {
        AccessibilityChrome.resolve(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize).stacksFields
    }

    var body: some View {
        Group {
            if stacksFields {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .accessibilityHidden(true)
                    numberField
                    stepper
                }
            } else {
                LabeledContent {
                    HStack(spacing: 8) {
                        numberField
                        stepper
                    }
                } label: {
                    Text(title)
                }
            }
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

    private var numberField: some View {
        TextField(title, text: $draft)
            .focused($isFocused)
            .multilineTextAlignment(stacksFields ? .leading : .trailing)
            .keyboardType(.decimalPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(commitDraft)
            .accessibilityLabel(accessibilityLabel)
            .frame(minHeight: CGFloat(CanvasAccessibility.minimumHitTarget))
    }

    private var stepper: some View {
        Stepper(accessibilityLabel, onIncrement: { step(by: step) }, onDecrement: { step(by: -step) })
            .labelsHidden()
            .accessibilityLabel(accessibilityLabel)
            .frame(
                minWidth: CGFloat(CanvasAccessibility.minimumHitTarget),
                minHeight: CGFloat(CanvasAccessibility.minimumHitTarget)
            )
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
