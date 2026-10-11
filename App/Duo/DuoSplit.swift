import AdaptiveLayout
import CanvasModel
import SwiftUI

/// Canvas primary, inspector secondary, using the system split.
///
/// The style is `.split` with both axes left to the system: side by side when the
/// container is wider than it is tall, canvas above inspector when it is taller.
/// A horizontal-only axis is not set, because that can hide the inspector when the
/// container is taller than it is wide.
///
/// `splitArrangementLayoutSize` is applied to the inspector. Width values are the
/// horizontal split. Height values are the vertical split. A fold may ignore these
/// and divide on the hinge; check that in Device Hub.
///
/// ArrangementView does not offer a draggable divider. The panes are cards on a
/// black gutter, and the grabber is a capsule in that gutter. It writes the
/// inspector's ideal width. It is hidden when the split is stacked and when that
/// width would sit on an active division. The stacked layout keeps the cards.
struct DuoSplit<Primary: View, Secondary: View>: View {
    private let primary: Primary
    private let secondary: Secondary

    @AppStorage(InspectorColumnStorage.key) private var storedWidth = InspectorColumnSizing.idealWidth
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    @State private var probe = SplitChromeProbe(width: 0, height: 0, areas: [])
    @State private var axis: SplitPaneAxis?
    @State private var inspectorFrame: CGRect = .zero

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        let inspectorIsTrailing = layoutDirection != .rightToLeft
        let layoutWidth = InspectorColumnSizing.clamped(storedWidth, containerWidth: probe.width)
        let limits = InspectorColumnSizing.limits(containerWidth: probe.width)
        let splitX = resolvedSplitX(layoutWidth: layoutWidth, inspectorIsTrailing: inspectorIsTrailing)
        let blocked = InspectorDividerClearance.blockedByActiveDivision(
            splitX: splitX,
            containerHeight: probe.height,
            reservedAreas: probe.areas
        )
        let showsDivider = InspectorDividerVisibility.shows(axis: axis, blockedByDivision: blocked)
            && probe.width > 1
            && probe.height > 1

        ArrangementView {
            SplitPaneCard(axis: axis, isPrimary: true) {
                primary
            }
            .layoutPriority(1)
        } secondary: {
            SplitPaneCard(axis: axis, isPrimary: false) {
                secondary
            }
            .splitArrangementLayoutSize(
                    minWidth: CGFloat(limits.lower),
                    idealWidth: CGFloat(layoutWidth),
                    maxWidth: CGFloat(limits.upper),
                    minHeight: InspectorPaneMetrics.minimumHeight,
                    idealHeight: InspectorPaneMetrics.idealHeight,
                    maxHeight: InspectorPaneMetrics.maximumHeight
                )
                .background {
                    ZStack {
                        SplitAxisProbe { axis = $0 }
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: InspectorFramePreference.self,
                                value: proxy.frame(in: .named(EditorSplitSpace.name))
                            )
                        }
                    }
                }
        }
        .arrangementViewStyle(.split)
        .background(Color.black)
        .containerShape(
            RoundedRectangle(
                cornerRadius: CGFloat(SplitPaneChrome.containerCornerRadius),
                style: .continuous
            )
        )
        .coordinateSpace(name: EditorSplitSpace.name)
        .onGeometryChange(for: SplitChromeProbe.self) { proxy in
            SplitChromeProbe(
                width: Double(proxy.size.width),
                height: Double(proxy.size.height),
                areas: ReservedRegionMapping.areas(from: proxy)
            )
        } action: { probe in
            self.probe = probe
        }
        .onPreferenceChange(InspectorFramePreference.self) { inspectorFrame = $0 }
        .overlay {
            if showsDivider {
                InspectorDivider(
                    width: $storedWidth,
                    containerWidth: probe.width,
                    splitX: splitX,
                    inspectorIsTrailing: inspectorIsTrailing,
                    increasedContrast: contrast == .increased,
                    reduceMotion: reduceMotion
                )
            }
        }
    }

    private func resolvedSplitX(layoutWidth: Double, inspectorIsTrailing: Bool) -> Double {
        if inspectorFrame.width > 1, inspectorFrame.height > 1 {
            return inspectorIsTrailing ? inspectorFrame.minX : inspectorFrame.maxX
        }
        if inspectorIsTrailing {
            return max(0, probe.width - layoutWidth)
        }
        return layoutWidth
    }
}

enum InspectorColumnStorage {
    static let key = "inspectorColumnWidth"
}

enum InspectorPaneMetrics {
    static let minimumHeight: CGFloat = 240
    static let idealHeight: CGFloat = 320
    static let maximumHeight: CGFloat = 480
}

private struct SplitChromeProbe: Equatable {
    var width: Double
    var height: Double
    var areas: [CanvasReservedArea]
}

private struct InspectorFramePreference: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// One pane drawn as a card. The black split shows through the gutter.
///
/// `ConcentricRectangle` is iOS 26. `isUniform` keeps every corner rounded: the corners
/// beside the gutter are far from the container, and without it those corners go square.
/// The container shape is `.rect(cornerRadius:style: .continuous)` on the split.
private struct SplitPaneCard<Content: View>: View {
    var axis: SplitPaneAxis?
    var isPrimary: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        let insets = SplitPaneChrome.insets(axis: axis, isPrimary: isPrimary)
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground), in: shape)
            .clipShape(shape)
            .padding(EdgeInsets(
                top: CGFloat(insets.top),
                leading: CGFloat(insets.leading),
                bottom: CGFloat(insets.bottom),
                trailing: CGFloat(insets.trailing)
            ))
            .background(Color.black)
    }
}

/// Reads the split axis from inside the arrangement. The value is nil outside one.
private struct SplitAxisProbe: View {
    var onAxis: (SplitPaneAxis?) -> Void
    @Environment(\.splitArrangementAxis) private var axis

    var body: some View {
        Color.clear
            .onAppear { onAxis(Self.map(axis)) }
            .onChange(of: axis) { _, newValue in
                onAxis(Self.map(newValue))
            }
    }

    /// Horizontal places the panes side by side. Vertical stacks the canvas above the inspector.
    private static func map(_ axis: Axis?) -> SplitPaneAxis? {
        switch axis {
        case .horizontal:
            .horizontal
        case .vertical:
            .vertical
        case nil:
            nil
        }
    }
}
