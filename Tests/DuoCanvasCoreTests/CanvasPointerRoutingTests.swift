import CanvasModel
import Testing

@Suite("Canvas pointer routing")
struct CanvasPointerRoutingTests {
    @Test func aShortPressOnTheBodyIsStillPending() {
        let intent = CanvasPointerRouting.intent(
            elapsed: 0.24,
            distance: 0,
            onBody: true,
            handleOutsideBody: .bottomTrailing
        )
        #expect(intent == .pending)
    }

    @Test func holdingOnTheBodyArmsAMoveEvenWhenAHandleOverlaps() {
        let armed = CanvasPointerRouting.intent(
            elapsed: 0.25,
            distance: 0,
            onBody: true,
            handleOutsideBody: .bottomTrailing
        )
        let dragged = CanvasPointerRouting.intent(
            elapsed: 0.4,
            distance: 40,
            onBody: true,
            handleOutsideBody: .trailing
        )
        #expect(armed == .move)
        #expect(dragged == .move)
    }

    @Test func draggingTheBodyBeforeTheHoldDoesNotMoveOrResize() {
        let intent = CanvasPointerRouting.intent(
            elapsed: 0.1,
            distance: CanvasPointerRouting.dragSlop,
            onBody: true,
            handleOutsideBody: .bottom
        )
        #expect(intent == .ignore)
    }

    @Test func aHandleOutsideTheBodyResizesWithoutWaiting() {
        let resize = CanvasPointerRouting.intent(
            elapsed: 0,
            distance: CanvasPointerRouting.dragSlop,
            onBody: false,
            handleOutsideBody: .trailing
        )
        let afterAPause = CanvasPointerRouting.intent(
            elapsed: 1,
            distance: 12,
            onBody: false,
            handleOutsideBody: .topLeading
        )
        #expect(resize == .resize(.trailing))
        #expect(afterAPause == .resize(.topLeading))
    }

    @Test func theRotateHandleStaysARotateAfterAPause() {
        let intent = CanvasPointerRouting.intent(
            elapsed: 0.8,
            distance: CanvasPointerRouting.dragSlop,
            onBody: false,
            handleOutsideBody: .rotate
        )
        #expect(intent == .rotate)
    }

    @Test func aHandleInsideTheSlopDoesNotResizeYet() {
        let intent = CanvasPointerRouting.intent(
            elapsed: 1,
            distance: CanvasPointerRouting.dragSlop - 0.1,
            onBody: false,
            handleOutsideBody: .top
        )
        #expect(intent == .pending)
    }

    @Test func emptySpaceIgnoresADragAndWaitsOnATap() {
        let drag = CanvasPointerRouting.intent(
            elapsed: 0,
            distance: CanvasPointerRouting.dragSlop,
            onBody: false,
            handleOutsideBody: nil
        )
        let tap = CanvasPointerRouting.intent(
            elapsed: 1,
            distance: 0,
            onBody: false,
            handleOutsideBody: nil
        )
        #expect(drag == .ignore)
        #expect(tap == .pending)
    }
}
