import Foundation

/// A point in canvas space, in points. The origin and axis direction belong to the view layer.
public struct CanvasPoint: Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = CanvasPoint(x: 0, y: 0)
}

/// A size in canvas space, in points.
///
/// Width and height are not required to be positive. A line stores its end as an offset from
/// its start, so either component may be negative.
public struct CanvasSize: Equatable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = CanvasSize(width: 0, height: 0)

    /// Default artboard. This is not a device size.
    public static let defaultArtboard = CanvasSize(width: 1200, height: 800)
}

/// Rotation stored in degrees, clockwise. Values are not normalised.
public struct CanvasRotation: Equatable, Hashable, Sendable {
    public var degrees: Double

    public init(degrees: Double) {
        self.degrees = degrees
    }

    public static let zero = CanvasRotation(degrees: 0)
}
