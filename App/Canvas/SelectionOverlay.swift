import CanvasModel
import SwiftUI
import UIKit

/// Resize and rotate handles, drawn only. The page gesture owns the touch.
/// VoiceOver skips the overlay; the inspector's numeric fields resize and rotate the same element.
struct SelectionOverlay: View {
    var element: CanvasElement
    var scale: Double
    var placements: [SelectionHandlePlacement]

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let box = CanvasRect(origin: element.position, size: element.size).standardized
        let width = max(box.size.width * scale, 1)
        let height = max(box.size.height * scale, 1)
        ZStack(alignment: .topLeading) {
            rotateStem(width: width)
            ForEach(placements, id: \.handle) { placement in
                handleControl(placement)
            }
        }
        .frame(width: CGFloat(width), height: CGFloat(height))
        .rotationEffect(.degrees(element.rotation.degrees))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var strokeColor: Color {
        contrast == .increased ? Color.primary : Color.accentColor
    }

    private var lineWidth: CGFloat {
        contrast == .increased ? 2 : 1
    }

    @ViewBuilder
    private func rotateStem(width: Double) -> some View {
        if let rotate = placements.first(where: { $0.handle == .rotate }) {
            Path { path in
                path.move(to: CGPoint(x: CGFloat(width / 2), y: 0))
                path.addLine(to: CGPoint(x: CGFloat(rotate.center.x), y: CGFloat(rotate.center.y)))
            }
            .stroke(strokeColor, lineWidth: lineWidth)
        }
    }

    private func handleControl(_ placement: SelectionHandlePlacement) -> some View {
        let isRotate = placement.handle == .rotate
        return ZStack {
            if isRotate {
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .overlay {
                        Circle().strokeBorder(strokeColor, lineWidth: lineWidth)
                    }
                    .frame(width: 10, height: 10)
            } else {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .strokeBorder(strokeColor, lineWidth: lineWidth)
                    }
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: CGFloat(SelectionHandleLayout.hitExtent), height: CGFloat(SelectionHandleLayout.hitExtent))
        .position(x: CGFloat(placement.center.x), y: CGFloat(placement.center.y))
        .accessibilityHidden(true)
    }
}

enum ArtboardCoordinate {
    static let name = "DuoCanvasArtboard"
}
