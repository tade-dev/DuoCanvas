import CanvasModel
import SwiftUI

/// Adds a named VoiceOver action only when there is one to perform.
struct OptionalAccessibilityAction: ViewModifier {
    var name: String
    var perform: (() -> Void)?

    func body(content: Content) -> some View {
        if let perform {
            content.accessibilityAction(named: name, perform)
        } else {
            content
        }
    }
}

struct AccessibilityActionList: ViewModifier {
    var actions: [CanvasAccessibilityAction]
    var perform: (CanvasAccessibilityAction) -> Void

    func body(content: Content) -> some View {
        actions.reduce(AnyView(content)) { view, action in
            AnyView(
                view.accessibilityAction(named: action.title) {
                    perform(action)
                }
            )
        }
    }
}

/// The Text rotor is omitted when the page has no text, so the rotor menu stays short.
struct TextElementsRotor: ViewModifier {
    var entries: [CanvasRotorEntry]
    var namespace: Namespace.ID

    func body(content: Content) -> some View {
        if entries.isEmpty {
            content
        } else {
            content.accessibilityRotor("Text") {
                ForEach(entries) { entry in
                    AccessibilityRotorEntry(entry.label, entry.id, in: namespace)
                }
            }
        }
    }
}
