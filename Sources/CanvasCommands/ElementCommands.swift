import CanvasModel

public struct InsertElementCommand: CanvasCommand {
    public let element: CanvasElement
    /// Index in back-to-front order. The element is inserted so this index is where it lands.
    public let zIndex: Int
    public var actionName: String { "Insert" }

    public init(element: CanvasElement, zIndex: Int) {
        self.element = element
        self.zIndex = zIndex
    }

    public func apply(to document: CanvasDocument) {
        document.insert(element, at: zIndex)
    }

    public func inverse() -> any CanvasCommand {
        DeleteElementCommand(element: element, zIndex: zIndex)
    }
}

public struct DeleteElementCommand: CanvasCommand {
    public let element: CanvasElement
    /// Index the element occupied before it was removed. Undo inserts it there again.
    public let zIndex: Int
    public var actionName: String { "Delete" }

    public init(element: CanvasElement, zIndex: Int) {
        self.element = element
        self.zIndex = zIndex
    }

    public init?(elementID: CanvasElement.ID, in document: CanvasDocument) {
        guard let element = document.element(elementID), let zIndex = document.zIndex(of: elementID) else {
            return nil
        }
        self.init(element: element, zIndex: zIndex)
    }

    public func apply(to document: CanvasDocument) {
        document.remove(id: element.id)
    }

    public func inverse() -> any CanvasCommand {
        InsertElementCommand(element: element, zIndex: zIndex)
    }
}

public struct MoveElementCommand: CanvasCommand {
    public let elementID: CanvasElement.ID
    public let from: CanvasPoint
    public let to: CanvasPoint
    public var actionName: String { "Move" }

    public init(elementID: CanvasElement.ID, from: CanvasPoint, to: CanvasPoint) {
        self.elementID = elementID
        self.from = from
        self.to = to
    }

    public func apply(to document: CanvasDocument) {
        document.update(elementID) { element in
            element.position = to
        }
    }

    public func inverse() -> any CanvasCommand {
        MoveElementCommand(elementID: elementID, from: to, to: from)
    }
}

public struct ResizeElementCommand: CanvasCommand {
    public let elementID: CanvasElement.ID
    public let from: CanvasSize
    public let to: CanvasSize
    public var actionName: String { "Resize" }

    public init(elementID: CanvasElement.ID, from: CanvasSize, to: CanvasSize) {
        self.elementID = elementID
        self.from = from
        self.to = to
    }

    public func apply(to document: CanvasDocument) {
        document.update(elementID) { element in
            element.size = to
        }
    }

    public func inverse() -> any CanvasCommand {
        ResizeElementCommand(elementID: elementID, from: to, to: from)
    }
}

public struct UpdateStyleCommand: CanvasCommand {
    public let elementID: CanvasElement.ID
    public let from: ElementStyle
    public let to: ElementStyle
    public var actionName: String { StyleActionName.describe(from: from, to: to) }

    public init(elementID: CanvasElement.ID, from: ElementStyle, to: ElementStyle) {
        self.elementID = elementID
        self.from = from
        self.to = to
    }

    public func apply(to document: CanvasDocument) {
        document.update(elementID) { element in
            element.style = to
        }
    }

    public func inverse() -> any CanvasCommand {
        UpdateStyleCommand(elementID: elementID, from: to, to: from)
    }
}

enum StyleActionName {
    static func describe(from: ElementStyle, to: ElementStyle) -> String {
        var parts: [String] = []
        if from.fill != to.fill {
            parts.append("Fill")
        }
        if from.stroke != to.stroke {
            if from.stroke?.color == to.stroke?.color {
                parts.append("Stroke Width")
            } else {
                parts.append("Stroke")
            }
        }
        if from.opacity != to.opacity {
            parts.append("Opacity")
        }
        if from.cornerRadius != to.cornerRadius {
            parts.append("Corner Radius")
        }
        if parts.count == 1, let only = parts.first {
            return only
        }
        return "Style"
    }
}
