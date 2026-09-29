import Foundation

public enum CanvasElementType: String, Equatable, Hashable, Sendable, CaseIterable {
    case rectangle
    case roundedRectangle
    case circle
    case text
    case image
    case line
    case group
}

public enum CanvasFontWeight: String, Equatable, Hashable, Sendable, CaseIterable {
    case ultraLight
    case thin
    case light
    case regular
    case medium
    case semibold
    case bold
    case heavy
    case black
}

/// Horizontal alignment. Leading and trailing follow the layout direction used when the text is drawn.
public enum CanvasTextAlignment: String, Equatable, Hashable, Sendable {
    case leading
    case center
    case trailing
}

public struct TextAttributes: Equatable, Hashable, Sendable {
    public var string: String
    public var fontName: String
    public var fontSize: Double
    public var fontWeight: CanvasFontWeight
    public var alignment: CanvasTextAlignment
    public var color: CanvasColor

    public init(
        string: String,
        fontName: String = "Helvetica Neue",
        fontSize: Double = 17,
        fontWeight: CanvasFontWeight = .regular,
        alignment: CanvasTextAlignment = .leading,
        color: CanvasColor = .black
    ) {
        self.string = string
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.alignment = alignment
        self.color = color
    }
}

/// Identity of an image asset. Bytes live outside the document.
public struct ImageRef: Equatable, Hashable, Sendable {
    public var id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

/// The appearance fields an `UpdateStyleCommand` replaces as a group.
public struct ElementStyle: Equatable, Hashable, Sendable {
    public var opacity: Double
    public var fill: Paint?
    public var stroke: Stroke?
    public var cornerRadius: Double

    public init(
        opacity: Double,
        fill: Paint?,
        stroke: Stroke?,
        cornerRadius: Double
    ) {
        self.opacity = opacity
        self.fill = fill
        self.stroke = stroke
        self.cornerRadius = cornerRadius
    }
}

public struct CanvasElement: Equatable, Hashable, Sendable, Identifiable {
    public typealias ID = UUID

    public var id: ID
    public var type: CanvasElementType
    public var position: CanvasPoint
    public var size: CanvasSize
    public var rotation: CanvasRotation
    /// Expected range is 0...1. The model does not clamp.
    public var opacity: Double
    public var fill: Paint?
    public var stroke: Stroke?
    public var cornerRadius: Double
    public var text: TextAttributes?
    public var image: ImageRef?
    public var parentID: ID?
    /// Caller-managed until a grouping command exists. Removing an element does not edit this list.
    public var childIDs: [ID]

    public init(
        id: ID = UUID(),
        type: CanvasElementType,
        position: CanvasPoint = .zero,
        size: CanvasSize = .zero,
        rotation: CanvasRotation = .zero,
        opacity: Double = 1,
        fill: Paint? = nil,
        stroke: Stroke? = nil,
        cornerRadius: Double = 0,
        text: TextAttributes? = nil,
        image: ImageRef? = nil,
        parentID: ID? = nil,
        childIDs: [ID] = []
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.size = size
        self.rotation = rotation
        self.opacity = opacity
        self.fill = fill
        self.stroke = stroke
        self.cornerRadius = cornerRadius
        self.text = text
        self.image = image
        self.parentID = parentID
        self.childIDs = childIDs
    }

    public var style: ElementStyle {
        get {
            ElementStyle(
                opacity: opacity,
                fill: fill,
                stroke: stroke,
                cornerRadius: cornerRadius
            )
        }
        set {
            opacity = newValue.opacity
            fill = newValue.fill
            stroke = newValue.stroke
            cornerRadius = newValue.cornerRadius
        }
    }

    public static func rectangle(
        id: ID = UUID(),
        position: CanvasPoint = .zero,
        size: CanvasSize = CanvasSize(width: 100, height: 100),
        rotation: CanvasRotation = .zero,
        fill: Paint? = Paint(color: .black)
    ) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .rectangle,
            position: position,
            size: size,
            rotation: rotation,
            fill: fill
        )
    }

    public static func roundedRectangle(
        id: ID = UUID(),
        position: CanvasPoint = .zero,
        size: CanvasSize = CanvasSize(width: 100, height: 100),
        cornerRadius: Double = 12,
        fill: Paint? = Paint(color: .black)
    ) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .roundedRectangle,
            position: position,
            size: size,
            fill: fill,
            cornerRadius: cornerRadius
        )
    }

    public static func circle(
        id: ID = UUID(),
        position: CanvasPoint = .zero,
        size: CanvasSize = CanvasSize(width: 100, height: 100),
        fill: Paint? = Paint(color: .black)
    ) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .circle,
            position: position,
            size: size,
            fill: fill
        )
    }

    public static func text(
        _ string: String,
        id: ID = UUID(),
        position: CanvasPoint = .zero,
        size: CanvasSize = CanvasSize(width: 200, height: 40)
    ) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .text,
            position: position,
            size: size,
            text: TextAttributes(string: string)
        )
    }

    public static func image(
        _ image: ImageRef,
        id: ID = UUID(),
        position: CanvasPoint = .zero,
        size: CanvasSize = CanvasSize(width: 120, height: 120)
    ) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .image,
            position: position,
            size: size,
            image: image
        )
    }

    /// A line from `start` to `end`. `size` is the end expressed as an offset from `position`.
    public static func line(from start: CanvasPoint, to end: CanvasPoint, id: ID = UUID()) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .line,
            position: start,
            size: CanvasSize(width: end.x - start.x, height: end.y - start.y),
            stroke: Stroke(color: .black, width: 1)
        )
    }

    public static func group(
        id: ID = UUID(),
        childIDs: [ID] = [],
        position: CanvasPoint = .zero,
        size: CanvasSize = .zero
    ) -> CanvasElement {
        CanvasElement(
            id: id,
            type: .group,
            position: position,
            size: size,
            opacity: 1,
            childIDs: childIDs
        )
    }
}
