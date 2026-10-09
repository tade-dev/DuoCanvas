import Foundation

extension CanvasElementType {
    public var displayName: String {
        switch self {
        case .rectangle: "Rectangle"
        case .roundedRectangle: "Rounded rectangle"
        case .circle: "Circle"
        case .text: "Text"
        case .image: "Image"
        case .line: "Line"
        case .group: "Group"
        }
    }
}

public enum CanvasFormatting {
    public static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    public static func backgroundDescription(_ color: CanvasColor) -> String {
        if color == .white { return "White" }
        if color == .black { return "Black" }
        if color == .clear { return "Clear" }
        return "\(number(color.red)), \(number(color.green)), \(number(color.blue))"
    }
}
