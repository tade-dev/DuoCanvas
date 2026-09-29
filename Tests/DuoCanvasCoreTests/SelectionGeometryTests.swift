import CanvasModel
import Testing

@Suite("Selection geometry")
struct SelectionGeometryTests {
    @Test func handlesSitOnTheBoxWhenNothingIsReserved() {
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 80),
            rotationDegrees: 0,
            paneOrigin: .zero,
            reservedAreas: []
        )
        let centers = Dictionary(uniqueKeysWithValues: placements.map { ($0.handle, $0.center) })
        #expect(centers[.topLeading] == CanvasPoint(x: 0, y: 0))
        #expect(centers[.top] == CanvasPoint(x: 50, y: 0))
        #expect(centers[.topTrailing] == CanvasPoint(x: 100, y: 0))
        #expect(centers[.leading] == CanvasPoint(x: 0, y: 40))
        #expect(centers[.trailing] == CanvasPoint(x: 100, y: 40))
        #expect(centers[.bottomLeading] == CanvasPoint(x: 0, y: 80))
        #expect(centers[.bottom] == CanvasPoint(x: 50, y: 80))
        #expect(centers[.bottomTrailing] == CanvasPoint(x: 100, y: 80))
        #expect(centers[.rotate] == CanvasPoint(x: 50, y: -SelectionHandleLayout.rotateGap))
    }

    @Test func aBlockedCornerSlidesAlongItsEdge() {
        let obstacle = CanvasReservedArea(
            id: "fold",
            frame: CanvasRect(origin: CanvasPoint(x: -40, y: -40), size: CanvasSize(width: 60, height: 60)),
            margins: .zero,
            isActive: true,
            kind: .division
        )
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 80),
            rotationDegrees: 0,
            paneOrigin: .zero,
            reservedAreas: [obstacle]
        )
        let centers = Dictionary(uniqueKeysWithValues: placements.map { ($0.handle, $0.center) })
        let moved = centers[.topLeading]!
        #expect(moved != CanvasPoint(x: 0, y: 0))
        let onTopEdge = moved.y == 0 && moved.x >= 0 && moved.x <= 100
        let onLeadingEdge = moved.x == 0 && moved.y >= 0 && moved.y <= 80
        #expect(onTopEdge || onLeadingEdge)
        #expect(!hitIntersects(moved, area: obstacle))
        #expect(centers[.topTrailing] == CanvasPoint(x: 100, y: 0))
        #expect(centers[.bottomTrailing] == CanvasPoint(x: 100, y: 80))
    }

    @Test func anInactiveAreaDoesNotMoveHandles() {
        let obstacle = CanvasReservedArea(
            id: "fold",
            frame: CanvasRect(origin: CanvasPoint(x: -40, y: -40), size: CanvasSize(width: 80, height: 80)),
            margins: .zero,
            isActive: false,
            kind: .division
        )
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 80),
            rotationDegrees: 0,
            paneOrigin: .zero,
            reservedAreas: [obstacle]
        )
        let leading = placements.first { $0.handle == .topLeading }
        #expect(leading?.center == CanvasPoint(x: 0, y: 0))
    }

    @Test func aFullyBlockedEdgeStaysOnTheIdealPoint() {
        let obstacle = CanvasReservedArea(
            id: "cover",
            frame: CanvasRect(origin: CanvasPoint(x: -80, y: -80), size: CanvasSize(width: 400, height: 400)),
            margins: .zero,
            isActive: true,
            kind: .occlusion
        )
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 80),
            rotationDegrees: 0,
            paneOrigin: .zero,
            reservedAreas: [obstacle]
        )
        let centers = Dictionary(uniqueKeysWithValues: placements.map { ($0.handle, $0.center) })
        #expect(centers[.top] == CanvasPoint(x: 50, y: 0))
        #expect(centers[.rotate] == CanvasPoint(x: 50, y: -SelectionHandleLayout.rotateGap))
    }

    @Test func rotationKeepsAnUnrotatedObstacleFromMovingTheHandle() {
        let obstacle = CanvasReservedArea(
            id: "corner",
            frame: CanvasRect(origin: CanvasPoint(x: -30, y: -30), size: CanvasSize(width: 40, height: 40)),
            margins: .zero,
            isActive: true,
            kind: .division
        )
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 20),
            rotationDegrees: 90,
            paneOrigin: .zero,
            reservedAreas: [obstacle]
        )
        let leading = placements.first { $0.handle == .topLeading }
        #expect(leading?.center == CanvasPoint(x: 0, y: 0))
    }

    @Test func rotationMovesAHandleThatLandsInTheArea() {
        let obstacle = CanvasReservedArea(
            id: "rotated",
            frame: CanvasRect(origin: CanvasPoint(x: 40, y: -60), size: CanvasSize(width: 40, height: 40)),
            margins: .zero,
            isActive: true,
            kind: .occlusion
        )
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 20),
            rotationDegrees: 90,
            paneOrigin: .zero,
            reservedAreas: [obstacle]
        )
        let leading = placements.first { $0.handle == .topLeading }
        #expect(leading?.center != CanvasPoint(x: 0, y: 0))
    }

    @Test func hitTestingFindsTheHandleAndMissesTheMiddle() {
        let placements = SelectionHandleLayout.placements(
            localSize: CanvasSize(width: 100, height: 80),
            rotationDegrees: 0,
            paneOrigin: .zero,
            reservedAreas: []
        )
        let centers = Dictionary(uniqueKeysWithValues: placements.map { ($0.handle, $0.center) })
        #expect(SelectionHandleLayout.hitHandle(at: CanvasPoint(x: 0, y: 0), centers: centers) == .topLeading)
        #expect(SelectionHandleLayout.hitHandle(at: CanvasPoint(x: 50, y: 40), centers: centers) == nil)
        #expect(
            SelectionHandleLayout.hitHandle(
                at: CanvasPoint(x: 50, y: -SelectionHandleLayout.rotateGap),
                centers: centers
            ) == .rotate
        )
    }

    @Test func trailingResizeKeepsTheLeadingEdge() {
        let result = SelectionGeometry.resized(
            handle: .trailing,
            position: CanvasPoint(x: 10, y: 20),
            size: CanvasSize(width: 100, height: 40),
            rotationDegrees: 0,
            localTranslation: CanvasPoint(x: 15, y: 9),
            minimumLength: 8
        )
        #expect(result.position == CanvasPoint(x: 10, y: 20))
        #expect(result.size == CanvasSize(width: 115, height: 40))
    }

    @Test func leadingResizeMovesTheOrigin() {
        let result = SelectionGeometry.resized(
            handle: .leading,
            position: .zero,
            size: CanvasSize(width: 100, height: 50),
            rotationDegrees: 0,
            localTranslation: CanvasPoint(x: 10, y: 0),
            minimumLength: 8
        )
        #expect(result.position == CanvasPoint(x: 10, y: 0))
        #expect(result.size == CanvasSize(width: 90, height: 50))
    }

    @Test func resizeStopsAtTheMinimumAndKeepsTheAnchor() {
        let start = CanvasPoint(x: 0, y: 0)
        let size = CanvasSize(width: 20, height: 40)
        let anchorBefore = SelectionGeometry.canvasPoint(
            localX: 20,
            localY: 20,
            position: start,
            size: size,
            rotationDegrees: 0
        )
        let result = SelectionGeometry.resized(
            handle: .leading,
            position: start,
            size: size,
            rotationDegrees: 0,
            localTranslation: CanvasPoint(x: 30, y: 0),
            minimumLength: 8
        )
        #expect(result.size.width == 8)
        let anchorAfter = SelectionGeometry.canvasPoint(
            localX: result.size.width,
            localY: result.size.height / 2,
            position: result.position,
            size: result.size,
            rotationDegrees: 0
        )
        #expect(anchorBefore == anchorAfter)
    }

    @Test func rotatedResizeKeepsTheOppositeEdgeFixed() {
        let start = CanvasPoint(x: 10, y: 20)
        let size = CanvasSize(width: 100, height: 40)
        let degrees = 30.0
        let anchorBefore = SelectionGeometry.canvasPoint(
            localX: 0,
            localY: 20,
            position: start,
            size: size,
            rotationDegrees: degrees
        )
        let result = SelectionGeometry.resized(
            handle: .trailing,
            position: start,
            size: size,
            rotationDegrees: degrees,
            localTranslation: CanvasPoint(x: 15, y: 4),
            minimumLength: 8
        )
        let anchorAfter = SelectionGeometry.canvasPoint(
            localX: 0,
            localY: result.size.height / 2,
            position: result.position,
            size: result.size,
            rotationDegrees: degrees
        )
        #expect(abs(result.size.width - 115) < 0.001)
        #expect(abs(result.size.height - 40) < 0.001)
        #expect(abs(anchorBefore.x - anchorAfter.x) < 0.001)
        #expect(abs(anchorBefore.y - anchorAfter.y) < 0.001)
    }

    @Test func localTranslationFollowsTheElementAxes() {
        let flat = SelectionGeometry.localTranslation(artboardX: 10, artboardY: 4, scale: 2, rotationDegrees: 0)
        #expect(flat == CanvasPoint(x: 5, y: 2))

        let turned = SelectionGeometry.localTranslation(artboardX: 0, artboardY: 10, scale: 1, rotationDegrees: 90)
        #expect(abs(turned.x - 10) < 0.001)
        #expect(abs(turned.y) < 0.001)
    }

    @Test func clockwiseDeltaWrapsAcrossTheBranchCut() {
        let quarter = SelectionGeometry.clockwiseDeltaDegrees(from: 0, to: Double.pi / 2)
        #expect(abs(quarter - 90) < 0.001)
        let previous = 170.0 * Double.pi / 180
        let next = -170.0 * Double.pi / 180
        let wrapped = SelectionGeometry.clockwiseDeltaDegrees(from: previous, to: next)
        #expect(abs(wrapped - 20) < 0.001)
    }

    private func hitIntersects(_ center: CanvasPoint, area: CanvasReservedArea) -> Bool {
        let half = SelectionHandleLayout.hitExtent / 2
        let hit = CanvasRect(
            origin: CanvasPoint(x: center.x - half, y: center.y - half),
            size: CanvasSize(width: SelectionHandleLayout.hitExtent, height: SelectionHandleLayout.hitExtent)
        )
        return area.frame.intersects(hit)
    }
}
