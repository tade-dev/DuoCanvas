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
struct DuoSplit<Primary: View, Secondary: View>: View {
    private let primary: Primary
    private let secondary: Secondary

    init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        ArrangementView {
            primary
                .layoutPriority(1)
        } secondary: {
            secondary
                .splitArrangementLayoutSize(
                    minWidth: InspectorPaneMetrics.minimumWidth,
                    idealWidth: InspectorPaneMetrics.idealWidth,
                    maxWidth: InspectorPaneMetrics.maximumWidth,
                    minHeight: InspectorPaneMetrics.minimumHeight,
                    idealHeight: InspectorPaneMetrics.idealHeight,
                    maxHeight: InspectorPaneMetrics.maximumHeight
                )
        }
        .arrangementViewStyle(.split)
    }
}

enum InspectorPaneMetrics {
    static let minimumWidth: CGFloat = 280
    static let idealWidth: CGFloat = 320
    static let maximumWidth: CGFloat = 400
    static let minimumHeight: CGFloat = 240
    static let idealHeight: CGFloat = 320
    static let maximumHeight: CGFloat = 480
}
