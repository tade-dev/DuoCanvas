import CanvasModel
import CoreGraphics
import SwiftUI
import UIKit

/// How an element participates in the selection. Handles stay on the primary only.
enum ElementSelectionRole: Equatable {
    case none
    case member
    case primary
}

struct CanvasElementView: View {
    var element: CanvasElement
    var scale: Double
    var imageData: Data?
    var role: ElementSelectionRole
    var selectionLineWidth: CGFloat
    var onSelect: () -> Void
    var onDuplicate: (() -> Void)?
    var onToggleSelection: (() -> Void)?
    var onGroup: (() -> Void)?
    var onUngroup: (() -> Void)?
    /// Hides the rendered string while the canvas text field draws it.
    var suppressesString: Bool = false
    var onEditText: (() -> Void)? = nil

    var body: some View {
        content
            .opacity(element.opacity)
            .frame(width: frameSize.width, height: frameSize.height)
            .overlay {
                if role != .none, !suppressesString {
                    Rectangle()
                        .strokeBorder(
                            Color.accentColor,
                            style: StrokeStyle(
                                lineWidth: selectionLineWidth,
                                dash: role == .primary ? [] : [6, 4]
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
            .rotationEffect(.degrees(element.rotation.degrees))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CanvasFormatting.accessibilityDescription(for: element))
            .accessibilityValue(role == .primary ? "Primary" : "")
            .accessibilityAddTraits(role == .none ? AccessibilityTraits() : .isSelected)
            .accessibilityAction(.default, onSelect)
            .modifier(NamedAccessibilityAction(name: "Duplicate", perform: onDuplicate))
            .modifier(NamedAccessibilityAction(
                name: role == .none ? "Add to Selection" : "Remove from Selection",
                perform: onToggleSelection
            ))
            .modifier(NamedAccessibilityAction(name: "Group", perform: onGroup))
            .modifier(NamedAccessibilityAction(name: "Ungroup", perform: onUngroup))
            .modifier(NamedAccessibilityAction(name: "Edit Text", perform: editTextAction))
            .accessibilityHidden(suppressesString)
    }

    /// VoiceOver edits text only on the primary element, and only when the field is closed.
    private var editTextAction: (() -> Void)? {
        guard element.type == .text, role == .primary, !suppressesString else { return nil }
        return onEditText
    }

    private var frameSize: CGSize {
        CGSize(
            width: max(abs(element.size.width) * scale, 1),
            height: max(abs(element.size.height) * scale, 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        switch element.type {
        case .text:
            textBody
        case .line:
            lineBody
        case .image:
            imageBody
        case .group:
            groupBody
        case .rectangle, .roundedRectangle, .circle:
            shapeBody
        }
    }

    private var shapeBody: some View {
        shape
            .fill(fillColor)
            .overlay {
                if let stroke = element.stroke {
                    shape.stroke(style: .init(
                        lineWidth: max(stroke.width * scale, 0)
                    ))
                    .foregroundStyle(stroke.color.swiftUIColor)
                }
            }
    }

    private var shape: AnyShape {
        switch element.type {
        case .roundedRectangle:
            AnyShape(RoundedRectangle(cornerRadius: max(element.cornerRadius * scale, 0), style: .continuous))
        case .circle:
            AnyShape(Ellipse())
        default:
            AnyShape(Rectangle())
        }
    }

    @ViewBuilder
    private var textBody: some View {
        if suppressesString {
            Color.clear
        } else {
            renderedText
        }
    }

    private var renderedText: some View {
        let text = element.text
        return Text(text?.string ?? "")
            .font(
                .custom(text?.fontName ?? "Helvetica Neue", size: (text?.fontSize ?? 17) * scale)
                    .weight(text?.fontWeight.swiftUIWeight ?? .regular)
            )
            .foregroundStyle((text?.color ?? .black).swiftUIColor)
            .multilineTextAlignment(text?.alignment.swiftUIAlignment ?? .leading)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: text?.alignment.frameAlignment ?? .leading
            )
            .minimumScaleFactor(0.5)
    }

    /// The line runs through the centre of its bounding box, then the element rotation is applied outside.
    private var lineBody: some View {
        let length = (element.size.width * element.size.width + element.size.height * element.size.height).squareRoot() * scale
        let angle = atan2(element.size.height, element.size.width)
        let width = max((element.stroke?.width ?? 1) * scale, 1)
        return Capsule()
            .fill((element.stroke?.color ?? .black).swiftUIColor)
            .frame(width: max(length, 1), height: width)
            .rotationEffect(.radians(angle))
    }

    private var imageBody: some View {
        ZStack {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(element.fill?.color.swiftUIColor ?? Color.secondary.opacity(0.2))
                Text("Image")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var groupBody: some View {
        RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
            .strokeBorder(
                Color.secondary,
                style: StrokeStyle(lineWidth: max(scale, 0.5), dash: [4 * scale, 4 * scale])
            )
    }

    /// An element with no paint still has a faint fill so it can be selected.
    private var fillColor: Color {
        element.fill?.color.swiftUIColor ?? Color.primary.opacity(0.08)
    }
}

/// Adds a named VoiceOver action only when the editor has one to perform.
private struct NamedAccessibilityAction: ViewModifier {
    var name: String
    var perform: (() -> Void)?

    func body(content: Content) -> some View {
        if let perform {
            content.accessibilityAction(named: name, perform)
        } else {
            content
        }
    }
}
