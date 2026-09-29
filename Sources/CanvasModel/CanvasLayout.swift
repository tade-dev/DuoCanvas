import Foundation

/// A rectangle in canvas or view space. Width and height may be negative; intersection
/// uses the standardized box.
public struct CanvasRect: Equatable, Hashable, Sendable {
    public var origin: CanvasPoint
    public var size: CanvasSize

    public init(origin: CanvasPoint, size: CanvasSize) {
        self.origin = origin
        self.size = size
    }

    public static let zero = CanvasRect(origin: .zero, size: .zero)

    /// The same area with a non-negative size and an origin at the minimum corner.
    public var standardized: CanvasRect {
        let width = size.width
        let height = size.height
        let x = width < 0 ? origin.x + width : origin.x
        let y = height < 0 ? origin.y + height : origin.y
        return CanvasRect(
            origin: CanvasPoint(x: x, y: y),
            size: CanvasSize(width: abs(width), height: abs(height))
        )
    }

    /// True when the boxes overlap or share an edge.
    ///
    /// A control that only touches the boundary of a reserved area still counts as inside it.
    public func intersects(_ other: CanvasRect) -> Bool {
        let a = standardized
        let b = other.standardized
        let aMaxX = a.origin.x + a.size.width
        let aMaxY = a.origin.y + a.size.height
        let bMaxX = b.origin.x + b.size.width
        let bMaxY = b.origin.y + b.size.height
        return a.origin.x <= bMaxX
            && b.origin.x <= aMaxX
            && a.origin.y <= bMaxY
            && b.origin.y <= aMaxY
    }
}

/// Insets around a reserved area. The area's frame already includes these.
public struct CanvasEdgeInsets: Equatable, Hashable, Sendable {
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

    public static let zero = CanvasEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
}

/// A region the canvas must keep its own controls clear of.
///
/// This is a plain value. The app's Duo layer maps system regions into it. The canvas
/// does not know which device produced the region.
public struct CanvasReservedArea: Equatable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Equatable, Hashable, Sendable {
        /// A split in the usable area, such as a fold.
        case division
        /// Something covering the display, such as a camera.
        case occlusion
    }

    public var id: String
    public var frame: CanvasRect
    public var margins: CanvasEdgeInsets
    public var isActive: Bool
    public var kind: Kind

    public init(
        id: String,
        frame: CanvasRect,
        margins: CanvasEdgeInsets,
        isActive: Bool,
        kind: Kind
    ) {
        self.id = id
        self.frame = frame
        self.margins = margins
        self.isActive = isActive
        self.kind = kind
    }
}

/// Width size class, without a UI framework type.
public enum CanvasSizeClass: String, Equatable, Hashable, Sendable {
    case compact
    case regular
    /// The system has not reported a size class yet.
    case unspecified
}

/// What the canvas needs in order to lay out its own controls.
///
/// `bounds` and `reservedAreas` share one coordinate space: the canvas pane.
/// Element geometry stays in canvas space and is not rewritten from this value.
public struct CanvasLayoutContext: Equatable, Hashable, Sendable {
    public var bounds: CanvasRect
    public var horizontalSizeClass: CanvasSizeClass
    public var reservedAreas: [CanvasReservedArea]
    public var displayScale: Double

    public init(
        bounds: CanvasRect,
        horizontalSizeClass: CanvasSizeClass,
        reservedAreas: [CanvasReservedArea],
        displayScale: Double
    ) {
        self.bounds = bounds
        self.horizontalSizeClass = horizontalSizeClass
        self.reservedAreas = reservedAreas
        self.displayScale = displayScale
    }

    public static let empty = CanvasLayoutContext(
        bounds: .zero,
        horizontalSizeClass: .unspecified,
        reservedAreas: [],
        displayScale: 1
    )
}
