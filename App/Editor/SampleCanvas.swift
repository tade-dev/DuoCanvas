import CanvasModel
import Foundation

/// A few shapes so the editor can be tried without an insert tool.
enum SampleCanvas {
    @MainActor static func makeDocument() -> CanvasDocument {
        CanvasDocument(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
            canvasConfig: CanvasConfig(
                size: CanvasSize(width: 800, height: 600),
                background: .white
            ),
            elements: elements
        )
    }

    private static let elements: [CanvasElement] = [
        .rectangle(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            position: CanvasPoint(x: 48, y: 48),
            size: CanvasSize(width: 200, height: 140),
            fill: Paint(color: CanvasColor(red: 0.23, green: 0.39, blue: 0.67, alpha: 1))
        ),
        .roundedRectangle(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            position: CanvasPoint(x: 300, y: 72),
            size: CanvasSize(width: 200, height: 130),
            cornerRadius: 16,
            fill: Paint(color: CanvasColor(red: 0.86, green: 0.49, blue: 0.22, alpha: 1))
        ),
        .circle(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            position: CanvasPoint(x: 80, y: 250),
            size: CanvasSize(width: 150, height: 150),
            fill: Paint(color: CanvasColor(red: 0.18, green: 0.55, blue: 0.42, alpha: 1))
        ),
        CanvasElement(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            type: .text,
            position: CanvasPoint(x: 280, y: 280),
            size: CanvasSize(width: 320, height: 80),
            text: TextAttributes(string: "Select, then inspect", fontSize: 28)
        ),
        .line(
            from: CanvasPoint(x: 64, y: 470),
            to: CanvasPoint(x: 460, y: 540),
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        ),
    ]
}
