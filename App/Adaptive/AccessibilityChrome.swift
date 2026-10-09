import CanvasModel
import SwiftUI

/// Turns Reduce Motion into a transaction flag. There is no decorative animation to replace.
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transaction { transaction in
            if MotionPolicy.disablesAnimations(reduceMotion: reduceMotion) {
                transaction.disablesAnimations = true
            }
        }
    }
}

extension View {
    func honorReduceMotion() -> some View {
        modifier(ReduceMotionModifier())
    }

    /// Symbol toolbar items keep their spoken name in the large content viewer.
    func toolbarAccessibility() -> some View {
        accessibilityShowsLargeContentViewer()
    }
}
