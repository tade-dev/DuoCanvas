import Foundation

/// Which inspector controls apply to an element type.
///
/// The view hides everything this set marks false. Corner radius belongs to the rounded
/// rectangle only: the rectangle, circle, line, text, and image renderers do not use it.
/// Text colour lives in the typography section, not in fill.
public struct InspectorFieldSet: Equatable, Sendable {
    public var fill: Bool
    public var stroke: Bool
    public var cornerRadius: Bool
    public var opacity: Bool
    public var typography: Bool

    public init(
        fill: Bool,
        stroke: Bool,
        cornerRadius: Bool,
        opacity: Bool,
        typography: Bool
    ) {
        self.fill = fill
        self.stroke = stroke
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.typography = typography
    }

    public static func forType(_ type: CanvasElementType) -> InspectorFieldSet {
        switch type {
        case .rectangle:
            InspectorFieldSet(fill: true, stroke: true, cornerRadius: false, opacity: true, typography: false)
        case .roundedRectangle:
            InspectorFieldSet(fill: true, stroke: true, cornerRadius: true, opacity: true, typography: false)
        case .circle:
            InspectorFieldSet(fill: true, stroke: true, cornerRadius: false, opacity: true, typography: false)
        case .text:
            InspectorFieldSet(fill: false, stroke: false, cornerRadius: false, opacity: true, typography: true)
        case .image:
            InspectorFieldSet(fill: false, stroke: false, cornerRadius: false, opacity: true, typography: false)
        case .line:
            InspectorFieldSet(fill: false, stroke: true, cornerRadius: false, opacity: true, typography: false)
        case .group:
            InspectorFieldSet(fill: false, stroke: false, cornerRadius: false, opacity: true, typography: false)
        }
    }
}
