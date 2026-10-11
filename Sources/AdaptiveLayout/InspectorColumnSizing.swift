import CanvasModel
import Foundation

/// Width of the inspector column in a side-by-side split.
///
/// The value is chrome. It is not an undo step and it is not part of the document.
/// Views persist it themselves. This type only clamps and places the divider.
public struct InspectorColumnDrag: Equatable, Sendable {
    /// Width the split should use. Always inside the clamp.
    public var layoutWidth: Double
    /// How far the pill draws past the clamp, in points. Positive means the finger
    /// asked for a wider inspector than the clamp allows.
    public var pillOvershoot: Double
    public var needsSnap: Bool

    public init(layoutWidth: Double, pillOvershoot: Double, needsSnap: Bool) {
        self.layoutWidth = layoutWidth
        self.pillOvershoot = pillOvershoot
        self.needsSnap = needsSnap
    }
}

public enum InspectorColumnSizing {
    public static let minimumWidth: Double = 280
    public static let idealWidth: Double = 320
    public static let maximumWidth: Double = 480
    /// The canvas keeps at least this much when the container is wide enough.
    public static let minimumCanvasWidth: Double = 240
    public static let voiceOverStep: Double = 20
    /// The pill may travel this far past the clamp, then it snaps back.
    public static let rubberBand: Double = 28

    /// Lower and upper inspector widths for `containerWidth`. Neither pane is zero.
    public static func limits(containerWidth: Double) -> (lower: Double, upper: Double) {
        guard containerWidth.isFinite, containerWidth > 1 else {
            return (minimumWidth, maximumWidth)
        }
        if containerWidth >= minimumWidth + minimumCanvasWidth {
            let upper = min(maximumWidth, containerWidth - minimumCanvasWidth)
            return (minimumWidth, max(minimumWidth, upper))
        }
        let share = containerWidth * minimumWidth / (minimumWidth + minimumCanvasWidth)
        let width = min(max(share, 1), containerWidth - 1)
        return (width, width)
    }

    public static func clamped(_ width: Double, containerWidth: Double) -> Double {
        let limits = limits(containerWidth: containerWidth)
        guard width.isFinite else { return limits.lower }
        return min(max(width, limits.lower), limits.upper)
    }

    /// `translationTowardTrailing` is the finger's movement in container space.
    /// Positive moves toward the trailing edge. A trailing inspector grows when the
    /// finger moves the other way.
    public static func drag(
        startWidth: Double,
        translationTowardTrailing: Double,
        containerWidth: Double,
        inspectorIsTrailing: Bool
    ) -> InspectorColumnDrag {
        let delta = inspectorIsTrailing ? -translationTowardTrailing : translationTowardTrailing
        let proposed = startWidth + (delta.isFinite ? delta : 0)
        let layout = clamped(proposed, containerWidth: containerWidth)
        let raw = proposed - layout
        return InspectorColumnDrag(
            layoutWidth: layout,
            pillOvershoot: rubberBanded(raw),
            needsSnap: raw != 0
        )
    }

    public static func adjusted(_ width: Double, by step: Double, containerWidth: Double) -> Double {
        clamped(width + step, containerWidth: containerWidth)
    }

    /// Shift applied to the pill's x. Positive moves it toward the trailing edge.
    public static func pillShift(overshoot: Double, inspectorIsTrailing: Bool) -> Double {
        inspectorIsTrailing ? -overshoot : overshoot
    }

    private static func rubberBanded(_ overshoot: Double) -> Double {
        let sign: Double = overshoot < 0 ? -1 : 1
        let magnitude = min(abs(overshoot), rubberBand)
        return sign * magnitude
    }
}

/// Whether the side-by-side divider is on screen.
public enum SplitPaneAxis: Equatable, Sendable {
    /// The two panes sit next to each other.
    case horizontal
    /// The canvas is stacked above the inspector.
    case vertical
}

public enum InspectorDividerVisibility {
    public static func shows(axis: SplitPaneAxis?, blockedByDivision: Bool) -> Bool {
        axis == .horizontal && !blockedByDivision
    }
}

public struct InspectorDividerMetrics: Equatable, Sendable {
    public var pillWidth: Double
    public var pillHeight: Double
    public var hitWidth: Double
    public var usesHighContrast: Bool

    public init(pillWidth: Double, pillHeight: Double, hitWidth: Double, usesHighContrast: Bool) {
        self.pillWidth = pillWidth
        self.pillHeight = pillHeight
        self.hitWidth = hitWidth
        self.usesHighContrast = usesHighContrast
    }

    public static let hitWidth: Double = 44
    /// Mail-style capsule. Increase Contrast keeps this height and draws it wider.
    public static let pillHeight: Double = 40

    public static func resolve(increasedContrast: Bool) -> InspectorDividerMetrics {
        InspectorDividerMetrics(
            pillWidth: increasedContrast ? 6 : 4,
            pillHeight: pillHeight,
            hitWidth: hitWidth,
            usesHighContrast: increasedContrast
        )
    }
}

/// The dark margin around the two panes. The gap is the divider; there is no hairline.
public struct SplitPaneInsets: Equatable, Sendable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }
}

public enum SplitPaneChrome {
    /// Space between the cards, and the same margin at the window edges.
    public static let gutter: Double = 10
    /// Continuous corner of the split. Each card is concentric, so its radius is this minus `gutter`.
    public static let containerCornerRadius: Double = 46

    /// Primary keeps the outer edges and half the shared gutter. Secondary takes the other half.
    ///
    /// A nil axis uses the side-by-side insets. The grabber stays hidden until the axis is horizontal.
    public static func insets(axis: SplitPaneAxis?, isPrimary: Bool) -> SplitPaneInsets {
        let outer = gutter
        let inner = gutter / 2
        switch axis {
        case .vertical:
            if isPrimary {
                return SplitPaneInsets(top: outer, leading: outer, bottom: inner, trailing: outer)
            }
            return SplitPaneInsets(top: inner, leading: outer, bottom: outer, trailing: outer)
        case .horizontal, nil:
            if isPrimary {
                return SplitPaneInsets(top: outer, leading: outer, bottom: outer, trailing: inner)
            }
            return SplitPaneInsets(top: outer, leading: inner, bottom: outer, trailing: outer)
        }
    }
}

public enum InspectorDividerClearance {
    /// True when the divider strip would sit on an active division, such as a fold.
    ///
    /// `splitX` and `reservedAreas` share one coordinate space. Inactive divisions,
    /// including a flat fold, do not hide the divider.
    public static func blockedByActiveDivision(
        splitX: Double,
        containerHeight: Double,
        reservedAreas: [CanvasReservedArea]
    ) -> Bool {
        guard splitX.isFinite, containerHeight > 0 else { return false }
        let frame = CanvasRect(
            origin: CanvasPoint(x: splitX - InspectorDividerMetrics.hitWidth / 2, y: 0),
            size: CanvasSize(width: InspectorDividerMetrics.hitWidth, height: containerHeight)
        )
        return reservedAreas.contains { area in
            area.isActive && area.kind == .division && area.frame.intersects(frame)
        }
    }
}
