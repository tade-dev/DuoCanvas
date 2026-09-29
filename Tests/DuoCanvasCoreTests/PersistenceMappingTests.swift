import CanvasCommands
import CanvasModel
import Foundation
import PersistenceMapping
import Testing

@MainActor
@Suite("Persistence mapping")
struct PersistenceMappingTests {
    @Test func aDocumentRoundTripsElementsImagesAndOrder() throws {
        let imageID = UUID(uuidString: "30000000-0000-0000-0000-000000000010")!
        let bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D])
        let groupID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let childID = UUID(uuidString: "30000000-0000-0000-0000-000000000002")!
        let textID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
        let imageElementID = UUID(uuidString: "30000000-0000-0000-0000-000000000004")!
        let lineID = UUID(uuidString: "30000000-0000-0000-0000-000000000005")!
        let circleID = UUID(uuidString: "30000000-0000-0000-0000-000000000006")!
        let roundedID = UUID(uuidString: "30000000-0000-0000-0000-000000000007")!
        let plainID = UUID(uuidString: "30000000-0000-0000-0000-000000000008")!

        let original = CanvasDocument(
            id: UUID(uuidString: "30000000-0000-0000-0000-0000000000AA")!,
            canvasConfig: CanvasConfig(
                size: CanvasSize(width: 900, height: 500),
                background: CanvasColor(red: 0.25, green: 0.5, blue: 0.75, alpha: 1)
            ),
            elements: [
                CanvasElement.group(id: groupID, childIDs: [childID, plainID]),
                CanvasElement(
                    id: childID,
                    type: .rectangle,
                    position: CanvasPoint(x: 10, y: 20),
                    size: CanvasSize(width: 30, height: 40),
                    rotation: CanvasRotation(degrees: 15),
                    opacity: 0.5,
                    fill: Paint(color: CanvasColor(red: 0.25, green: 0.5, blue: 0, alpha: 1)),
                    stroke: Stroke(color: .black, width: 2),
                    cornerRadius: 0,
                    parentID: groupID
                ),
                CanvasElement(
                    id: textID,
                    type: .text,
                    position: CanvasPoint(x: 8, y: 9),
                    size: CanvasSize(width: 120, height: 40),
                    text: TextAttributes(
                        string: "A \"quote\" and café",
                        fontName: "Helvetica Neue",
                        fontSize: 21,
                        fontWeight: .semibold,
                        alignment: .center,
                        color: CanvasColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
                    )
                ),
                CanvasElement.image(
                    ImageRef(id: imageID),
                    id: imageElementID,
                    position: CanvasPoint(x: 4, y: 6),
                    size: CanvasSize(width: 80, height: 50)
                ),
                CanvasElement.line(
                    from: CanvasPoint(x: 1, y: 2),
                    to: CanvasPoint(x: -20, y: 14),
                    id: lineID
                ),
                CanvasElement.circle(
                    id: circleID,
                    position: CanvasPoint(x: 3, y: 4),
                    size: CanvasSize(width: 16, height: 16),
                    fill: nil
                ),
                CanvasElement.roundedRectangle(
                    id: roundedID,
                    position: .zero,
                    size: CanvasSize(width: 12, height: 8),
                    cornerRadius: 4,
                    fill: Paint(color: .white)
                ),
                CanvasElement.rectangle(id: plainID, fill: nil),
            ]
        )

        let state = CanvasRecordMapping.state(from: original) { id in
            id == imageID ? bytes : nil
        }
        #expect(state.elements.map(\.zIndex) == Array(0..<state.elements.count))
        #expect(state.elements.map(\.id).last == plainID)

        let loaded = try CanvasRecordMapping.makeDocument(id: original.id, from: state)
        #expect(loaded.document == original)
        #expect(loaded.document.revision == 0)
        #expect(loaded.imageDataByID[imageID] == bytes)
        #expect(loaded.document.element(imageElementID)?.image == ImageRef(id: imageID))
        #expect(loaded.document.element(imageElementID)?.id != imageID)
        #expect(loaded.document.zIndex(of: groupID) == 0)
        #expect(loaded.document.zIndex(of: plainID) == original.order.count - 1)
        #expect(loaded.document.element(lineID)?.size.width == -21)
        #expect(loaded.document.element(childID)?.parentID == groupID)
        #expect(loaded.document.element(groupID)?.childIDs == [childID, plainID])
    }

    @Test func zIndexSortsBackToFrontWhenStoredOutOfOrder() throws {
        let back = element(id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!, zIndex: 5)
        let middle = element(id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!, zIndex: 0)
        let front = element(id: UUID(uuidString: "40000000-0000-0000-0000-000000000003")!, zIndex: 2)
        let state = PersistedCanvasState(
            canvasWidth: 10,
            canvasHeight: 10,
            backgroundRed: 1,
            backgroundGreen: 1,
            backgroundBlue: 1,
            backgroundAlpha: 1,
            elements: [back, front, middle]
        )
        let loaded = try CanvasRecordMapping.makeDocument(id: UUID(), from: state)
        #expect(loaded.document.order == [middle.id, front.id, back.id])
    }

    @Test func changesReportInsertUpdateDeletionAndImageBytes() {
        let id = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        let other = UUID(uuidString: "50000000-0000-0000-0000-000000000002")!
        let original = element(id: id, zIndex: 0)
        var moved = original
        moved.positionX = 9
        var reordered = original
        reordered.zIndex = 3
        var newBytes = original
        newBytes.imageID = UUID(uuidString: "50000000-0000-0000-0000-000000000099")!
        newBytes.imageData = Data([1, 2])
        let added = element(id: other, zIndex: 1)

        #expect(CanvasRecordMapping.changes(from: [original], to: [original]).isEmpty)

        let move = CanvasRecordMapping.changes(from: [original], to: [moved])
        #expect(move.inserted.isEmpty)
        #expect(move.deletedIDs.isEmpty)
        #expect(move.updated.map(\.id) == [id])
        #expect(move.updated.first?.positionX == 9)

        let order = CanvasRecordMapping.changes(from: [original], to: [reordered])
        #expect(order.updated.map(\.zIndex) == [3])

        let bytes = CanvasRecordMapping.changes(from: [original], to: [newBytes])
        #expect(bytes.updated.first?.imageData == Data([1, 2]))

        let insert = CanvasRecordMapping.changes(from: [], to: [added])
        #expect(insert.inserted.map(\.id) == [other])

        let deletion = CanvasRecordMapping.changes(from: [original, added], to: [added])
        #expect(deletion.deletedIDs == [id])
        #expect(deletion.updated.isEmpty)
    }

    @Test func aCommandCommitDiffersAndAPreviewDoesNotAdvanceRevision() {
        let document = CanvasDocument()
        let session = EditingSession(document: document)
        let element = CanvasElement.rectangle(
            position: CanvasPoint(x: 1, y: 2),
            size: CanvasSize(width: 10, height: 10)
        )
        session.commandManager.insert(element)
        let committed = CanvasRecordMapping.state(from: document, imageData: { _ in nil })
        let revision = document.revision

        let edit = session.commandManager.beginCoalescedEdit(actionName: "Move")
        edit.preview { document in
            document.update(element.id) { item in
                item.position = CanvasPoint(x: 40, y: 12)
            }
        }
        #expect(document.revision == revision)
        let duringPreview = CanvasRecordMapping.state(from: document, imageData: { _ in nil })
        #expect(CanvasRecordMapping.changes(from: committed.elements, to: duringPreview.elements).isEmpty == false)
        edit.cancel()
        let restored = CanvasRecordMapping.state(from: document, imageData: { _ in nil })
        #expect(restored == committed)

        session.commandManager.move(element.id, to: CanvasPoint(x: 9, y: 8))
        let moved = CanvasRecordMapping.state(from: document, imageData: { _ in nil })
        let changes = CanvasRecordMapping.changes(from: committed.elements, to: moved.elements)
        #expect(changes.inserted.isEmpty)
        #expect(changes.deletedIDs.isEmpty)
        #expect(changes.updated.count == 1)
        #expect(changes.updated.first?.positionX == 9)
        #expect(changes.updated.first?.positionY == 8)

        session.commandManager.undo()
        let undone = CanvasRecordMapping.state(from: document, imageData: { _ in nil })
        #expect(undone == committed)
        #expect(document.revision != revision)
    }

    @Test func unknownTypeAndCorruptBlobsFailTheLoad() {
        var badType = element(id: UUID(), zIndex: 0)
        badType.typeRaw = "blob"
        expectMappingError(.unknownElementType("blob"), state: state(with: badType))

        var badText = element(id: UUID(), zIndex: 0)
        badText.textJSON = Data("not-json".utf8)
        expectMappingError(.corruptBlob, state: state(with: badText))

        var badChildren = element(id: UUID(), zIndex: 0)
        badChildren.childIDsJSON = Data("{".utf8)
        expectMappingError(.corruptBlob, state: state(with: badChildren))
    }

    @Test func unknownTextFieldsFailTheLoad() throws {
        let document = CanvasDocument(elements: [
            CanvasElement.text("Hello"),
        ])
        var record = CanvasRecordMapping.state(from: document, imageData: { _ in nil }).elements[0]
        let blob = try JSONDecoder().decode(EditableTextBlob.self, from: record.textJSON!)
        var weight = blob
        weight.fontWeight = "book"
        record.textJSON = try JSONEncoder().encode(weight)
        expectMappingError(.unknownFontWeight("book"), state: state(with: record))

        var alignment = blob
        alignment.alignment = "justified"
        record.textJSON = try JSONEncoder().encode(alignment)
        expectMappingError(.unknownTextAlignment("justified"), state: state(with: record))
    }

    @Test func deletingAnElementIsADeletionAndKeepsTheImageIdOnRedo() {
        let session = EditingSession()
        let ref = ImageRef()
        let bytes = Data([9, 8, 7])
        let element = CanvasElement.image(ref, size: CanvasSize(width: 12, height: 8))
        session.imageStore.store(bytes, for: ref.id)
        session.commandManager.insert(element)
        let withImage = CanvasRecordMapping.state(from: session.document) { id in
            session.imageStore.data(for: id)
        }
        #expect(withImage.elements.first?.imageID == ref.id)
        #expect(withImage.elements.first?.imageData == bytes)

        session.commandManager.undo()
        let removed = CanvasRecordMapping.state(from: session.document, imageData: { _ in nil })
        let deletion = CanvasRecordMapping.changes(from: withImage.elements, to: removed.elements)
        #expect(deletion.deletedIDs == [element.id])
        #expect(session.imageStore.data(for: ref.id) == bytes)

        session.commandManager.redo()
        let restored = CanvasRecordMapping.state(from: session.document) { id in
            session.imageStore.data(for: id)
        }
        #expect(restored.elements.first?.imageID == ref.id)
        #expect(restored.elements.first?.imageData == bytes)
    }

    private func element(id: UUID, zIndex: Int) -> PersistedElement {
        PersistedElement(
            id: id,
            zIndex: zIndex,
            typeRaw: CanvasElementType.rectangle.rawValue,
            positionX: 0,
            positionY: 0,
            width: 10,
            height: 10,
            rotationDegrees: 0,
            opacity: 1,
            cornerRadius: 0,
            parentID: nil,
            childIDsJSON: Data("[]".utf8),
            textJSON: nil,
            fillJSON: nil,
            strokeJSON: nil,
            imageID: nil,
            imageData: nil
        )
    }

    private func state(with element: PersistedElement) -> PersistedCanvasState {
        PersistedCanvasState(
            canvasWidth: 1,
            canvasHeight: 1,
            backgroundRed: 1,
            backgroundGreen: 1,
            backgroundBlue: 1,
            backgroundAlpha: 1,
            elements: [element]
        )
    }

    private func expectMappingError(
        _ expected: CanvasRecordMappingError,
        state: PersistedCanvasState
    ) {
        do {
            _ = try CanvasRecordMapping.makeDocument(id: UUID(), from: state)
            Issue.record("Expected \(expected)")
        } catch let error as CanvasRecordMappingError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }
}

/// Mirrors the text blob so a test can replace one field. Keys match the encoder's names.
private struct EditableTextBlob: Codable {
    var alignment: String
    var alpha: Double
    var blue: Double
    var fontName: String
    var fontSize: Double
    var fontWeight: String
    var green: Double
    var red: Double
    var string: String
}

@Suite("Project list ordering")
struct ProjectListOrderingTests {
    private struct Item: Equatable {
        var id: UUID
        var opened: Date?
        var created: Date
    }

    @Test func recentsPutTheLatestOpenFirstAndNeverOpenedLast() {
        let newest = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000003")!,
            opened: Date(timeIntervalSince1970: 30),
            created: Date(timeIntervalSince1970: 1)
        )
        let older = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000002")!,
            opened: Date(timeIntervalSince1970: 20),
            created: Date(timeIntervalSince1970: 2)
        )
        let never = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
            opened: nil,
            created: Date(timeIntervalSince1970: 100)
        )
        let ordered = ProjectListOrdering.recentsFirst(
            [never, older, newest],
            id: \.id,
            lastOpenedAt: \.opened,
            createdAt: \.created
        )
        #expect(ordered.map(\.id) == [newest.id, older.id, never.id])
    }

    @Test func tiesFallBackToCreatedAtThenIdentifier() {
        let sharedOpen = Date(timeIntervalSince1970: 50)
        let laterCreated = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-00000000000B")!,
            opened: sharedOpen,
            created: Date(timeIntervalSince1970: 8)
        )
        let earlierCreated = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-00000000000A")!,
            opened: sharedOpen,
            created: Date(timeIntervalSince1970: 4)
        )
        let sameCreatedHighID = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-00000000000D")!,
            opened: nil,
            created: Date(timeIntervalSince1970: 1)
        )
        let sameCreatedLowID = Item(
            id: UUID(uuidString: "60000000-0000-0000-0000-00000000000C")!,
            opened: nil,
            created: Date(timeIntervalSince1970: 1)
        )
        let ordered = ProjectListOrdering.recentsFirst(
            [earlierCreated, laterCreated, sameCreatedHighID, sameCreatedLowID],
            id: \.id,
            lastOpenedAt: \.opened,
            createdAt: \.created
        )
        #expect(ordered.map(\.id) == [
            laterCreated.id,
            earlierCreated.id,
            sameCreatedLowID.id,
            sameCreatedHighID.id,
        ])
    }
}
