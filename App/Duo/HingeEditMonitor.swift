import SwiftUI

/// Cancels an in-flight drag when the hinge status changes.
///
/// The hinge is not used to choose the layout. Opening and closing resize the scene,
/// and the split follows that size. This modifier only ends a gesture that a pose
/// change would otherwise leave open.
struct HingeEditMonitor: ViewModifier {
    var editor: EditorModel
    @State private var statusDescription: String?

    func body(content: Content) -> some View {
        content.onHingeChange { _, newContext in
            let next = newContext.hinge.map { String(describing: $0.status) }
            if let statusDescription, statusDescription != next {
                editor.cancelInFlightEdit()
            }
            statusDescription = next
        }
    }
}

extension View {
    func cancelInFlightEditsWhenHingeChanges(_ editor: EditorModel) -> some View {
        modifier(HingeEditMonitor(editor: editor))
    }
}
