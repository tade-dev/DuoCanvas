import CanvasModel
import Foundation
import Testing

@Suite("Accessibility")
struct AccessibilityTests {
    @Test func rectangleLabelIncludesTypeSizeAndPosition() {
        let element = CanvasElement.rectangle(
            position: CanvasPoint(x: 40, y: 60),
            size: CanvasSize(width: 120, height: 80)
        )
        let speech = CanvasAccessibility.speech(for: element, role: .none, isGroupedChild: false)
        #expect(speech.label == "Rectangle, \(CanvasFormatting.number(120)) by \(CanvasFormatting.number(80)) points, at \(CanvasFormatting.number(40)), \(CanvasFormatting.number(60))")
        #expect(speech.value == "")
        #expect(speech.hint == "Selects this element.")
    }

    @Test func textLabelIncludesTheStringAndSkipsAnEmptyString() {
        let hello = CanvasElement.text("Hello", position: CanvasPoint(x: 1, y: 2))
        #expect(CanvasAccessibility.spokenLabel(for: hello, isGroupedChild: false).hasPrefix("Text, Hello, "))

        var empty = CanvasElement.text("")
        empty.text?.string = ""
        #expect(!CanvasAccessibility.spokenLabel(for: empty, isGroupedChild: false).contains(", ,"))
        #expect(CanvasAccessibility.spokenLabel(for: empty, isGroupedChild: false).hasPrefix("Text, "))
    }

    @Test func rotationAndGroupMembershipAreSpokenWhenTheyMatter() {
        var turned = CanvasElement.rectangle(size: CanvasSize(width: 10, height: 10))
        turned.rotation = CanvasRotation(degrees: 15)
        #expect(CanvasAccessibility.spokenLabel(for: turned, isGroupedChild: false).contains("rotated \(CanvasFormatting.number(15)) degrees"))

        let group = CanvasElement.group(childIDs: [UUID(), UUID()])
        #expect(CanvasAccessibility.spokenLabel(for: group, isGroupedChild: false).contains("2 members"))
        let single = CanvasElement.group(childIDs: [UUID()])
        #expect(CanvasAccessibility.spokenLabel(for: single, isGroupedChild: false).contains("1 member"))

        var child = CanvasElement.text("Inside")
        child.parentID = UUID()
        #expect(CanvasAccessibility.spokenLabel(for: child, isGroupedChild: true).hasSuffix("inside a group"))
        #expect(CanvasAccessibility.spokenHint(role: .none, isGroupedChild: true) == "Selects the group.")
    }

    @Test func selectedValuesAndHints() {
        #expect(CanvasAccessibility.spokenValue(role: .member) == "Selected")
        #expect(CanvasAccessibility.spokenValue(role: .primary) == "Primary")
        #expect(
            CanvasAccessibility.spokenHint(role: .primary, isGroupedChild: false)
                == "Moves or deletes the selection. Resizes this element."
        )
    }

    @Test func unselectedElementCanBeAddedButNotMoved() {
        let actions = CanvasAccessibility.actions(for: context(role: .none))
        #expect(actions == [.duplicate, .addToSelection])
        #expect(!actions.contains(.delete))
        #expect(!actions.contains(.nudgeLeft))
    }

    @Test func primaryTextOnASheetOffersMoveResizeDeleteAndInspector() {
        let actions = CanvasAccessibility.actions(for: context(
            role: .primary,
            isText: true,
            canGroup: true,
            inspectorIsSheet: true
        ))
        #expect(actions.contains(.nudgeUp))
        #expect(actions.contains(.increaseWidth))
        #expect(actions.contains(.decreaseHeight))
        #expect(actions.contains(.delete))
        #expect(actions.contains(.duplicate))
        #expect(actions.contains(.removeFromSelection))
        #expect(actions.contains(.group))
        #expect(actions.contains(.editText))
        #expect(actions.contains(.showInspector))
        #expect(!actions.contains(.ungroup))
        #expect(actions.map(\.title).contains("Nudge Left"))
        #expect(actions.map(\.title).contains("Show Inspector"))
    }

    @Test func memberOmitsPrimaryOnlyActions() {
        let actions = CanvasAccessibility.actions(for: context(
            role: .member,
            isText: true,
            canGroup: true,
            canUngroup: true,
            inspectorIsSheet: true
        ))
        #expect(actions.contains(.nudgeRight))
        #expect(actions.contains(.delete))
        #expect(!actions.contains(.group))
        #expect(!actions.contains(.ungroup))
        #expect(!actions.contains(.editText))
        #expect(!actions.contains(.showInspector))
    }

    @Test func inlineEditingAndUnselectedGroupedChildrenHaveNoCustomActions() {
        #expect(CanvasAccessibility.actions(for: context(role: .primary, isText: true, inlineEditing: true)).isEmpty)
        #expect(CanvasAccessibility.actions(for: context(role: .none, isGroupedChild: true)).isEmpty)
        let selectedChild = CanvasAccessibility.actions(for: context(role: .primary, isGroupedChild: true))
        #expect(selectedChild.contains(.nudgeDown))
    }

    @Test func nudgeUpIsNegativeYAndResizeStepsOneAxis() {
        #expect(CanvasAccessibility.nudgeDelta(for: .nudgeUp) == CanvasPoint(x: 0, y: -1))
        #expect(CanvasAccessibility.nudgeDelta(for: .nudgeLeft) == CanvasPoint(x: -1, y: 0))
        #expect(CanvasAccessibility.nudgeDelta(for: .duplicate) == nil)
        let size = CanvasSize(width: 20, height: 30)
        #expect(CanvasAccessibility.resized(size, by: .increaseWidth) == CanvasSize(width: 28, height: 30))
        #expect(CanvasAccessibility.resized(size, by: .decreaseHeight) == CanvasSize(width: 20, height: 22))
        #expect(CanvasAccessibility.resized(size, by: .delete) == nil)
    }

    @Test func rotorListsFrontToBackAndTextSeparately() {
        let back = CanvasElement.rectangle()
        let text = CanvasElement.text("Title")
        let front = CanvasElement.circle()
        let entries = CanvasAccessibility.rotorEntries(in: [back, text, front])
        #expect(entries.map(\.id) == [front.id, text.id, back.id])
        #expect(entries.filter(\.isText).map(\.id) == [text.id])
        #expect(CanvasAccessibility.sortPriority(zIndex: 2) > CanvasAccessibility.sortPriority(zIndex: 0))
    }

    @Test func canvasValueCountsEveryDrawnElement() {
        #expect(CanvasAccessibility.canvasValue(elements: []) == "Empty")
        #expect(CanvasAccessibility.canvasValue(elements: [CanvasElement.rectangle()]) == "1 element")
        var child = CanvasElement.text("Child")
        child.parentID = UUID()
        let group = CanvasElement.group(childIDs: [child.id])
        #expect(CanvasAccessibility.canvasValue(elements: [child, group]) == "2 elements")
    }

    @Test func contrastAndDifferentiateWithoutColorChangeTheIndicator() {
        let plain = SelectionIndicatorStyle.resolve(
            increasedContrast: false,
            differentiateWithoutColor: false,
            crossesReservedArea: false
        )
        #expect(plain.lineWidth == 2)
        #expect(!plain.usesHighContrastColor)
        #expect(!plain.drawsShapeCue)
        #expect(plain.resizeGlyph == 8)
        #expect(plain.rotateGlyph == 10)

        let contrast = SelectionIndicatorStyle.resolve(
            increasedContrast: true,
            differentiateWithoutColor: false,
            crossesReservedArea: true
        )
        #expect(contrast.lineWidth == 4)
        #expect(contrast.usesHighContrastColor)
        #expect(!contrast.drawsShapeCue)
        #expect(contrast.handleLineWidth == 2)

        let withoutColor = SelectionIndicatorStyle.resolve(
            increasedContrast: false,
            differentiateWithoutColor: true,
            crossesReservedArea: false
        )
        #expect(withoutColor.lineWidth == 3)
        #expect(withoutColor.usesHighContrastColor)
        #expect(withoutColor.drawsShapeCue)
    }

    @Test func accessibilitySizesStackChromeAndReduceMotionStopsAnimation() {
        let regular = AccessibilityChrome.resolve(isAccessibilitySize: false)
        #expect(!regular.stacksFields)
        #expect(!regular.usesMenuPicker)
        let large = AccessibilityChrome.resolve(isAccessibilitySize: true)
        #expect(large.stacksFields)
        #expect(large.usesMenuPicker)
        #expect(!MotionPolicy.disablesAnimations(reduceMotion: false))
        #expect(MotionPolicy.disablesAnimations(reduceMotion: true))
    }

    @Test func handleHitTargetMeetsTheMinimum() {
        #expect(CanvasAccessibility.minimumHitTarget == 44)
        #expect(SelectionHandleLayout.hitExtent >= CanvasAccessibility.minimumHitTarget)
    }

    @Test func backgroundNamesAndDisplayNames() {
        #expect(CanvasFormatting.backgroundDescription(.white) == "White")
        #expect(CanvasFormatting.backgroundDescription(.black) == "Black")
        #expect(CanvasFormatting.backgroundDescription(.clear) == "Clear")
        let custom = CanvasColor(red: 0.5, green: 0, blue: 1, alpha: 1)
        #expect(CanvasFormatting.backgroundDescription(custom).contains(CanvasFormatting.number(0.5)))
        #expect(CanvasElementType.roundedRectangle.displayName == "Rounded rectangle")
        #expect(CanvasElementType.allCases.map(\.displayName).count == CanvasElementType.allCases.count)
    }

    private func context(
        role: CanvasAccessibilityRole,
        isText: Bool = false,
        isGroupedChild: Bool = false,
        inlineEditing: Bool = false,
        canDuplicate: Bool = true,
        canGroup: Bool = false,
        canUngroup: Bool = false,
        inspectorIsSheet: Bool = false
    ) -> CanvasAccessibilityContext {
        CanvasAccessibilityContext(
            role: role,
            isText: isText,
            isGroupedChild: isGroupedChild,
            inlineEditing: inlineEditing,
            canDuplicate: canDuplicate,
            canGroup: canGroup,
            canUngroup: canUngroup,
            inspectorIsSheet: inspectorIsSheet
        )
    }
}
