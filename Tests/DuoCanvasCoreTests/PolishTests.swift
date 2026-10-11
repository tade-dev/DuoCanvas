import AdaptiveLayout
import CanvasModel
import Foundation
import PersistenceMapping
import Testing

@Suite("Polish")
struct PolishTests {
    @Test func reduceMotionSkipsTheZoomTransition() {
        #expect(MotionPolicy.usesZoomTransition(reduceMotion: false))
        #expect(!MotionPolicy.usesZoomTransition(reduceMotion: true))
        #expect(MotionPolicy.disablesAnimations(reduceMotion: true))
    }

    @Test func emptyCopyAndImageFailureMessagesStayCalm() {
        #expect(CanvasEmptyCopy.homeAction == "New Project")
        #expect(CanvasEmptyCopy.canvasAction == "Add Rectangle")
        #expect(CanvasEmptyCopy.inspectorAction == "Add Rectangle")
        #expect(CanvasImageProblem.empty.message.contains("no data"))
        #expect(CanvasImageProblem.undecodable.message.contains("could not be read"))
        #expect(CanvasImageAudit.notDrawnMessage(count: 0) == "")
        #expect(CanvasImageAudit.notDrawnMessage(count: 1).contains("An image"))
        #expect(CanvasImageAudit.notDrawnMessage(count: 2).contains("2 images"))
        #expect(CanvasExportProblem.invalidCanvasSize.message.contains("no size"))
        #expect(CanvasExportProblem.renderFailed.message.contains("PNG"))
        #expect(CanvasExportCheck.problem(width: 0, height: 10) == .invalidCanvasSize)
        #expect(CanvasExportCheck.problem(width: 10, height: .nan) == .invalidCanvasSize)
        #expect(CanvasExportCheck.problem(width: 1200, height: 800) == nil)
    }

    @Test func missingImagesAreTheOnesWithoutBytes() {
        let present = UUID()
        let absent = UUID()
        let noRef = CanvasElement(id: UUID(), type: .image, size: CanvasSize(width: 10, height: 10))
        let elements = [
            CanvasElement.rectangle(),
            CanvasElement.image(ImageRef(id: present)),
            CanvasElement.image(ImageRef(id: absent)),
            noRef,
        ]
        let missing = CanvasImageAudit.missingIDs(in: elements) { $0 == present }
        #expect(missing == [absent, noRef.id])
    }

    @Test func anUnavailableImageIsSpoken() {
        let element = CanvasElement.image(ImageRef())
        let label = CanvasAccessibility.spokenLabel(
            for: element,
            isGroupedChild: false,
            imageUnavailable: true
        )
        #expect(label.contains("image unavailable"))
        let grouped = CanvasAccessibility.spokenLabel(
            for: element,
            isGroupedChild: true,
            imageUnavailable: true
        )
        #expect(grouped.hasSuffix("inside a group"))
        #expect(grouped.contains("image unavailable"))
    }

    @Test func openingMessagesNameTheBrokenRecord() {
        #expect(CanvasRecordMappingError.corruptBlob.openingMessage.contains("damaged"))
        #expect(CanvasRecordMappingError.unknownElementType("nope").openingMessage.contains("element"))
        #expect(CanvasRecordMappingError.unknownFontWeight("nope").openingMessage.contains("text"))
        #expect(CanvasRecordMappingError.unknownTextAlignment("nope").openingMessage.contains("text"))
    }

    @Test func inspectorWidthStaysInsideTheClamp() {
        let wide = InspectorColumnSizing.limits(containerWidth: 1200)
        #expect(wide.lower == 280)
        #expect(wide.upper == 480)
        #expect(InspectorColumnSizing.clamped(100, containerWidth: 1200) == 280)
        #expect(InspectorColumnSizing.clamped(900, containerWidth: 1200) == 480)
        #expect(InspectorColumnSizing.clamped(320, containerWidth: 1200) == 320)
        #expect(InspectorColumnSizing.clamped(320, containerWidth: 0) == 320)

        let tight = InspectorColumnSizing.limits(containerWidth: 600)
        #expect(tight.lower == 280)
        #expect(tight.upper == 360)

        let cramped = InspectorColumnSizing.limits(containerWidth: 200)
        #expect(cramped.lower == cramped.upper)
        #expect(cramped.lower > 1)
        #expect(cramped.lower < 200)
    }

    @Test func aDragPastTheClampSnapsTheLayoutAndLeavesThePillShort() {
        let inside = InspectorColumnSizing.drag(
            startWidth: 320,
            translationTowardTrailing: -40,
            containerWidth: 1200,
            inspectorIsTrailing: true
        )
        #expect(inside.layoutWidth == 360)
        #expect(inside.pillOvershoot == 0)
        #expect(!inside.needsSnap)

        let past = InspectorColumnSizing.drag(
            startWidth: 460,
            translationTowardTrailing: -80,
            containerWidth: 1200,
            inspectorIsTrailing: true
        )
        #expect(past.layoutWidth == 480)
        #expect(past.needsSnap)
        #expect(past.pillOvershoot == InspectorColumnSizing.rubberBand)
        #expect(InspectorColumnSizing.pillShift(overshoot: past.pillOvershoot, inspectorIsTrailing: true) < 0)

        let leading = InspectorColumnSizing.drag(
            startWidth: 320,
            translationTowardTrailing: 40,
            containerWidth: 1200,
            inspectorIsTrailing: false
        )
        #expect(leading.layoutWidth == 360)
    }

    @Test func voiceOverStepsStayInsideTheClamp() {
        #expect(InspectorColumnSizing.adjusted(320, by: 20, containerWidth: 1200) == 340)
        #expect(InspectorColumnSizing.adjusted(470, by: 20, containerWidth: 1200) == 480)
        #expect(InspectorColumnSizing.adjusted(290, by: -20, containerWidth: 1200) == 280)
    }

    @Test func theDividerShowsOnlyBesideTheCanvasAndOffTheFold() {
        #expect(InspectorDividerVisibility.shows(axis: .horizontal, blockedByDivision: false))
        #expect(!InspectorDividerVisibility.shows(axis: .horizontal, blockedByDivision: true))
        #expect(!InspectorDividerVisibility.shows(axis: .vertical, blockedByDivision: false))
        #expect(!InspectorDividerVisibility.shows(axis: nil, blockedByDivision: false))

        let metrics = InspectorDividerMetrics.resolve(increasedContrast: false)
        #expect(metrics.hitWidth >= CanvasAccessibility.minimumHitTarget)
        #expect(metrics.pillWidth == 4)
        #expect(metrics.pillWidth < metrics.hitWidth)
        #expect(metrics.pillHeight >= 36)
        #expect(metrics.pillHeight <= 44)
        let contrast = InspectorDividerMetrics.resolve(increasedContrast: true)
        #expect(contrast.usesHighContrast)
        #expect(contrast.pillWidth > metrics.pillWidth)
        #expect(contrast.pillHeight == metrics.pillHeight)

        #expect(SplitPaneChrome.gutter >= 8)
        #expect(SplitPaneChrome.gutter <= 12)
        #expect(SplitPaneChrome.containerCornerRadius > SplitPaneChrome.gutter)
        let canvas = SplitPaneChrome.insets(axis: .horizontal, isPrimary: true)
        let inspector = SplitPaneChrome.insets(axis: .horizontal, isPrimary: false)
        #expect(canvas.trailing + inspector.leading == SplitPaneChrome.gutter)
        #expect(canvas.leading == SplitPaneChrome.gutter)
        #expect(inspector.trailing == SplitPaneChrome.gutter)
        #expect(canvas.top == SplitPaneChrome.gutter)
        #expect(canvas.bottom == SplitPaneChrome.gutter)
        let upper = SplitPaneChrome.insets(axis: .vertical, isPrimary: true)
        let lower = SplitPaneChrome.insets(axis: .vertical, isPrimary: false)
        #expect(upper.bottom + lower.top == SplitPaneChrome.gutter)
        #expect(upper.leading == SplitPaneChrome.gutter)
        #expect(lower.trailing == SplitPaneChrome.gutter)
        #expect(SplitPaneChrome.insets(axis: nil, isPrimary: true) == canvas)

        let fold = CanvasReservedArea(
            id: "fold",
            frame: CanvasRect(
                origin: CanvasPoint(x: 400, y: 0),
                size: CanvasSize(width: 20, height: 800)
            ),
            margins: .zero,
            isActive: true,
            kind: .division
        )
        #expect(InspectorDividerClearance.blockedByActiveDivision(
            splitX: 410,
            containerHeight: 800,
            reservedAreas: [fold]
        ))
        var flat = fold
        flat.isActive = false
        #expect(!InspectorDividerClearance.blockedByActiveDivision(
            splitX: 410,
            containerHeight: 800,
            reservedAreas: [flat]
        ))
        let occlusion = CanvasReservedArea(
            id: "camera",
            frame: fold.frame,
            margins: .zero,
            isActive: true,
            kind: .occlusion
        )
        #expect(!InspectorDividerClearance.blockedByActiveDivision(
            splitX: 410,
            containerHeight: 800,
            reservedAreas: [occlusion]
        ))
        #expect(!InspectorDividerClearance.blockedByActiveDivision(
            splitX: 100,
            containerHeight: 800,
            reservedAreas: [fold]
        ))
    }
}
