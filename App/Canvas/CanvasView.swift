import CanvasModel
import SwiftUI
import UIKit

/// The page, fitted to the pane. This view takes a plain layout context and does not
/// read device pose itself.
struct CanvasView: View {
    var editor: EditorModel
    var layoutContext: CanvasLayoutContext

    @Environment(\.colorSchemeContrast) private var contrast
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
                    artboardBackground
                        .frame(width: fitted.width, height: fitted.height)
                    ForEach(editor.document.orderedElements) { element in
                        let role = selectionRole(of: element.id)
                        CanvasElementView(
                            element: element,
                            scale: scale,
                            imageData: imageData(for: element),
                            role: role,
                            selectionLineWidth: selectionLineWidth(
                                for: element,
                                scale: scale,
                                artboardOrigin: origin
                            ),
                            onSelect: { editor.select(element.id) },
                            onDuplicate: { editor.duplicateElement(element.id) },
                            onToggleSelection: { editor.toggleSelection(element.id) },
                            onGroup: role == .primary && editor.canGroup ? { editor.groupSelection() } : nil,
                            onUngroup: role == .primary && editor.canUngroup ? { editor.ungroupSelection() } : nil
                        )
                        .position(center(of: element, scale: scale))
                    }
                    if let selected = editor.selectedElement {
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
                .contentShape(Rectangle())
                .coordinateSpace(name: ArtboardCoordinate.name)
                .gesture(pageGesture(scale: scale, artboardOrigin: origin))
                .frame(width: fitted.width, height: fitted.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Canvas")
        .focusable()
        .focused($canvasFocused)
        .focusedValue(\.canvasEditActions, CanvasEditActions(
            canDuplicate: editor.canDuplicate,
            duplicate: { editor.duplicateSelection() }
        ))
        .modifier(CanvasClipboardModifier(
            clipboard: editor.makeClipboard(),
            onPaste: { editor.paste($0) }
        ))
        .onDeleteCommand { editor.deleteSelection() }
        .onKeyPress(phases: [.down, .up]) { press in
            shiftHeld = press.modifiers.contains(.shift)
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
                canvasFocused = true
                var session = session(for: value, scale: scale, artboardOrigin: artboardOrigin)
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
                let edited = editor.activeMoveID != nil || editor.isAdjustingWithHandle
                editor.endMove()
                editor.endResize()
                editor.endRotate()
                if !edited, traveled < CanvasPointerRouting.dragSlop {
                    let hit = pointer?.contact ?? contact(
                        at: value.startLocation,
                        scale: scale,
                        artboardOrigin: artboardOrigin
                    )
                    select(for: hit, additive: shiftHeld)
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
        canvasFocused = true
        if contact.onBody, let id = contact.elementID {
            if additive {
                editor.toggleSelection(id)
            } else {
                editor.select(id)
            }
        } else if contact.handleOutsideBody == nil, !additive {
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
    private func selectionLineWidth(
        for element: CanvasElement,
        scale: Double,
        artboardOrigin: CGPoint
    ) -> CGFloat {
        let base: CGFloat = contrast == .increased ? 3 : 2
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
        return crossesReservedArea ? base + 1 : base
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
