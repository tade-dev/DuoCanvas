import CanvasModel
import SwiftUI
import UIKit

/// Resize and rotate handles. There is no system control for these, so the overlay is custom.
/// VoiceOver skips it; the inspector's numeric fields resize and rotate the same element.
struct SelectionOverlay: View {
    var element: CanvasElement
    var scale: Double
    var placements: [SelectionHandlePlacement]
    var editor: EditorModel

    @Environment(\.colorSchemeContrast) private var contrast
    @GestureState private var handleGestureActive = false

    var body: some View {
        let box = CanvasRect(origin: element.position, size: element.size).standardized
        let width = max(box.size.width * scale, 1)
        let height = max(box.size.height * scale, 1)
        ZStack(alignment: .topLeading) {
            rotateStem(width: width)
                .allowsHitTesting(false)
            ForEach(placements, id: \.handle) { placement in
                handleControl(placement)
            }
        }
        .frame(width: CGFloat(width), height: CGFloat(height))
        .contentShape(HandleHitShape(placements: placements, extent: SelectionHandleLayout.hitExtent))
        .rotationEffect(.degrees(element.rotation.degrees))
        .accessibilityHidden(true)
        .onChange(of: handleGestureActive) { _, active in
            if !active {
                editor.noteCanvasGestureEnded()
            }
        }
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
        .contentShape(Rectangle())
        .position(x: CGFloat(placement.center.x), y: CGFloat(placement.center.y))
        .highPriorityGesture(handleDrag(placement.handle))
        .accessibilityHidden(true)
    }

    private func handleDrag(_ handle: SelectionHandle) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(ArtboardCoordinate.name))
            .updating($handleGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                switch handle {
                case .rotate:
                    editor.previewRotate(
                        of: element.id,
                        canvasPoint: CanvasPoint(
                            x: Double(value.location.x) / scale,
                            y: Double(value.location.y) / scale
                        )
                    )
                default:
                    editor.previewResize(
                        of: element.id,
                        handle: handle,
                        artboardTranslationX: Double(value.translation.width),
                        artboardTranslationY: Double(value.translation.height),
                        scale: scale
                    )
                }
            }
            .onEnded { _ in
                switch handle {
                case .rotate:
                    editor.endRotate()
                default:
                    editor.endResize()
                }
            }
    }
}

enum ArtboardCoordinate {
    static let name = "DuoCanvasArtboard"
}

/// Hit shape for the handle boxes only, so a drag on the element body still reaches the page.
private struct HandleHitShape: Shape {
    var placements: [SelectionHandlePlacement]
    var extent: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let half = CGFloat(extent / 2)
        let side = CGFloat(extent)
        for placement in placements {
            path.addRect(
                CGRect(
                    x: CGFloat(placement.center.x) - half,
                    y: CGFloat(placement.center.y) - half,
                    width: side,
                    height: side
                )
            )
        }
        return path
    }
}
