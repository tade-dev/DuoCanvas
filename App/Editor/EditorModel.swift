import CanvasCommands
import CanvasModel
import Foundation
import Observation

/// The in-memory editor for one project: the document, its command stack, and the selection.
@MainActor
@Observable
final class EditorModel {
    let session: EditingSession

    var primarySelection: CanvasElement.ID?
    /// Compact width presents the inspector as a sheet. Regular width ignores this flag.
    var inspectorPresented = false

    private var moveEdit: CoalescedEdit?
    private var moveOrigin: CanvasPoint?
    private var movingID: CanvasElement.ID?
    private var resizeEdit: CoalescedEdit?
    private var resizeStartPosition: CanvasPoint?
    private var resizeStartSize: CanvasSize?
    private var resizeRotation = 0.0
    private var resizeHandle: SelectionHandle?
    private var resizingID: CanvasElement.ID?
    private var rotateEdit: CoalescedEdit?
    private var rotateCenter: CanvasPoint?
    private var rotateLastRadians: Double?
    private var rotatingID: CanvasElement.ID?
    private var styleEdit: CoalescedEdit?
    private var styleID: CanvasElement.ID?
    private var styleAction: String?
    private var styleSliderDown = false
    private var styleEndTask: Task<Void, Never>?
    private var continuousFlushTask: Task<Void, Never>?
    private var canvasGestureEndedNormally = false
    private var canvasGestureGeneration = 0
    /// The system undo manager this session is recording into, once SwiftUI has provided one.
    private var adoptedUndoManager: UndoManager?

    init(document: CanvasDocument, imageStore: CanvasImageStore? = nil) {
        let undoManager = UndoManager()
        // Used until the view can see the system undo manager. `groupsByEvent` matches
        // UndoManager's default, so a run-loop turn is still one step.
        undoManager.groupsByEvent = true
        session = EditingSession(
            document: document,
            imageStore: imageStore,
            undoRecording: SystemUndoRecording(undoManager: undoManager)
        )
    }

    /// Records later edits on `manager` when the stack is still empty.
    ///
    /// `EnvironmentValues.undoManager` is get-only, so the session uses the instance
    /// SwiftUI already publishes. Shake and the Edit menu then see the same registrations
    /// as the toolbar. A nil value leaves the session on its own manager.
    func adoptSystemUndoManager(_ manager: UndoManager?) {
        guard let manager else { return }
        if adoptedUndoManager === manager { return }
        guard !session.commandManager.canUndo, !session.commandManager.canRedo else { return }
        cancelInFlightEdit()
        guard session.commandManager.replaceUndoRecordingIfEmpty(
            with: SystemUndoRecording(undoManager: manager)
        ) else { return }
        adoptedUndoManager = manager
    }

    var document: CanvasDocument { session.document }
    var imageStore: CanvasImageStore { session.imageStore }

    var selectedElement: CanvasElement? {
        guard let primarySelection else { return nil }
        return document.element(primarySelection)
    }

    var activeMoveID: CanvasElement.ID? { movingID }

    var isAdjustingWithHandle: Bool {
        resizeEdit != nil || rotateEdit != nil
    }

    var canUndo: Bool { session.commandManager.canUndo }
    var canRedo: Bool { session.commandManager.canRedo }
    var undoActionName: String { session.commandManager.undoActionName }
    var redoActionName: String { session.commandManager.redoActionName }

    func select(_ id: CanvasElement.ID?) {
        if id != primarySelection {
            endStyleEdit()
            session.commandManager.flushContinuousEdits()
        }
        primarySelection = id
    }

    func undo() {
        cancelInFlightEdit()
        continuousFlushTask?.cancel()
        session.commandManager.undo()
    }

    func redo() {
        cancelInFlightEdit()
        continuousFlushTask?.cancel()
        session.commandManager.redo()
    }

    func setX(_ x: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        prepareForDiscreteCommand()
        session.commandManager.move(id, to: CanvasPoint(x: x, y: element.position.y))
    }

    func setY(_ y: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        prepareForDiscreteCommand()
        session.commandManager.move(id, to: CanvasPoint(x: element.position.x, y: y))
    }

    func setWidth(_ width: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        prepareForDiscreteCommand()
        session.commandManager.resize(id, to: CanvasSize(width: width, height: element.size.height))
    }

    func setHeight(_ height: Double, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        prepareForDiscreteCommand()
        session.commandManager.resize(id, to: CanvasSize(width: element.size.width, height: height))
    }

    func setRotation(_ degrees: Double, for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        session.commandManager.rotate(id, to: CanvasRotation(degrees: degrees))
    }

    func setFillColor(_ color: CanvasColor, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        let alpha = element.fill?.color.alpha ?? 1
        let next = CanvasColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha)
        if let current = element.fill?.color, sameColorChannels(current, next) { return }
        prepareForContinuousEdit()
        session.commandManager.recordContinuousEdit(
            key: ContinuousEditKey(elementID: id, property: .fill)
        ) { document in
            document.update(id) { element in
                let alpha = element.fill?.color.alpha ?? 1
                element.fill = Paint(
                    color: CanvasColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha)
                )
            }
        }
        scheduleContinuousFlush()
    }

    func addFill(for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        session.commandManager.updateStyle(of: id) { style in
            if style.fill == nil {
                style.fill = Paint(color: .black)
            }
        }
    }

    func setStrokeColor(_ color: CanvasColor, for id: CanvasElement.ID) {
        guard let element = document.element(id) else { return }
        let alpha = element.stroke?.color.alpha ?? 1
        let width = element.stroke?.width ?? 1
        let next = Stroke(
            color: CanvasColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha),
            width: width
        )
        if let current = element.stroke, sameColorChannels(current.color, next.color), current.width == next.width {
            return
        }
        prepareForContinuousEdit()
        session.commandManager.recordContinuousEdit(
            key: ContinuousEditKey(elementID: id, property: .stroke)
        ) { document in
            document.update(id) { element in
                let alpha = element.stroke?.color.alpha ?? 1
                let width = element.stroke?.width ?? 1
                element.stroke = Stroke(
                    color: CanvasColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha),
                    width: width
                )
            }
        }
        scheduleContinuousFlush()
    }

    func addStroke(for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        session.commandManager.updateStyle(of: id) { style in
            if style.stroke == nil {
                style.stroke = Stroke(color: .black, width: 1)
            }
        }
    }

    func removeStroke(for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        session.commandManager.updateStyle(of: id) { style in
            style.stroke = nil
        }
    }

    func beginStyleSlider(for id: CanvasElement.ID, actionName: String) {
        styleSliderDown = true
        styleEndTask?.cancel()
        ensureStyleEdit(id: id, actionName: actionName)
    }

    func endStyleAdjustment() {
        styleSliderDown = false
        styleEndTask?.cancel()
        endStyleEdit()
    }

    func previewOpacity(_ value: Double, for id: CanvasElement.ID) {
        let clamped = min(max(value, 0), 1)
        guard document.element(id)?.opacity != clamped else { return }
        ensureStyleEdit(id: id, actionName: "Opacity")
        styleEdit?.preview { document in
            document.update(id) { element in
                element.opacity = clamped
            }
        }
        scheduleStyleEndIfNeeded()
    }

    func setOpacity(_ value: Double, for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        session.commandManager.updateStyle(of: id) { style in
            style.opacity = min(max(value, 0), 1)
        }
    }

    func previewStrokeWidth(_ value: Double, for id: CanvasElement.ID) {
        let clamped = max(value, 0)
        guard document.element(id)?.stroke?.width != clamped else { return }
        ensureStyleEdit(id: id, actionName: "Stroke Width")
        styleEdit?.preview { document in
            document.update(id) { element in
                if var stroke = element.stroke {
                    stroke.width = clamped
                    element.stroke = stroke
                } else {
                    element.stroke = Stroke(color: .black, width: clamped)
                }
            }
        }
        scheduleStyleEndIfNeeded()
    }

    func setStrokeWidth(_ value: Double, for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        let clamped = max(value, 0)
        session.commandManager.updateStyle(of: id) { style in
            if var stroke = style.stroke {
                stroke.width = clamped
                style.stroke = stroke
            } else {
                style.stroke = Stroke(color: .black, width: clamped)
            }
        }
    }

    func previewCornerRadius(_ value: Double, for id: CanvasElement.ID) {
        let clamped = max(value, 0)
        guard document.element(id)?.cornerRadius != clamped else { return }
        ensureStyleEdit(id: id, actionName: "Corner Radius")
        styleEdit?.preview { document in
            document.update(id) { element in
                element.cornerRadius = clamped
            }
        }
        scheduleStyleEndIfNeeded()
    }

    func setCornerRadius(_ value: Double, for id: CanvasElement.ID) {
        prepareForDiscreteCommand()
        session.commandManager.updateStyle(of: id) { style in
            style.cornerRadius = max(value, 0)
        }
    }

    func setTextString(_ string: String, for id: CanvasElement.ID) {
        mutateText(id) { text in
            text.string = string
        }
    }

    func setFontName(_ name: String, for id: CanvasElement.ID) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutateText(id) { text in
            text.fontName = trimmed
        }
    }

    func setFontSize(_ size: Double, for id: CanvasElement.ID) {
        mutateText(id) { text in
            text.fontSize = min(max(size, 1), 512)
        }
    }

    func setFontWeight(_ weight: CanvasFontWeight, for id: CanvasElement.ID) {
        mutateText(id) { text in
            text.fontWeight = weight
        }
    }

    func setTextAlignment(_ alignment: CanvasTextAlignment, for id: CanvasElement.ID) {
        mutateText(id) { text in
            text.alignment = alignment
        }
    }

    func setTextColor(_ color: CanvasColor, for id: CanvasElement.ID) {
        guard let text = document.element(id)?.text else { return }
        let next = CanvasColor(red: color.red, green: color.green, blue: color.blue, alpha: text.color.alpha)
        guard !sameColorChannels(text.color, next) else { return }
        prepareForContinuousEdit()
        session.commandManager.recordContinuousEdit(
            key: ContinuousEditKey(elementID: id, property: .textColor)
        ) { document in
            document.update(id) { element in
                guard var text = element.text else { return }
                text.color = CanvasColor(
                    red: color.red,
                    green: color.green,
                    blue: color.blue,
                    alpha: text.color.alpha
                )
                element.text = text
            }
        }
        scheduleContinuousFlush()
    }

    func addRectangle() {
        insertNew(
            CanvasElement.rectangle(
                position: nextOrigin(),
                size: CanvasSize(width: 160, height: 110)
            )
        )
    }

    func addRoundedRectangle() {
        insertNew(
            CanvasElement.roundedRectangle(
                position: nextOrigin(),
                size: CanvasSize(width: 160, height: 110),
                cornerRadius: 16
            )
        )
    }

    func addCircle() {
        insertNew(
            CanvasElement.circle(
                position: nextOrigin(),
                size: CanvasSize(width: 120, height: 120)
            )
        )
    }

    func addText() {
        insertNew(
            CanvasElement.text(
                "Text",
                position: nextOrigin(),
                size: CanvasSize(width: 200, height: 48)
            )
        )
    }

    func addLine() {
        let start = nextOrigin()
        insertNew(
            CanvasElement.line(
                from: start,
                to: CanvasPoint(x: start.x + 180, y: start.y + 36)
            )
        )
    }

    /// Stores `data` for this session and inserts an image element.
    /// The id is the `ImageRef`. A project save writes those bytes with the element.
    func insertImage(data: Data, pixelWidth: Double, pixelHeight: Double) {
        let id = UUID()
        session.imageStore.store(data, for: id)
        let element = CanvasElement.image(
            ImageRef(id: id),
            position: nextOrigin(),
            size: fittedImageSize(width: pixelWidth, height: pixelHeight)
        )
        insertNew(element)
    }

    /// Live drag. `translation` is in the artboard's view space; `scale` converts it to canvas points.
    func previewMove(of id: CanvasElement.ID, translationX: Double, translationY: Double, scale: Double) {
        guard resizeEdit == nil, rotateEdit == nil else { return }
        guard scale > 0, document.element(id) != nil else { return }
        if moveEdit == nil {
            guard let current = document.element(id) else { return }
            endStyleEdit()
            session.commandManager.flushContinuousEdits()
            primarySelection = id
            movingID = id
            moveOrigin = current.position
            beginCanvasGesture()
            moveEdit = session.commandManager.beginCoalescedEdit(actionName: "Move")
        }
        guard movingID == id, let origin = moveOrigin else { return }
        let position = CanvasPoint(
            x: origin.x + translationX / scale,
            y: origin.y + translationY / scale
        )
        moveEdit?.preview { document in
            document.update(id) { element in
                element.position = position
            }
        }
    }

    func previewResize(
        of id: CanvasElement.ID,
        handle: SelectionHandle,
        artboardTranslationX: Double,
        artboardTranslationY: Double,
        scale: Double
    ) {
        guard scale > 0, document.element(id) != nil else { return }
        if resizeEdit == nil {
            guard let current = document.element(id) else { return }
            endMove()
            endRotate()
            endStyleEdit()
            session.commandManager.flushContinuousEdits()
            resizeStartPosition = current.position
            resizeStartSize = current.size
            resizeRotation = current.rotation.degrees
            resizeHandle = handle
            resizingID = id
            primarySelection = id
            beginCanvasGesture()
            resizeEdit = session.commandManager.beginCoalescedEdit(actionName: "Resize")
        }
        guard resizingID == id, resizeHandle == handle,
              let startPosition = resizeStartPosition, let startSize = resizeStartSize else { return }
        let local = SelectionGeometry.localTranslation(
            artboardX: artboardTranslationX,
            artboardY: artboardTranslationY,
            scale: scale,
            rotationDegrees: resizeRotation
        )
        let minimum = document.element(id)?.type == .line ? 1.0 : 8.0
        let result = SelectionGeometry.resized(
            handle: handle,
            position: startPosition,
            size: startSize,
            rotationDegrees: resizeRotation,
            localTranslation: local,
            minimumLength: minimum
        )
        resizeEdit?.preview { document in
            document.update(id) { element in
                element.position = result.position
                element.size = result.size
            }
        }
    }

    func previewRotate(of id: CanvasElement.ID, canvasPoint: CanvasPoint) {
        guard document.element(id) != nil else { return }
        if rotateEdit == nil {
            guard let current = document.element(id) else { return }
            endMove()
            endResize()
            endStyleEdit()
            session.commandManager.flushContinuousEdits()
            rotateCenter = CanvasPoint(
                x: current.position.x + current.size.width / 2,
                y: current.position.y + current.size.height / 2
            )
            rotatingID = id
            primarySelection = id
            beginCanvasGesture()
            rotateEdit = session.commandManager.beginCoalescedEdit(actionName: "Rotate")
            rotateLastRadians = angle(from: rotateCenter ?? .zero, to: canvasPoint)
            return
        }
        guard rotatingID == id, let center = rotateCenter, let last = rotateLastRadians else { return }
        let nextAngle = angle(from: center, to: canvasPoint)
        let delta = SelectionGeometry.clockwiseDeltaDegrees(from: last, to: nextAngle)
        rotateLastRadians = nextAngle
        let degrees = (document.element(id)?.rotation.degrees ?? 0) + delta
        rotateEdit?.preview { document in
            document.update(id) { element in
                element.rotation = CanvasRotation(degrees: degrees)
            }
        }
    }

    func endMove() {
        guard moveEdit != nil else { return }
        canvasGestureEndedNormally = true
        moveEdit?.end()
        clearMove()
    }

    func endResize() {
        guard resizeEdit != nil else { return }
        canvasGestureEndedNormally = true
        resizeEdit?.end()
        clearResize()
    }

    func endRotate() {
        guard rotateEdit != nil else { return }
        canvasGestureEndedNormally = true
        rotateEdit?.end()
        clearRotate()
    }

    /// Turns an open drag, slider, or colour edit into a command when it changed anything.
    ///
    /// Leaving the app calls this before the project save. The preview is not written.
    /// Ending it records one command, and that commit is what gets saved.
    func commitOpenEdits() {
        endMove()
        endResize()
        endRotate()
        endStyleEdit()
        session.commandManager.flushContinuousEdits()
    }

    /// Drops a drag that the gesture system cancelled, or that a pose change interrupted.
    func cancelInFlightEdit() {
        styleSliderDown = false
        styleEndTask?.cancel()
        if moveEdit != nil {
            moveEdit?.cancel()
            clearMove()
        }
        if resizeEdit != nil {
            resizeEdit?.cancel()
            clearResize()
        }
        if rotateEdit != nil {
            rotateEdit?.cancel()
            clearRotate()
        }
        if styleEdit != nil {
            styleEdit?.cancel()
            clearStyle()
        }
    }

    /// Called after a canvas gesture resets. A normal end has already cleared the edit.
    func noteCanvasGestureEnded() {
        let generation = canvasGestureGeneration
        Task { @MainActor in
            guard generation == self.canvasGestureGeneration else { return }
            self.cancelAbandonedCanvasGesture()
        }
    }

    private func cancelAbandonedCanvasGesture() {
        guard !canvasGestureEndedNormally else { return }
        guard moveEdit != nil || resizeEdit != nil || rotateEdit != nil else { return }
        if moveEdit != nil {
            moveEdit?.cancel()
            clearMove()
        }
        if resizeEdit != nil {
            resizeEdit?.cancel()
            clearResize()
        }
        if rotateEdit != nil {
            rotateEdit?.cancel()
            clearRotate()
        }
    }

    private func beginCanvasGesture() {
        canvasGestureGeneration += 1
        canvasGestureEndedNormally = false
    }

    private func prepareForDiscreteCommand() {
        endMove()
        endResize()
        endRotate()
        endStyleEdit()
        session.commandManager.flushContinuousEdits()
    }

    /// Ends an open slider or drag so a colour change can record on its own.
    private func prepareForContinuousEdit() {
        endMove()
        endResize()
        endRotate()
        endStyleEdit()
    }

    private func ensureStyleEdit(id: CanvasElement.ID, actionName: String) {
        if styleEdit != nil, styleID == id, styleAction == actionName {
            return
        }
        endMove()
        endResize()
        endRotate()
        endStyleEdit()
        session.commandManager.flushContinuousEdits()
        styleID = id
        styleAction = actionName
        styleEdit = session.commandManager.beginCoalescedEdit(actionName: actionName)
    }

    private func endStyleEdit() {
        guard styleEdit != nil else { return }
        styleEdit?.end()
        clearStyle()
    }

    private func scheduleStyleEndIfNeeded() {
        guard !styleSliderDown else { return }
        styleEndTask?.cancel()
        styleEndTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, !self.styleSliderDown else { return }
            self.endStyleEdit()
        }
    }

    private func scheduleContinuousFlush() {
        continuousFlushTask?.cancel()
        continuousFlushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            self.session.commandManager.flushContinuousEdits()
        }
    }

    private func mutateText(_ id: CanvasElement.ID, _ body: (inout TextAttributes) -> Void) {
        prepareForDiscreteCommand()
        session.commandManager.updateText(of: id, body)
    }

    private func insertNew(_ element: CanvasElement) {
        prepareForDiscreteCommand()
        session.commandManager.insert(element)
        primarySelection = element.id
    }

    private func nextOrigin() -> CanvasPoint {
        let step = Double(document.order.count % 8)
        return CanvasPoint(x: 72 + step * 18, y: 72 + step * 18)
    }

    private func fittedImageSize(width: Double, height: Double) -> CanvasSize {
        let fallback = CanvasSize(width: 180, height: 140)
        guard width > 0, height > 0 else { return fallback }
        let maxSide = 240.0
        let scale = min(maxSide / width, maxSide / height)
        return CanvasSize(width: width * scale, height: height * scale)
    }

    private func angle(from center: CanvasPoint, to point: CanvasPoint) -> Double {
        atan2(point.y - center.y, point.x - center.x)
    }

    /// Ignores noise from a colour picker echoing the colour it was given.
    private func sameColorChannels(_ lhs: CanvasColor, _ rhs: CanvasColor) -> Bool {
        let tolerance = 1.0 / 512
        return abs(lhs.red - rhs.red) < tolerance
            && abs(lhs.green - rhs.green) < tolerance
            && abs(lhs.blue - rhs.blue) < tolerance
    }

    private func clearMove() {
        moveEdit = nil
        moveOrigin = nil
        movingID = nil
    }

    private func clearResize() {
        resizeEdit = nil
        resizeStartPosition = nil
        resizeStartSize = nil
        resizeHandle = nil
        resizingID = nil
    }

    private func clearRotate() {
        rotateEdit = nil
        rotateCenter = nil
        rotateLastRadians = nil
        rotatingID = nil
    }

    private func clearStyle() {
        styleEdit = nil
        styleID = nil
        styleAction = nil
    }
}
