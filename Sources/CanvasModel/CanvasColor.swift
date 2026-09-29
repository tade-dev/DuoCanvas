import Foundation

/// Straight (non-premultiplied) RGBA in the range 0...1.
///
/// The canvas core does not import SwiftUI. Mapping to a resolved system colour happens in the app.
public struct CanvasColor: Equatable, Hashable, Sendable, Codable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let clear = CanvasColor(red: 0, green: 0, blue: 0, alpha: 0)
    public static let black = CanvasColor(red: 0, green: 0, blue: 0, alpha: 1)
    public static let white = CanvasColor(red: 1, green: 1, blue: 1, alpha: 1)
}

/// A solid fill. Further paint kinds can be added without changing element identity.
public struct Paint: Equatable, Hashable, Sendable, Codable {
    public var color: CanvasColor

    public init(color: CanvasColor) {
        self.color = color
    }
}

/// Stroke colour and width, in points.
public struct Stroke: Equatable, Hashable, Sendable, Codable {
    public var color: CanvasColor
    public var width: Double

    public init(color: CanvasColor, width: Double) {
        self.color = color
        self.width = width
    }
}
