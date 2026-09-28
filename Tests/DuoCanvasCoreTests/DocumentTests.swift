import CanvasModel
import Testing

@MainActor
@Suite("Canvas document")
struct DocumentTests {
    @Test func equalityIgnoresRevision() {
        let document = CanvasDocument()
        let element = CanvasElement.rectangle(position: CanvasPoint(x: 4, y: 5))
        document.insert(element, at: nil)
        let saved = document.copy()

        #expect(saved == document)
        #expect(saved.revision == 0)
        #expect(document.revision == 1)

        document.withoutRecordingRevision {
            document.update(element.id) { $0.position = CanvasPoint(x: 9, y: 9) }
        }
        #expect(document.revision == 1)
        #expect(document.element(element.id)?.position == CanvasPoint(x: 9, y: 9))
        #expect(saved != document)
    }

    @Test func orderIsBackToFront() {
        let document = CanvasDocument()
        let back = CanvasElement.rectangle()
        let front = CanvasElement.circle()
        document.insert(back, at: nil)
        document.insert(front, at: nil)
        document.insert(CanvasElement.text("Between"), at: 1)

        #expect(document.order.first == back.id)
        #expect(document.order.last == front.id)
        #expect(document.orderedElements.map(\.type) == [.rectangle, .text, .circle])
    }

    @Test func defaultArtboardIsNotADeviceSize() {
        let config = CanvasConfig()
        #expect(config.size == CanvasSize(width: 1200, height: 800))
        #expect(config.background == .white)
    }

    @Test func elementTypesCoverTheV1Set() {
        #expect(CanvasElementType.allCases == [
            .rectangle, .roundedRectangle, .circle, .text, .image, .line, .group,
        ])
    }

    @Test func lineStoresEndAsAnOffset() {
        let line = CanvasElement.line(
            from: CanvasPoint(x: 1, y: 2),
            to: CanvasPoint(x: 4, y: -1)
        )
        #expect(line.position == CanvasPoint(x: 1, y: 2))
        #expect(line.size == CanvasSize(width: 3, height: -3))
    }
}
