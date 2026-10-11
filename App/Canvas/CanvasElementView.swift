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

struct CanvasElementView: View, @MainActor Equatable {
    var element: CanvasElement
    var scale: Double
    var displayImage: UIImage?
    var role: ElementSelectionRole
    var indicator: SelectionIndicatorStyle
    var accessibilityContext: CanvasAccessibilityContext
    /// Nil for a static render. The live canvas always supplies the rotor namespace.
    var rotorNamespace: Namespace.ID?
    var sortPriority: Double
    /// Hides the rendered string while the canvas text field draws it.
    var suppressesString: Bool = false
    /// ImageRenderer output is not an accessibility element.
    var isAccessibilityElement: Bool = true
    var onSelect: () -> Void = {}
    var onAction: (CanvasAccessibilityAction) -> Void = { _ in }

    /// Closures are left out of equality. They call the same editor, and a changed
    /// element or selection role rebuilds them. This keeps a drag from redrawing
    /// every other element on each frame.
    static func == (lhs: CanvasElementView, rhs: CanvasElementView) -> Bool {
        lhs.element == rhs.element
            && lhs.scale == rhs.scale
            && lhs.displayImage === rhs.displayImage
            && lhs.role == rhs.role
            && lhs.indicator == rhs.indicator
            && lhs.accessibilityContext == rhs.accessibilityContext
            && lhs.sortPriority == rhs.sortPriority
            && lhs.suppressesString == rhs.suppressesString
            && lhs.isAccessibilityElement == rhs.isAccessibilityElement
    }

    /// Selection-free drawing for PNG export. No actions, and hidden from VoiceOver.
    static func rendered(
        element: CanvasElement,
        scale: Double,
        displayImage: UIImage?
    ) -> CanvasElementView {
        CanvasElementView(
            element: element,
            scale: scale,
            displayImage: displayImage,
            role: .none,
            indicator: SelectionIndicatorStyle.resolve(
                increasedContrast: false,
                differentiateWithoutColor: false,
                crossesReservedArea: false
            ),
            accessibilityContext: CanvasAccessibilityContext(
                role: .none,
                isText: false,
                isGroupedChild: false,
                inlineEditing: false,
                canDuplicate: false,
                canGroup: false,
                canUngroup: false,
                inspectorIsSheet: false
            ),
            rotorNamespace: nil,
            sortPriority: 0,
            suppressesString: false,
            isAccessibilityElement: false
        )
    }

    var body: some View {
        if isAccessibilityElement {
            accessibleDrawing
        } else {
            drawing.accessibilityHidden(true)
        }
    }

    private var drawing: some View {
        content
            .opacity(element.opacity)
            .frame(width: frameSize.width, height: frameSize.height)
            .overlay {
                if role != .none, !suppressesString {
                    selectionOutline
                }
            }
            .rotationEffect(.degrees(element.rotation.degrees))
            .contentShape(Rectangle())
    }

    private var accessibleDrawing: some View {
        let speech = CanvasAccessibility.speech(
            for: element,
            role: accessibilityContext.role,
            isGroupedChild: accessibilityContext.isGroupedChild,
            imageUnavailable: element.type == .image && displayImage == nil
        )
        return drawing
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(speech.label)
            .accessibilityValue(speech.value)
            .accessibilityHint(speech.hint)
            .accessibilityAddTraits(accessibilityContext.role == .none ? AccessibilityTraits() : .isSelected)
            .accessibilityAction(.default, onSelect)
            .modifier(AccessibilityActionList(
                actions: CanvasAccessibility.actions(for: accessibilityContext),
                perform: onAction
            ))
            .modifier(RotorEntryMarker(id: element.id, namespace: rotorNamespace))
            .accessibilitySortPriority(sortPriority)
            .accessibilityHidden(suppressesString)
    }

    private var selectionOutline: some View {
        let width = CGFloat(indicator.lineWidth)
        let color = indicator.usesHighContrastColor ? Color.primary : Color.accentColor
        return ZStack {
            Rectangle()
                .strokeBorder(
                    color,
                    style: StrokeStyle(
                        lineWidth: width,
                        dash: role == .primary ? [] : [6, 4]
                    )
                )
            if indicator.drawsShapeCue, min(frameSize.width, frameSize.height) > (width + 3) * 2 {
                Rectangle()
                    .inset(by: width + 3)
                    .stroke(color, style: StrokeStyle(lineWidth: max(width - 1, 1), dash: [2, 2]))
            }
        }
        .allowsHitTesting(false)
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
            if let displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(element.fill?.color.swiftUIColor ?? Color.secondary.opacity(0.2))
                Text(CanvasEmptyCopy.imageUnavailable)
                    .font(.system(size: 12))
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

/// Attaches a rotor entry only when the live canvas has supplied a namespace.
private struct RotorEntryMarker: ViewModifier {
    var id: CanvasElement.ID
    var namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.accessibilityRotorEntry(id: id, in: namespace)
        } else {
            content
        }
    }
}

