import CanvasModel
import CoreGraphics
import SwiftUI
import UIKit

struct CanvasElementView: View {
    var element: CanvasElement
    var scale: Double
    var imageData: Data?
    var isSelected: Bool
    var selectionLineWidth: CGFloat
    var onSelect: () -> Void

    var body: some View {
        content
            .opacity(element.opacity)
            .frame(width: frameSize.width, height: frameSize.height)
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: selectionLineWidth)
                        .allowsHitTesting(false)
                }
            }
            .rotationEffect(.degrees(element.rotation.degrees))
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CanvasFormatting.accessibilityDescription(for: element))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(.default, onSelect)
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
                    shape.strokeBorder(
                        stroke.color.swiftUIColor,
                        lineWidth: max(stroke.width * scale, 0)
                    )
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

    private var textBody: some View {
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
