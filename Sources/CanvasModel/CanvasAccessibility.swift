import Foundation

/// How an element is announced and which custom actions it offers.
///
/// Views map these values onto VoiceOver. The canvas package does not import SwiftUI.
public enum CanvasAccessibilityRole: Equatable, Sendable {
    case none
    case member
    case primary
}

public enum CanvasAccessibilityAction: String, Equatable, CaseIterable, Sendable {
    case nudgeLeft
    case nudgeRight
    case nudgeUp
    case nudgeDown
    case increaseWidth
    case decreaseWidth
    case increaseHeight
    case decreaseHeight
    case duplicate
    case delete
    case addToSelection
    case removeFromSelection
    case group
    case ungroup
    case editText
    case showInspector

    public var title: String {
        switch self {
        case .nudgeLeft: "Nudge Left"
        case .nudgeRight: "Nudge Right"
        case .nudgeUp: "Nudge Up"
        case .nudgeDown: "Nudge Down"
        case .increaseWidth: "Increase Width"
        case .decreaseWidth: "Decrease Width"
        case .increaseHeight: "Increase Height"
        case .decreaseHeight: "Decrease Height"
        case .duplicate: "Duplicate"
        case .delete: "Delete"
        case .addToSelection: "Add to Selection"
        case .removeFromSelection: "Remove from Selection"
        case .group: "Group"
        case .ungroup: "Ungroup"
        case .editText: "Edit Text"
        case .showInspector: "Show Inspector"
        }
    }
}

/// What the view already knows about the selection. The action list is derived from this.
public struct CanvasAccessibilityContext: Equatable, Sendable {
    public var role: CanvasAccessibilityRole
    public var isText: Bool
    public var isGroupedChild: Bool
    public var inlineEditing: Bool
    public var canDuplicate: Bool
    public var canGroup: Bool
    public var canUngroup: Bool
    public var inspectorIsSheet: Bool

    public init(
        role: CanvasAccessibilityRole,
        isText: Bool,
        isGroupedChild: Bool,
        inlineEditing: Bool,
        canDuplicate: Bool,
        canGroup: Bool,
        canUngroup: Bool,
        inspectorIsSheet: Bool
    ) {
        self.role = role
        self.isText = isText
        self.isGroupedChild = isGroupedChild
        self.inlineEditing = inlineEditing
        self.canDuplicate = canDuplicate
        self.canGroup = canGroup
        self.canUngroup = canUngroup
        self.inspectorIsSheet = inspectorIsSheet
    }
}

public struct CanvasAccessibilitySpeech: Equatable, Sendable {
    public var label: String
    public var value: String
    public var hint: String

    public init(label: String, value: String, hint: String) {
        self.label = label
        self.value = value
        self.hint = hint
    }
}

/// One rotor row. `id` matches the element view so VoiceOver can move to it.
public struct CanvasRotorEntry: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var label: String
    public var isText: Bool

    public init(id: UUID, label: String, isText: Bool) {
        self.id = id
        self.label = label
        self.isText = isText
    }
}

/// Selection chrome that stays legible under Increase Contrast and Differentiate Without Color.
///
/// The outline width is in points. Handles keep a separate stroke and glyph size; their hit box
/// stays `CanvasAccessibility.minimumHitTarget`.
public struct SelectionIndicatorStyle: Equatable, Sendable {
    public var lineWidth: Double
    public var usesHighContrastColor: Bool
    /// A second stroke, so the selection is not carried by colour alone.
    public var drawsShapeCue: Bool
    public var handleLineWidth: Double
    public var resizeGlyph: Double
    public var rotateGlyph: Double

    public init(
        lineWidth: Double,
        usesHighContrastColor: Bool,
        drawsShapeCue: Bool,
        handleLineWidth: Double,
        resizeGlyph: Double,
        rotateGlyph: Double
    ) {
        self.lineWidth = lineWidth
        self.usesHighContrastColor = usesHighContrastColor
        self.drawsShapeCue = drawsShapeCue
        self.handleLineWidth = handleLineWidth
        self.resizeGlyph = resizeGlyph
        self.rotateGlyph = rotateGlyph
    }

    public static func resolve(
        increasedContrast: Bool,
        differentiateWithoutColor: Bool,
        crossesReservedArea: Bool
    ) -> SelectionIndicatorStyle {
        let emphasized = increasedContrast || differentiateWithoutColor
        let base = emphasized ? 3.0 : 2.0
        return SelectionIndicatorStyle(
            lineWidth: crossesReservedArea ? base + 1 : base,
            usesHighContrastColor: emphasized,
            drawsShapeCue: differentiateWithoutColor,
            handleLineWidth: emphasized ? 2 : 1,
            resizeGlyph: emphasized ? 11 : 8,
            rotateGlyph: emphasized ? 13 : 10
        )
    }
}

/// Inspector and home chrome. Canvas artwork does not use this.
public struct AccessibilityChrome: Equatable, Sendable {
    /// Numeric rows stack so the field and stepper are not squeezed onto one line.
    public var stacksFields: Bool
    /// Segmented controls become menus so their labels are not clipped.
    public var usesMenuPicker: Bool

    public init(stacksFields: Bool, usesMenuPicker: Bool) {
        self.stacksFields = stacksFields
        self.usesMenuPicker = usesMenuPicker
    }

    public static func resolve(isAccessibilitySize: Bool) -> AccessibilityChrome {
        AccessibilityChrome(
            stacksFields: isAccessibilitySize,
            usesMenuPicker: isAccessibilitySize
        )
    }
}

public enum MotionPolicy {
    /// App-owned transitions stop when Reduce Motion is on. System sheets already do the same.
    public static func disablesAnimations(reduceMotion: Bool) -> Bool {
        reduceMotion
    }

    /// Home opens the canvas with the system zoom transition only when motion is allowed.
    /// Reduce Motion keeps the ordinary navigation change, which the app then shows without animation.
    public static func usesZoomTransition(reduceMotion: Bool) -> Bool {
        !reduceMotion
    }
}

public enum CanvasAccessibility {
    /// Matches the arrow-key nudge, in canvas points. Y increases downward.
    public static let nudgeStep: Double = 1
    /// VoiceOver resize step, in canvas points. Larger than a nudge so the change is perceptible.
    public static let resizeStep: Double = 8
    /// Minimum control size, in points. Selection-handle hit boxes use this.
    public static let minimumHitTarget: Double = 44

    public static let canvasLabel = "Canvas"
    public static let canvasHint = "Front to back. Select an element, then use its actions to move or resize."
    public static let clearSelectionAction = "Clear Selection"
    public static let inlineTextLabel = "Canvas text"
    public static let inlineTextHint = "Return commits the text. Escape cancels."

    public static func speech(
        for element: CanvasElement,
        role: CanvasAccessibilityRole,
        isGroupedChild: Bool,
        imageUnavailable: Bool = false
    ) -> CanvasAccessibilitySpeech {
        CanvasAccessibilitySpeech(
            label: spokenLabel(
                for: element,
                isGroupedChild: isGroupedChild,
                imageUnavailable: imageUnavailable
            ),
            value: spokenValue(role: role),
            hint: spokenHint(role: role, isGroupedChild: isGroupedChild)
        )
    }

    public static func spokenLabel(
        for element: CanvasElement,
        isGroupedChild: Bool,
        imageUnavailable: Bool = false
    ) -> String {
        var parts = [element.type.displayName]
        if element.type == .text, let string = element.text?.string, !string.isEmpty {
            parts.append(string)
        }
        if element.type == .group {
            let count = element.childIDs.count
            parts.append(count == 1 ? "1 member" : "\(count) members")
        }
        parts.append(
            "\(CanvasFormatting.number(abs(element.size.width))) by \(CanvasFormatting.number(abs(element.size.height))) points"
        )
        parts.append(
            "at \(CanvasFormatting.number(element.position.x)), \(CanvasFormatting.number(element.position.y))"
        )
        if element.rotation.degrees != 0 {
            parts.append("rotated \(CanvasFormatting.number(element.rotation.degrees)) degrees")
        }
        if imageUnavailable {
            parts.append("image unavailable")
        }
        if isGroupedChild {
            parts.append("inside a group")
        }
        return parts.joined(separator: ", ")
    }

    public static func spokenValue(role: CanvasAccessibilityRole) -> String {
        switch role {
        case .none: ""
        case .member: "Selected"
        case .primary: "Primary"
        }
    }

    public static func spokenHint(role: CanvasAccessibilityRole, isGroupedChild: Bool) -> String {
        if isGroupedChild, role == .none {
            return "Selects the group."
        }
        switch role {
        case .none:
            return "Selects this element."
        case .member, .primary:
            return "Moves or deletes the selection. Resizes this element."
        }
    }

    /// Move, resize, and delete are offered on a selected element. A grouped child that is not
    /// itself selected only has the default action, which selects its group.
    public static func actions(for context: CanvasAccessibilityContext) -> [CanvasAccessibilityAction] {
        if context.inlineEditing { return [] }
        if context.isGroupedChild, context.role == .none { return [] }

        var actions: [CanvasAccessibilityAction] = []
        let selected = context.role != .none
        if selected {
            actions.append(contentsOf: [.nudgeLeft, .nudgeRight, .nudgeUp, .nudgeDown])
            actions.append(contentsOf: [.increaseWidth, .decreaseWidth, .increaseHeight, .decreaseHeight])
            actions.append(.delete)
        }
        if context.canDuplicate {
            actions.append(.duplicate)
        }
        if context.role == .none {
            actions.append(.addToSelection)
        } else {
            actions.append(.removeFromSelection)
        }
        if context.role == .primary, context.canGroup {
            actions.append(.group)
        }
        if context.role == .primary, context.canUngroup {
            actions.append(.ungroup)
        }
        if context.role == .primary, context.isText {
            actions.append(.editText)
        }
        if context.role == .primary, context.inspectorIsSheet {
            actions.append(.showInspector)
        }
        return actions
    }

    public static func nudgeDelta(for action: CanvasAccessibilityAction) -> CanvasPoint? {
        switch action {
        case .nudgeLeft: CanvasPoint(x: -nudgeStep, y: 0)
        case .nudgeRight: CanvasPoint(x: nudgeStep, y: 0)
        case .nudgeUp: CanvasPoint(x: 0, y: -nudgeStep)
        case .nudgeDown: CanvasPoint(x: 0, y: nudgeStep)
        default: nil
        }
    }

    public static func resized(_ size: CanvasSize, by action: CanvasAccessibilityAction) -> CanvasSize? {
        switch action {
        case .increaseWidth:
            CanvasSize(width: size.width + resizeStep, height: size.height)
        case .decreaseWidth:
            CanvasSize(width: size.width - resizeStep, height: size.height)
        case .increaseHeight:
            CanvasSize(width: size.width, height: size.height + resizeStep)
        case .decreaseHeight:
            CanvasSize(width: size.width, height: size.height - resizeStep)
        default:
            nil
        }
    }

    /// Front to back. `elements` is the document order, which is back to front.
    public static func rotorEntries(in elements: [CanvasElement]) -> [CanvasRotorEntry] {
        elements.reversed().map { element in
            CanvasRotorEntry(
                id: element.id,
                label: spokenLabel(for: element, isGroupedChild: element.parentID != nil),
                isText: element.type == .text
            )
        }
    }

    /// Higher values are visited first. A larger z-index is in front.
    public static func sortPriority(zIndex: Int) -> Double {
        Double(zIndex)
    }

    /// Every drawn element, including grouped children, because each one is in the VoiceOver order.
    public static func canvasValue(elements: [CanvasElement]) -> String {
        switch elements.count {
        case 0: "Empty"
        case 1: "1 element"
        default: "\(elements.count) elements"
        }
    }
}
