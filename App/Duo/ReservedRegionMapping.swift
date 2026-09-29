import CanvasModel
import SwiftUI

/// Maps system reserved regions into plain canvas values.
///
/// Calls used here, from the iOS 27.1 docs and the public Duo examples:
/// `reservedRegions(kind:options:layoutDirectionBehavior:)`.
/// Division and occlusion are both requested with `.includeInactive`, so a flat
/// fold is still present and marked inactive. Frames stay in the geometry proxy's
/// coordinate space, which is the canvas pane. The default layout-direction
/// behaviour is kept, so the frames match the rest of the SwiftUI layout.
enum ReservedRegionMapping {
    static func areas(from proxy: GeometryProxy) -> [CanvasReservedArea] {
        let divisions = proxy.reservedRegions(kind: .division, options: [.includeInactive])
        let occlusions = proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
        let mapped = divisions.map { area(from: $0, kind: .division) }
            + occlusions.map { area(from: $0, kind: .occlusion) }
        return mapped.sorted { $0.id < $1.id }
    }

    private static func area(from region: ReservedRegion, kind: CanvasReservedArea.Kind) -> CanvasReservedArea {
        CanvasReservedArea(
            id: String(describing: region.id),
            frame: CanvasRect(
                origin: CanvasPoint(x: Double(region.frame.origin.x), y: Double(region.frame.origin.y)),
                size: CanvasSize(width: Double(region.frame.size.width), height: Double(region.frame.size.height))
            ),
            margins: CanvasEdgeInsets(
                top: Double(region.margins.top),
                leading: Double(region.margins.leading),
                bottom: Double(region.margins.bottom),
                trailing: Double(region.margins.trailing)
            ),
            isActive: region.isActive,
            kind: kind
        )
    }
}
