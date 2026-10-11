import CanvasModel
import CoreTransferable
import SwiftUI
import UIKit

enum CanvasPNGRenderer {
    /// Draws the page at 2x. Call when the user exports; a drag preview is not in `elements`
    /// when `elements` is the last committed snapshot.
    @MainActor
    static func pngData(
        canvasSize: CanvasSize,
        background: CanvasColor,
        elements: [CanvasElement],
        images: [UUID: Data]
    ) -> Data? {
        let decoded = images.mapValues { UIImage(data: $0) }
        let content = CanvasExportView(
            canvasSize: canvasSize,
            background: background,
            elements: elements,
            images: decoded
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: canvasSize.width, height: canvasSize.height)
        return renderer.uiImage?.pngData()
    }

    /// Renders on the main actor when sharing starts, and reports a failure the editor can show.
    @MainActor
    static func exportedPNG(_ page: CanvasPageExport) async throws -> Data {
        let interval = CanvasInstrumentation.begin(CanvasInstrumentation.pngExport)
        defer { CanvasInstrumentation.end(CanvasInstrumentation.pngExport, interval) }
        if let problem = CanvasExportCheck.problem(width: page.canvasSize.width, height: page.canvasSize.height) {
            CanvasExportReporting.report?(problem)
            throw problem
        }
        guard let data = pngData(
            canvasSize: page.canvasSize,
            background: page.background,
            elements: page.elements,
            images: page.images
        ) else {
            CanvasExportReporting.report?(.renderFailed)
            CanvasInstrumentation.log.error("PNG export produced no image")
            throw CanvasExportProblem.renderFailed
        }
        return data
    }
}

/// The committed page, rendered when the share sheet asks for bytes.
struct CanvasPageExport: Sendable {
    var canvasSize: CanvasSize
    var background: CanvasColor
    var elements: [CanvasElement]
    var images: [UUID: Data]
}

extension CanvasPageExport: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { page in
            try await CanvasPNGRenderer.exportedPNG(page)
        }
    }
}

@MainActor
enum CanvasExportReporting {
    static var report: ((CanvasExportProblem) -> Void)?
}

/// The artboard only, in canvas points, for `ImageRenderer`.
struct CanvasExportView: View {
    var canvasSize: CanvasSize
    var background: CanvasColor
    var elements: [CanvasElement]
    var images: [UUID: UIImage?]

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(background.swiftUIColor)
            ForEach(elements) { element in
                CanvasElementView.rendered(
                    element: element,
                    scale: 1,
                    displayImage: element.image.flatMap { images[$0.id] ?? nil }
                )
                .position(center(of: element))
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .accessibilityHidden(true)
    }

    private func center(of element: CanvasElement) -> CGPoint {
        CGPoint(
            x: element.position.x + element.size.width / 2,
            y: element.position.y + element.size.height / 2
        )
    }
}
