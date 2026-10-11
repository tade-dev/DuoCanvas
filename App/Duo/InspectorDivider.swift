import AdaptiveLayout
import CanvasModel
import SwiftUI

/// The vertical grabber between the canvas and the inspector.
///
/// Shown only for a side-by-side split that is not sitting on an active fold.
/// The width it writes is chrome: AppStorage in the split, not the document and not undo.
struct InspectorDivider: View {
    @Binding var width: Double
    var containerWidth: Double
    var splitX: Double
    var inspectorIsTrailing: Bool
    var increasedContrast: Bool
    var reduceMotion: Bool

    @State private var gestureStart: Double?
    @State private var overshoot: Double = 0

    var body: some View {
        let metrics = InspectorDividerMetrics.resolve(increasedContrast: increasedContrast)
        let shift = InspectorColumnSizing.pillShift(
            overshoot: overshoot,
            inspectorIsTrailing: inspectorIsTrailing
        )
        let centerX = splitX + shift
        GeometryReader { proxy in
            grabber(metrics)
                .frame(
                    width: CGFloat(metrics.hitWidth),
                    height: max(proxy.size.height, CGFloat(metrics.hitWidth))
                )
                .contentShape(Rectangle())
                .position(x: CGFloat(centerX), y: proxy.size.height / 2)
                .gesture(drag)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Inspector width")
                .accessibilityValue("\(CanvasFormatting.number(layoutWidth)) points")
                .accessibilityHint("Adjusts the inspector width.")
                .accessibilityAdjustableAction { direction in
                    let step = InspectorColumnSizing.voiceOverStep
                    switch direction {
                    case .increment:
                        width = InspectorColumnSizing.adjusted(width, by: step, containerWidth: containerWidth)
                    case .decrement:
                        width = InspectorColumnSizing.adjusted(width, by: -step, containerWidth: containerWidth)
                    @unknown default:
                        break
                    }
                }
        }
        .contentShape(DividerHitShape(centerX: centerX, width: metrics.hitWidth))
    }

    private func grabber(_ metrics: InspectorDividerMetrics) -> some View {
        Capsule()
            .fill(metrics.usesHighContrast ? Color.white : Color(white: 0.78))
            .frame(width: CGFloat(metrics.pillWidth), height: CGFloat(metrics.pillHeight))
            .frame(width: CGFloat(metrics.hitWidth))
            .hoverEffect(.highlight)
            .accessibilityHidden(true)
    }

    private var layoutWidth: Double {
        InspectorColumnSizing.clamped(width, containerWidth: containerWidth)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(EditorSplitSpace.name))
            .onChanged { value in
                if gestureStart == nil {
                    gestureStart = width
                }
                let update = InspectorColumnSizing.drag(
                    startWidth: gestureStart ?? width,
                    translationTowardTrailing: Double(value.translation.width),
                    containerWidth: containerWidth,
                    inspectorIsTrailing: inspectorIsTrailing
                )
                width = update.layoutWidth
                overshoot = update.pillOvershoot
            }
            .onEnded { value in
                let update = InspectorColumnSizing.drag(
                    startWidth: gestureStart ?? width,
                    translationTowardTrailing: Double(value.translation.width),
                    containerWidth: containerWidth,
                    inspectorIsTrailing: inspectorIsTrailing
                )
                gestureStart = nil
                let apply = {
                    width = update.layoutWidth
                    overshoot = 0
                }
                if update.needsSnap, !MotionPolicy.disablesAnimations(reduceMotion: reduceMotion) {
                    withAnimation(.snappy(duration: 0.25)) {
                        apply()
                    }
                } else {
                    apply()
                }
            }
    }
}

/// Limits hits to the grabber strip so the canvas and the inspector still receive taps.
private struct DividerHitShape: Shape {
    var centerX: Double
    var width: Double

    func path(in rect: CGRect) -> Path {
        Path(
            CGRect(
                x: CGFloat(centerX - width / 2),
                y: 0,
                width: CGFloat(width),
                height: rect.height
            )
        )
    }
}

enum EditorSplitSpace {
    static let name = "editorSplit"
}
