import CanvasModel
import SwiftUI

/// Reads the canvas pane and publishes a plain `CanvasLayoutContext`.
struct CanvasLayoutReader<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.displayScale) private var displayScale
    @State private var context = CanvasLayoutContext.empty
    @State private var probe = LayoutProbe(width: 0, height: 0, areas: [])

    private let content: (CanvasLayoutContext) -> Content

    init(@ViewBuilder content: @escaping (CanvasLayoutContext) -> Content) {
        self.content = content
    }

    var body: some View {
        content(context)
            .onGeometryChange(for: LayoutProbe.self) { proxy in
                LayoutProbe(
                    width: Double(proxy.size.width),
                    height: Double(proxy.size.height),
                    areas: ReservedRegionMapping.areas(from: proxy)
                )
            } action: { probe in
                self.probe = probe
                publish()
            }
            .onChange(of: horizontalSizeClass) { _, _ in publish() }
            .onChange(of: displayScale) { _, _ in publish() }
    }

    private func publish() {
        let next = CanvasLayoutContext(
            bounds: CanvasRect(
                origin: .zero,
                size: CanvasSize(width: probe.width, height: probe.height)
            ),
            horizontalSizeClass: CanvasSizeClass(horizontalSizeClass),
            reservedAreas: probe.areas,
            displayScale: Double(displayScale)
        )
        if next != context {
            context = next
        }
    }
}

private struct LayoutProbe: Equatable {
    var width: Double
    var height: Double
    var areas: [CanvasReservedArea]
}
