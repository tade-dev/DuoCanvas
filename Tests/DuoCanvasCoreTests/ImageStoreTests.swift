import CanvasCommands
import CanvasModel
import Foundation
import Testing

@MainActor
@Suite("Image store")
struct ImageStoreTests {
    @Test func bytesStayWhenTheElementIsUndone() {
        let session = EditingSession()
        let ref = ImageRef()
        let element = CanvasElement.image(ref)
        let bytes = Data([1, 2, 3, 4])
        session.imageStore.store(bytes, for: ref.id)
        session.commandManager.insert(element)
        let inserted = session.document.copy()

        session.commandManager.undo()
        #expect(session.document.element(element.id) == nil)
        #expect(session.imageStore.data(for: ref.id) == bytes)

        session.commandManager.redo()
        #expect(session.document == inserted)
        #expect(session.document.element(element.id)?.image == ref)
        #expect(session.imageStore.data(for: ref.id) == bytes)
    }

    @Test func aLaterWriteReplacesBytesForTheSameId() {
        let store = CanvasImageStore()
        let id = UUID()
        store.store(Data([1]), for: id)
        store.store(Data([9, 9]), for: id)
        #expect(store.data(for: id) == Data([9, 9]))
        #expect(store.data(for: UUID()) == nil)
    }

    @Test func theDocumentSnapshotDoesNotCarryBytes() {
        let session = EditingSession()
        let ref = ImageRef()
        let element = CanvasElement.image(ref, size: CanvasSize(width: 40, height: 20))
        session.imageStore.store(Data([7, 7, 7]), for: ref.id)
        session.commandManager.insert(element)
        let snapshot = session.document.snapshot()
        #expect(snapshot.elements[element.id]?.image == ref)
        #expect(snapshot.elements[element.id]?.id != ref.id)
        #expect(session.imageStore.data(for: ref.id)?.count == 3)
    }
}
