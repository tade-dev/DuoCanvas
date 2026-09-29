import Foundation

/// What a canvas press is allowed to do, once the gesture has enough information.
public enum CanvasPointerIntent: Equatable, Sendable {
    /// Still inside the hold and inside the drag threshold.
    case pending
    /// Hold finished on the element body. Later movement moves; it does not resize.
    case move
    /// A handle outside the body has moved past the drag threshold.
    case resize(SelectionHandle)
    /// The rotate handle, outside the body, has moved past the drag threshold.
    case rotate
    /// The finger moved before a body hold finished, or it missed both the body and the handles.
    case ignore
}

/// Chooses move, resize, or select-or-wait for one canvas press.
///
/// The element body never resizes. A hold of `holdToMove` on the body arms a move,
/// including when a handle box overlaps that body. A handle only wins once the finger
/// is outside the body, and it then resizes or rotates without waiting for the hold.
/// Crossing `dragSlop` before the hold finishes stays `ignore`, so a quick drag does
/// not become a move on a later event. The view locks the first non-pending result.
public enum CanvasPointerRouting {
    /// How long a press on the body must last before a drag moves the element.
    public static let holdToMove: TimeInterval = 0.25
    /// Movement, in the gesture's points, that counts as a drag rather than a tap.
    public static let dragSlop: Double = 10

    public static func intent(
        elapsed: TimeInterval,
        distance: Double,
        onBody: Bool,
        handleOutsideBody: SelectionHandle?
    ) -> CanvasPointerIntent {
        if onBody {
            if elapsed >= holdToMove {
                return .move
            }
            if distance >= dragSlop {
                return .ignore
            }
            return .pending
        }
        if let handle = handleOutsideBody, distance >= dragSlop {
            if handle == .rotate {
                return .rotate
            }
            return .resize(handle)
        }
        if distance >= dragSlop {
            return .ignore
        }
        return .pending
    }
}
