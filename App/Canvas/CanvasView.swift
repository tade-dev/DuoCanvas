import CanvasModel
import SwiftUI
import UIKit

/// The page, fitted to the pane. This view takes a plain layout context and does not
/// read device pose itself.
struct CanvasView: View {
    var editor: EditorModel
    var layoutContext: CanvasLayoutContext

    @Environment(\.colorSchemeContrast) private var contrast
    @GestureState private var moveGestureActive = false

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
                    .onTapGesture { editor.select(nil) }
                ZStack(alignment: .topLeading) {
                    artboardBackground
                        .frame(width: fitted.width, height: fitted.height)
                    ForEach(editor.document.orderedElements) { element in
                        CanvasElementView(
                            element: element,
                            scale: scale,
                            imageData: imageData(for: element),
                            isSelected: editor.primarySelection == element.id,
                            selectionLineWidth: selectionLineWidth(
                                for: element,
                                scale: scale,
                                artboardOrigin: origin
                            ),
                            onSelect: { editor.select(element.id) }
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
                            ),
                            editor: editor
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
        .onChange(of: moveGestureActive) { _, active in
            if !active {
                editor.noteCanvasGestureEnded()
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
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .updating($moveGestureActive) { value, state, _ in
                if distance(value.translation) >= 10 {
                    state = true
                }
            }
            .onChanged { value in
                guard !editor.isAdjustingWithHandle else { return }
                guard !hitsSelectionHandle(value.startLocation, scale: scale, artboardOrigin: artboardOrigin) else {
                    return
                }
                guard distance(value.translation) >= 10 else { return }
                let id = editor.activeMoveID ?? elementID(at: value.startLocation, scale: scale)
                guard let id else { return }
                editor.previewMove(
                    of: id,
                    translationX: Double(value.translation.width),
                    translationY: Double(value.translation.height),
                    scale: scale
                )
            }
            .onEnded { value in
                guard !editor.isAdjustingWithHandle else { return }
                let startedOnHandle = hitsSelectionHandle(
                    value.startLocation,
                    scale: scale,
                    artboardOrigin: artboardOrigin
                )
                let endedOnHandle = hitsSelectionHandle(
                    value.location,
                    scale: scale,
                    artboardOrigin: artboardOrigin
                )
                guard !startedOnHandle, !endedOnHandle else { return }
                if distance(value.translation) < 10 {
                    editor.select(elementID(at: value.location, scale: scale))
                } else {
                    editor.endMove()
                }
            }
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

    private func hitsSelectionHandle(_ point: CGPoint, scale: Double, artboardOrigin: CGPoint) -> Bool {
        guard let element = editor.selectedElement else { return false }
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
        return SelectionHandleLayout.hitHandle(at: local, centers: centers) != nil
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
