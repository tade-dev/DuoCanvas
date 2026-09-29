import AdaptiveLayout
import CanvasModel
import Testing

struct LayoutTests {
    @Test func edgeContactCountsAsAnIntersection() {
        let left = CanvasRect(origin: .zero, size: CanvasSize(width: 10, height: 10))
        let touching = CanvasRect(origin: CanvasPoint(x: 10, y: 0), size: CanvasSize(width: 4, height: 4))
        #expect(left.intersects(touching))
    }

    @Test func separatedRectanglesDoNotIntersect() {
        let left = CanvasRect(origin: .zero, size: CanvasSize(width: 10, height: 10))
        let right = CanvasRect(origin: CanvasPoint(x: 12, y: 0), size: CanvasSize(width: 4, height: 4))
        #expect(!left.intersects(right))
    }

    @Test func negativeSizeIntersectsOnTheStandardizedBox() {
        let flipped = CanvasRect(
            origin: CanvasPoint(x: 10, y: 10),
            size: CanvasSize(width: -10, height: -10)
        )
        let overlapping = CanvasRect(origin: .zero, size: CanvasSize(width: 5, height: 5))
        #expect(flipped.standardized.origin == .zero)
        #expect(flipped.intersects(overlapping))
    }

    @Test func regularWidthUsesTheSplitAndCompactUsesTheSheet() {
        #expect(EditorArrangement.forHorizontalSizeClass(.regular) == .split)
        #expect(EditorArrangement.forHorizontalSizeClass(.compact) == .sheet)
        #expect(EditorArrangement.forHorizontalSizeClass(.unspecified) == .sheet)
    }

    @Test func emptyLayoutContextHasNoReservedAreas() {
        #expect(CanvasLayoutContext.empty.reservedAreas.isEmpty)
        #expect(CanvasLayoutContext.empty.horizontalSizeClass == .unspecified)
        #expect(CanvasLayoutContext.empty.displayScale == 1)
    }
}
