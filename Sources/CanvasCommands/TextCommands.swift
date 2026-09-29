import CanvasModel

public struct UpdateTextCommand: CanvasCommand {
    public let elementID: CanvasElement.ID
    public let from: TextAttributes
    public let to: TextAttributes
    public var actionName: String { TextActionName.describe(from: from, to: to) }

    public init(elementID: CanvasElement.ID, from: TextAttributes, to: TextAttributes) {
        self.elementID = elementID
        self.from = from
        self.to = to
    }

    public func apply(to document: CanvasDocument) {
        document.update(elementID) { element in
            element.text = to
        }
    }

    public func inverse() -> any CanvasCommand {
        UpdateTextCommand(elementID: elementID, from: to, to: from)
    }
}

enum TextActionName {
    static func describe(from: TextAttributes, to: TextAttributes) -> String {
        var parts: [String] = []
        if from.string != to.string {
            parts.append("Text")
        }
        if from.fontName != to.fontName {
            parts.append("Font")
        }
        if from.fontSize != to.fontSize {
            parts.append("Size")
        }
        if from.fontWeight != to.fontWeight {
            parts.append("Weight")
        }
        if from.alignment != to.alignment {
            parts.append("Alignment")
        }
        if from.color != to.color {
            parts.append("Text Color")
        }
        if parts.count == 1, let only = parts.first {
            return only
        }
        return "Text"
    }
}
