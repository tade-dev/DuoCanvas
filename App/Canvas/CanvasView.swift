import AdaptiveLayout
import CanvasModel
import SwiftUI
import UIKit

/// The page, fitted to the pane. This view takes a plain layout context and does not
/// read device pose itself.
struct CanvasView: View {
    @Bindable var editor: EditorModel
    var layoutContext: CanvasLayoutContext

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Namespace private var canvasRotor
    @FocusState private var canvasFocused: Bool
    @GestureState private var moveGestureActive = false
    @State private var pointer: PointerSession?
    @State private var shiftHeld = false

    var body: some View {
        GeometryReader { geometry in
            let artboard = editor.document.canvasConfig.size
            let scale = fitScale(artboard: artboard, in: geometry.size)
            let fitted = CGSize(
                width: artboard.width * scale,
                height: artboard.height * scale
            )
            let origin = artboardOrigin(pane: geometry.size, fitted: fitted)
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        canvasFocused = true
                        editor.select(nil)
                    }
                ZStack(alignment: .topLeading) {
                    artboardContent(scale: scale, origin: origin)
                        .contentShape(Rectangle())
                        .gesture(pageGesture(scale: scale, artboardOrigin: origin))
                    // In front of the page gesture, so a drag cannot take the caret.
                    if let editing = inlineEditingElement {
                        CanvasInlineTextField(
                            element: editing,
                            scale: scale,
                            indicator: selectionIndicator(
                                for: editing,
                                scale: scale,
                                artboardOrigin: origin
                            ),
                            draft: $editor.inlineTextDraft,
                            onFinish: { commit in
                                if commit {
                                    editor.commitInlineTextEdit()
                                } else {
                                    editor.cancelInlineTextEdit()
                                }
                                canvasFocused = true
                            }
                        )
                        .position(center(of: editing, scale: scale))
                    }
                }
                .coordinateSpace(name: ArtboardCoordinate.name)
                .frame(width: fitted.width, height: fitted.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(CanvasAccessibility.canvasLabel)
        .accessibilityValue(CanvasAccessibility.canvasValue(elements: editor.document.orderedElements))
        .accessibilityHint(CanvasAccessibility.canvasHint)
        .modifier(OptionalAccessibilityAction(
            name: CanvasAccessibility.clearSelectionAction,
            perform: editor.primarySelection == nil || editor.isEditingTextInline
                ? nil
                : { editor.select(nil) }
        ))
        .accessibilityRotor("Elements") {
            ForEach(rotorEntries) { entry in
                AccessibilityRotorEntry(entry.label, entry.id, in: canvasRotor)
            }
        }
        .modifier(TextElementsRotor(entries: rotorEntries.filter(\.isText), namespace: canvasRotor))
        // focusSection() is macOS and tvOS only. The canvas takes hardware-key focus itself.
        .focusable()
        .focused($canvasFocused)
        .focusedValue(\.canvasEditActions, CanvasEditActions(
            canDuplicate: editor.canDuplicate && !editor.isEditingTextInline,
            duplicate: { editor.duplicateSelection() }
        ))
        .modifier(CanvasClipboardModifier(
            clipboard: editor.makeClipboard(),
            onPaste: { received in
                guard !editor.isEditingTextInline else { return }
                editor.paste(received)
            }
        ))
        .onDeleteCommand(perform: editor.isEditingTextInline ? nil : { editor.deleteSelection() })
        .onKeyPress(phases: [.down, .up]) { press in
            shiftHeld = press.modifiers.contains(.shift)
            if editor.isEditingTextInline {
                if press.key == .escape, press.phase == .down {
                    editor.cancelInlineTextEdit()
                    canvasFocused = true
                    return .handled
                }
                return .ignored
            }
            guard press.phase == .down else { return .ignored }
            switch press.key {
            case .upArrow:
                editor.nudgeSelection(dx: 0, dy: -1)
            case .downArrow:
                editor.nudgeSelection(dx: 0, dy: 1)
            case .leftArrow:
                editor.nudgeSelection(dx: -1, dy: 0)
            case .rightArrow:
                editor.nudgeSelection(dx: 1, dy: 0)
            case .deleteForward:
                editor.deleteSelection()
            default:
                return .ignored
            }
            return .handled
        }
        .onAppear { canvasFocused = true }
        .onChange(of: moveGestureActive) { _, active in
            if !active {
                editor.noteCanvasGestureEnded()
                closePointer()
            }
        }
    }

    private var inlineEditingElement: CanvasElement? {
        guard let id = editor.inlineTextEditingID else { return nil }
        return editor.document.element(id)
    }

    private func artboardContent(scale: Double, origin: CGPoint) -> some View {
        ZStack(alignment: .topLeading) {
            artboardBackground
                .frame(
                    width: editor.document.canvasConfig.size.width * scale,
                    height: editor.document.canvasConfig.size.height * scale
                )
            ForEach(Array(editor.document.orderedElements.enumerated()), id: \.element.id) { index, element in
                let role = selectionRole(of: element.id)
                CanvasElementView(
                    element: element,
                    scale: scale,
                    imageData: imageData(for: element),
                    role: role,
                    indicator: selectionIndicator(
                        for: element,
                        scale: scale,
                        artboardOrigin: origin
                    ),
                    accessibilityContext: accessibilityContext(for: element, role: role),
                    rotorNamespace: canvasRotor,
                    sortPriority: CanvasAccessibility.sortPriority(zIndex: index),
                    suppressesString: editor.inlineTextEditingID == element.id,
                    onSelect: {
                        let root = CanvasStructure.selectionRoot(of: element.id, in: editor.document.elements)
                        editor.select(root)
                    },
                    onAction: { action in
                        performAccessibilityAction(action, on: element)
                    }
                )
                .position(center(of: element, scale: scale))
            }
            if let selected = editor.selectedElement, editor.inlineTextEditingID == nil {
                SelectionOverlay(
                    element: selected,
                    scale: scale,
                    placements: handlePlacements(
                        for: selected,
                        scale: scale,
                        artboardOrigin: origin
                    )
                )
                .position(center(of: selected, scale: scale))
            }
        }
        .dynamicTypeSize(.large)
    }

    private var artboardBackground: some View {
        Rectangle()
            .fill(editor.document.canvasConfig.background.swiftUIColor)
            .overlay {
                Rectangle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            }
    }

    private func pageGesture(scale: Double, artboardOrigin: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(ArtboardCoordinate.name))
            .updating($moveGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                var session = session(for: value, scale: scale, artboardOrigin: artboardOrigin)
                if editor.isEditingTextInline {
                    let onEditingBody = session.contact.onBody
                        && session.contact.elementID == editor.inlineTextEditingID
                    if onEditingBody {
                        session.phase = .ignore
                        pointer = session
                        return
                    }
                    editor.commitInlineTextEdit()
                    session.contact = contact(
                        at: value.startLocation,
                        scale: scale,
                        artboardOrigin: artboardOrigin
                    )
                    pointer = session
                }
                canvasFocused = true
                if session.phase == .pending {
                    session.phase = CanvasPointerRouting.intent(
                        elapsed: value.time.timeIntervalSince(session.startedAt),
                        distance: distance(value.translation),
                        onBody: session.contact.onBody,
                        handleOutsideBody: session.contact.handleOutsideBody
                    )
                    pointer = session
                }
                apply(session, value: value, scale: scale)
            }
            .onEnded { value in
                let traveled = distance(value.translation)
                if var session = pointer, session.startLocation == value.startLocation {
                    if session.phase == .pending, traveled >= CanvasPointerRouting.dragSlop {
                        session.phase = CanvasPointerRouting.intent(
                            elapsed: value.time.timeIntervalSince(session.startedAt),
                            distance: traveled,
                            onBody: session.contact.onBody,
                            handleOutsideBody: session.contact.handleOutsideBody
                        )
                    }
                    apply(session, value: value, scale: scale)
                }
                let hit = pointer?.contact ?? contact(
                    at: value.startLocation,
                    scale: scale,
                    artboardOrigin: artboardOrigin
                )
                // A stationary second tap edits, including one that outlasted the move hold.
                // A drag that actually moved still commits as a move.
                if traveled < CanvasPointerRouting.dragSlop,
                   CanvasTextEditRouting.shouldBeginInlineEdit(
                       elementType: hit.elementID.flatMap { editor.document.element($0)?.type },
                       hitID: hit.elementID,
                       primarySelection: editor.primarySelection,
                       additive: shiftHeld,
                       onBody: hit.onBody
                   ) {
                    editor.cancelStationaryMove()
                }
                let edited = editor.activeMoveID != nil || editor.isAdjustingWithHandle
                editor.endMove()
                editor.endResize()
                editor.endRotate()
                if !edited, traveled < CanvasPointerRouting.dragSlop {
                    let onEditingBody = editor.isEditingTextInline
                        && hit.onBody
                        && hit.elementID == editor.inlineTextEditingID
                    if !onEditingBody {
                        select(for: hit, additive: shiftHeld)
                    }
                }
                closePointer()
            }
    }

    private func closePointer() {
        guard var session = pointer, !session.closed else { return }
        session.closed = true
        pointer = session
    }

    /// The press recorded at the finger-down point. A later event keeps that choice.
    private func session(for value: DragGesture.Value, scale: Double, artboardOrigin: CGPoint) -> PointerSession {
        if let pointer, !pointer.closed, pointer.startLocation == value.startLocation {
            return pointer
        }
        let session = PointerSession(
            startedAt: value.time,
            startLocation: value.startLocation,
            contact: contact(at: value.startLocation, scale: scale, artboardOrigin: artboardOrigin),
            phase: .pending,
            closed: false
        )
        pointer = session
        return session
    }

    private func apply(_ session: PointerSession, value: DragGesture.Value, scale: Double) {
        switch session.phase {
        case .pending, .ignore:
            return
        case .move:
            guard let id = session.contact.elementID else { return }
            editor.previewMove(
                of: id,
                translationX: Double(value.translation.width),
                translationY: Double(value.translation.height),
                scale: scale
            )
        case .resize(let handle):
            guard let id = session.contact.elementID else { return }
            editor.previewResize(
                of: id,
                handle: handle,
                artboardTranslationX: Double(value.translation.width),
                artboardTranslationY: Double(value.translation.height),
                scale: scale
            )
        case .rotate:
            guard let id = session.contact.elementID else { return }
            editor.previewRotate(
                of: id,
                canvasPoint: CanvasPoint(
                    x: Double(value.location.x) / scale,
                    y: Double(value.location.y) / scale
                )
            )
        }
    }

    private func select(for contact: PointerContact, additive: Bool) {
        if contact.onBody, let id = contact.elementID {
            if CanvasTextEditRouting.shouldBeginInlineEdit(
                elementType: editor.document.element(id)?.type,
                hitID: id,
                primarySelection: editor.primarySelection,
                additive: additive,
                onBody: contact.onBody
            ) {
                editor.beginInlineTextEdit(id)
                canvasFocused = false
                return
            }
            canvasFocused = true
            if additive {
                editor.toggleSelection(id)
            } else {
                editor.select(id)
            }
        } else if contact.handleOutsideBody == nil, !additive {
            canvasFocused = true
            editor.select(nil)
        }
    }

    private func selectionRole(of id: CanvasElement.ID) -> ElementSelectionRole {
        if editor.primarySelection == id { return .primary }
        if editor.selectedIDs.contains(id) { return .member }
        return .none
    }

    /// Body wins over a handle box that covers it. A handle only wins outside that body.
    ///
    /// Shift-tap skips that preference so a second element can join the selection.
    /// A hit on a grouped child selects the outermost group.
    private func contact(at point: CGPoint, scale: Double, artboardOrigin: CGPoint) -> PointerContact {
        if editor.inlineTextEditingID != nil {
            if let id = elementID(at: point, scale: scale) {
                if id == editor.inlineTextEditingID {
                    return PointerContact(onBody: true, elementID: id, handleOutsideBody: nil)
                }
                let root = CanvasStructure.selectionRoot(of: id, in: editor.document.elements)
                return PointerContact(onBody: true, elementID: root, handleOutsideBody: nil)
            }
            return PointerContact(onBody: false, elementID: nil, handleOutsideBody: nil)
        }
        if !shiftHeld, let selected = editor.selectedElement, bodyContains(selected, point: point, scale: scale) {
            return PointerContact(onBody: true, elementID: selected.id, handleOutsideBody: nil)
        }
        if !shiftHeld,
           let handle = selectionHandle(at: point, scale: scale, artboardOrigin: artboardOrigin),
           let selected = editor.selectedElement {
            return PointerContact(onBody: false, elementID: selected.id, handleOutsideBody: handle)
        }
        if let id = elementID(at: point, scale: scale) {
            let root = CanvasStructure.selectionRoot(of: id, in: editor.document.elements)
            return PointerContact(onBody: true, elementID: root, handleOutsideBody: nil)
        }
        return PointerContact(onBody: false, elementID: nil, handleOutsideBody: nil)
    }

    private func imageData(for element: CanvasElement) -> Data? {
        guard let id = element.image?.id else { return nil }
        return editor.imageStore.data(for: id)
    }

    private func handlePlacements(
        for element: CanvasElement,
        scale: Double,
        artboardOrigin: CGPoint
    ) -> [SelectionHandlePlacement] {
        let box = CanvasRect(origin: element.position, size: element.size).standardized
        let paneOrigin = CanvasPoint(
            x: Double(artboardOrigin.x) + box.origin.x * scale,
            y: Double(artboardOrigin.y) + box.origin.y * scale
        )
        return SelectionHandleLayout.placements(
            localSize: CanvasSize(width: box.size.width * scale, height: box.size.height * scale),
            rotationDegrees: element.rotation.degrees,
            paneOrigin: paneOrigin,
            reservedAreas: layoutContext.reservedAreas
        )
    }

    private func selectionHandle(
        at point: CGPoint,
        scale: Double,
        artboardOrigin: CGPoint
    ) -> SelectionHandle? {
        guard let element = editor.selectedElement else { return nil }
        let box = CanvasRect(origin: element.position, size: element.size).standardized
        let visualWidth = box.size.width * scale
        let visualHeight = box.size.height * scale
        let center = center(of: element, scale: scale)
        let local = SelectionGeometry.localPoint(
            artboardX: Double(point.x),
            artboardY: Double(point.y),
            centerX: Double(center.x),
            centerY: Double(center.y),
            rotationDegrees: element.rotation.degrees,
            visualWidth: visualWidth,
            visualHeight: visualHeight
        )
        let placements = handlePlacements(for: element, scale: scale, artboardOrigin: artboardOrigin)
        let centers = Dictionary(uniqueKeysWithValues: placements.map { ($0.handle, $0.center) })
        return SelectionHandleLayout.hitHandle(at: local, centers: centers)
    }

    private func bodyContains(_ element: CanvasElement, point: CGPoint, scale: Double) -> Bool {
        let rect = CanvasRect(
            origin: CanvasPoint(x: element.position.x * scale, y: element.position.y * scale),
            size: CanvasSize(width: element.size.width * scale, height: element.size.height * scale)
        )
        let location = CanvasPoint(x: point.x, y: point.y)
        return rect.standardized.intersects(CanvasRect(origin: location, size: .zero))
    }

    private func elementID(at point: CGPoint, scale: Double) -> CanvasElement.ID? {
        let location = CanvasPoint(x: point.x, y: point.y)
        for element in editor.document.orderedElements.reversed() {
            let rect = CanvasRect(
                origin: CanvasPoint(x: element.position.x * scale, y: element.position.y * scale),
                size: CanvasSize(width: element.size.width * scale, height: element.size.height * scale)
            )
            if rect.standardized.intersects(CanvasRect(origin: location, size: .zero)) {
                return element.id
            }
        }
        return nil
    }

    private func distance(_ translation: CGSize) -> Double {
        let x = Double(translation.width)
        let y = Double(translation.height)
        return (x * x + y * y).squareRoot()
    }

    private func fitScale(artboard: CanvasSize, in pane: CGSize) -> Double {
        guard artboard.width > 0, artboard.height > 0, pane.width > 1, pane.height > 1 else {
            return 1
        }
        return min(Double(pane.width) / artboard.width, Double(pane.height) / artboard.height)
    }

    private func artboardOrigin(pane: CGSize, fitted: CGSize) -> CGPoint {
        CGPoint(
            x: max(0, (pane.width - fitted.width) / 2),
            y: max(0, (pane.height - fitted.height) / 2)
        )
    }

    private func center(of element: CanvasElement, scale: Double) -> CGPoint {
        CGPoint(
            x: (element.position.x + element.size.width / 2) * scale,
            y: (element.position.y + element.size.height / 2) * scale
        )
    }

    /// The element's unrotated frame, in the same space as `layoutContext.reservedAreas`.
    private func selectionIndicator(
        for element: CanvasElement,
        scale: Double,
        artboardOrigin: CGPoint
    ) -> SelectionIndicatorStyle {
        let rect = CanvasRect(
            origin: CanvasPoint(
                x: Double(artboardOrigin.x) + element.position.x * scale,
                y: Double(artboardOrigin.y) + element.position.y * scale
            ),
            size: CanvasSize(width: element.size.width * scale, height: element.size.height * scale)
        )
        let crossesReservedArea = layoutContext.reservedAreas.contains { area in
            area.isActive && area.frame.intersects(rect)
        }
        return SelectionIndicatorStyle.resolve(
            increasedContrast: contrast == .increased,
            differentiateWithoutColor: differentiateWithoutColor,
            crossesReservedArea: crossesReservedArea
        )
    }

    private var inspectorIsSheet: Bool {
        EditorArrangement.forHorizontalSizeClass(CanvasSizeClass(horizontalSizeClass)) == .sheet
    }

    private var rotorEntries: [CanvasRotorEntry] {
        let visible = editor.document.orderedElements.filter { $0.id != editor.inlineTextEditingID }
        return CanvasAccessibility.rotorEntries(in: visible)
    }

    private func accessibilityContext(
        for element: CanvasElement,
        role: ElementSelectionRole
    ) -> CanvasAccessibilityContext {
        CanvasAccessibilityContext(
            role: accessibilityRole(role),
            isText: element.type == .text,
            isGroupedChild: element.parentID != nil,
            inlineEditing: editor.isEditingTextInline,
            canDuplicate: true,
            canGroup: editor.canGroup,
            canUngroup: editor.canUngroup,
            inspectorIsSheet: inspectorIsSheet
        )
    }

    private func accessibilityRole(_ role: ElementSelectionRole) -> CanvasAccessibilityRole {
        switch role {
        case .none: .none
        case .member: .member
        case .primary: .primary
        }
    }

    /// Custom VoiceOver actions go through the same commands as the keyboard and the inspector.
    private func performAccessibilityAction(_ action: CanvasAccessibilityAction, on element: CanvasElement) {
        switch action {
        case .nudgeLeft, .nudgeRight, .nudgeUp, .nudgeDown:
            guard let delta = CanvasAccessibility.nudgeDelta(for: action) else { return }
            editor.nudgeSelection(dx: delta.x, dy: delta.y)
        case .increaseWidth, .decreaseWidth, .increaseHeight, .decreaseHeight:
            guard let size = CanvasAccessibility.resized(element.size, by: action) else { return }
            if size.width != element.size.width {
                editor.setWidth(size.width, for: element.id)
            }
            if size.height != element.size.height {
                editor.setHeight(size.height, for: element.id)
            }
        case .duplicate:
            editor.duplicateElement(element.id)
        case .delete:
            editor.deleteSelection()
        case .addToSelection, .removeFromSelection:
            let root = CanvasStructure.selectionRoot(of: element.id, in: editor.document.elements)
            editor.toggleSelection(root)
        case .group:
            editor.groupSelection()
        case .ungroup:
            editor.ungroupSelection()
        case .editText:
            editor.beginInlineTextEdit(element.id)
        case .showInspector:
            editor.inspectorPresented = true
        }
    }
}

/// One press on the page. `phase` stays at the first choice that is not pending.
private struct PointerSession {
    var startedAt: Date
    var startLocation: CGPoint
    var contact: PointerContact
    var phase: CanvasPointerIntent
    var closed: Bool
}

/// Where the finger went down. The body and a protruding handle are never both set.
private struct PointerContact {
    var onBody: Bool
    var elementID: CanvasElement.ID?
    var handleOutsideBody: SelectionHandle?
}
