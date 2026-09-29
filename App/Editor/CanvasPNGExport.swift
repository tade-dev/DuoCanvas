import CanvasModel
import CoreTransferable
import SwiftUI
import UIKit

/// PNG of the committed artboard. Selection chrome is left out.
struct CanvasPNG: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { png in
            png.data
        }
    }
}

enum CanvasPNGRenderer {
    /// Draws the page at 2x. Call after a command commits; a drag preview is not in `elements`.
    @MainActor
    static func pngData(
        canvasSize: CanvasSize,
        background: CanvasColor,
        elements: [CanvasElement],
        images: [UUID: Data]
    ) -> Data? {
        let content = CanvasExportView(
            canvasSize: canvasSize,
            background: background,
            elements: elements,
            images: images
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: canvasSize.width, height: canvasSize.height)
        return renderer.uiImage?.pngData()
    }
}

/// The artboard only, in canvas points, for `ImageRenderer`.
struct CanvasExportView: View {
    var canvasSize: CanvasSize
    var background: CanvasColor
    var elements: [CanvasElement]
    var images: [UUID: Data]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(background.swiftUIColor)
            ForEach(elements) { element in
                CanvasElementView(
                    element: element,
                    scale: 1,
                    imageData: element.image.flatMap { images[$0.id] },
                    role: .none,
                    selectionLineWidth: 0,
                    onSelect: {}
                )
                .position(center(of: element))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }

    private func center(of element: CanvasElement) -> CGPoint {
        CGPoint(
            x: element.position.x + element.size.width / 2,
            y: element.position.y + element.size.height / 2
        )
    }
}
