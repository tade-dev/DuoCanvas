import CanvasModel
import SwiftUI

extension CanvasColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension CanvasFontWeight {
    var swiftUIWeight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension CanvasTextAlignment {
    var swiftUIAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var frameAlignment: Alignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

extension CanvasElementType {
    var displayName: String {
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

enum CanvasFormatting {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func accessibilityDescription(for element: CanvasElement) -> String {
        var parts = [element.type.displayName]
        if element.type == .text, let string = element.text?.string, !string.isEmpty {
            parts.append(string)
        }
        parts.append(
            "\(number(abs(element.size.width))) by \(number(abs(element.size.height))) points"
        )
        parts.append("at \(number(element.position.x)), \(number(element.position.y))")
        return parts.joined(separator: ", ")
    }

    static func backgroundDescription(_ color: CanvasColor) -> String {
        if color == .white { return "White" }
        if color == .black { return "Black" }
        if color == .clear { return "Clear" }
        return "\(number(color.red)), \(number(color.green)), \(number(color.blue))"
    }
}
