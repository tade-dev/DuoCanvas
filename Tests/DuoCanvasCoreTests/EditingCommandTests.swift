import CanvasCommands
import CanvasModel
import Foundation
import PersistenceMapping
import Testing

@MainActor
@Suite("Editing commands")
struct EditingCommandTests {
    @Test func duplicateOffsetsACopyAndUndoesAsOneStep() {
        let session = EditingSession()
        let element = CanvasElement.rectangle(
            position: CanvasPoint(x: 10, y: 20),
            size: CanvasSize(width: 30, height: 40)
        )
        let commands = session.commandManager
        commands.insert(element)
        let before = session.document.copy()
        let revision = session.document.revision
        let copyID = UUID()

        let result = commands.duplicate([element.id]) { copyID }
        #expect(commands.undoActionName == "Duplicate")
        #expect(session.document.revision == revision + 1)
        #expect(result.idMap[element.id] == copyID)
        #expect(session.document.order == [element.id, copyID])
        #expect(session.document.element(element.id) == element)
        let copy = session.document.element(copyID)
        #expect(copy?.position == CanvasPoint(x: 26, y: 36))
        #expect(copy?.size == element.size)
        #expect(copy?.type == .rectangle)

        commands.undo()
        #expect(session.document == before)
        commands.redo()
        #expect(session.document.element(copyID)?.position == CanvasPoint(x: 26, y: 36))
    }

    @Test func duplicateOfAGroupCopiesChildrenAndKeepsTheImageRef() {
        let session = EditingSession()
        let imageID = UUID()
        session.imageStore.store(Data([1, 2, 3]), for: imageID)
        let photo = CanvasElement.image(
            ImageRef(id: imageID),
            position: CanvasPoint(x: 4, y: 6),
            size: CanvasSize(width: 20, height: 10)
        )
        let label = CanvasElement.text("Hi", position: CanvasPoint(x: 8, y: 9))
        let commands = session.commandManager
        commands.insert(photo)
        commands.insert(label)
        let groupID = UUID()
        #expect(commands.group([photo.id, label.id], groupID: groupID) == groupID)

        var issued = 0
        let ids = [UUID(), UUID(), UUID()]
        let result = commands.duplicate([groupID]) {
            let id = ids[issued]
            issued += 1
            return id
        }
        #expect(commands.undoActionName == "Duplicate")
        let newGroup = result.idMap[groupID] ?? UUID()
        let newPhoto = result.idMap[photo.id] ?? UUID()
        let newLabel = result.idMap[label.id] ?? UUID()
        #expect(result.idMap[groupID] != nil)
        #expect(session.document.element(newGroup)?.childIDs == [newPhoto, newLabel])
        #expect(session.document.element(newPhoto)?.parentID == newGroup)
        #expect(session.document.element(newPhoto)?.image == ImageRef(id: imageID))
        #expect(session.document.element(newLabel)?.position == CanvasPoint(x: 24, y: 25))
        #expect(session.imageStore.data(for: imageID) == Data([1, 2, 3]))

        let grouped = session.document.copy()
        commands.undo()
        #expect(session.document.element(newGroup) == nil)
        #expect(session.document.element(groupID)?.childIDs == [photo.id, label.id])
        commands.redo()
        #expect(session.document == grouped)
    }

    @Test func duplicateOfNothingRecordsNothing() {
        let session = EditingSession()
        let element = CanvasElement.rectangle()
        session.commandManager.insert(element)
        let before = session.document.copy()
        let result = session.commandManager.duplicate([])
        #expect(result == .none)
        #expect(session.document == before)
        #expect(session.commandManager.undoActionName == "Insert")
    }

    @Test func groupWrapsMembersAndUndoRestoresThem() {
        let session = EditingSession()
        let back = CanvasElement.rectangle(
            position: CanvasPoint(x: 0, y: 10),
            size: CanvasSize(width: 20, height: 20)
        )
        let front = CanvasElement.circle(
            position: CanvasPoint(x: 30, y: 0),
            size: CanvasSize(width: 10, height: 40)
        )
        let outsider = CanvasElement.text("Stay")
        let commands = session.commandManager
        commands.insert(back)
        commands.insert(outsider)
        commands.insert(front)
        let before = session.document.copy()
        let revision = session.document.revision
        let groupID = UUID()

        #expect(commands.group([front.id, back.id], groupID: groupID) == groupID)
        #expect(commands.undoActionName == "Group")
        #expect(session.document.revision == revision + 1)
        #expect(session.document.order == [back.id, outsider.id, front.id, groupID])
        let group = session.document.element(groupID)
        #expect(group?.type == .group)
        #expect(group?.childIDs == [back.id, front.id])
        #expect(group?.position == CanvasPoint(x: 0, y: 0))
        #expect(group?.size == CanvasSize(width: 40, height: 40))
        #expect(session.document.element(back.id)?.parentID == groupID)
        #expect(session.document.element(front.id)?.parentID == groupID)
        #expect(session.document.element(back.id)?.position == back.position)
        #expect(session.document.element(outsider.id)?.parentID == nil)

        commands.undo()
        #expect(session.document == before)
        commands.redo()
        #expect(session.document.element(groupID)?.childIDs == [back.id, front.id])
    }

    @Test func groupingFewerThanTwoMembersRecordsNothing() {
        let session = EditingSession()
        let only = CanvasElement.rectangle()
        session.commandManager.insert(only)
        let before = session.document.copy()
        #expect(session.commandManager.group([only.id]) == nil)
        #expect(session.document == before)
        #expect(session.commandManager.undoActionName == "Insert")
    }

    @Test func groupingAChildPullsItOutOfTheOldGroup() {
        let session = EditingSession()
        let child = CanvasElement.rectangle(position: CanvasPoint(x: 0, y: 0), size: CanvasSize(width: 10, height: 10))
        let sibling = CanvasElement.circle(position: CanvasPoint(x: 20, y: 0), size: CanvasSize(width: 10, height: 10))
        let extra = CanvasElement.text("Extra", position: CanvasPoint(x: 0, y: 40), size: CanvasSize(width: 10, height: 10))
        let commands = session.commandManager
        commands.insert(child)
        commands.insert(sibling)
        let original = UUID()
        #expect(commands.group([child.id, sibling.id], groupID: original) == original)
        commands.insert(extra)

        let created = UUID()
        #expect(commands.group([child.id, extra.id], groupID: created) == created)
        #expect(session.document.element(original)?.childIDs == [sibling.id])
        #expect(session.document.element(child.id)?.parentID == created)
        #expect(session.document.element(extra.id)?.parentID == created)
        #expect(session.document.element(sibling.id)?.parentID == original)

        commands.undo()
        #expect(session.document.element(original)?.childIDs == [child.id, sibling.id])
        #expect(session.document.element(child.id)?.parentID == original)
        #expect(session.document.element(extra.id)?.parentID == nil)
    }

    @Test func ungroupReleasesChildrenAndUndoRestoresTheGroup() {
        let session = EditingSession()
        let left = CanvasElement.rectangle()
        let right = CanvasElement.circle()
        let commands = session.commandManager
        commands.insert(left)
        commands.insert(right)
        let groupID = UUID()
        commands.group([left.id, right.id], groupID: groupID)
        let grouped = session.document.copy()

        let released = commands.ungroup([groupID])
        #expect(commands.undoActionName == "Ungroup")
        #expect(released == [left.id, right.id])
        #expect(session.document.element(groupID) == nil)
        #expect(session.document.element(left.id)?.parentID == nil)
        #expect(session.document.element(right.id)?.parentID == nil)
        #expect(session.document.order == [left.id, right.id])

        commands.undo()
        #expect(session.document == grouped)
        commands.redo()
        #expect(session.document.element(left.id)?.parentID == nil)
    }

    @Test func ungroupLeavesANestedGroupInPlace() {
        let session = EditingSession()
        let a = CanvasElement.rectangle(position: CanvasPoint(x: 0, y: 0), size: CanvasSize(width: 8, height: 8))
        let b = CanvasElement.circle(position: CanvasPoint(x: 10, y: 0), size: CanvasSize(width: 8, height: 8))
        let c = CanvasElement.text("C", position: CanvasPoint(x: 0, y: 20), size: CanvasSize(width: 8, height: 8))
        let commands = session.commandManager
        commands.insert(a)
        commands.insert(b)
        commands.insert(c)
        let inner = UUID()
        let outer = UUID()
        commands.group([a.id, b.id], groupID: inner)
        commands.group([inner, c.id], groupID: outer)

        let released = commands.ungroup([outer])
        #expect(released == [inner, c.id])
        #expect(session.document.element(outer) == nil)
        #expect(session.document.element(inner)?.type == .group)
        #expect(session.document.element(inner)?.parentID == nil)
        #expect(session.document.element(a.id)?.parentID == inner)
        #expect(session.document.element(c.id)?.parentID == nil)
    }

    @Test func deleteRemovesAGroupAndItsChildrenAsOneStep() {
        let session = EditingSession()
        let child = CanvasElement.rectangle()
        let other = CanvasElement.text("Keep")
        let commands = session.commandManager
        commands.insert(child)
        commands.insert(other)
        let groupID = UUID()
        commands.group([child.id, other.id], groupID: groupID)
        commands.insert(CanvasElement.circle())
        let before = session.document.copy()

        commands.delete(groupID)
        #expect(commands.undoActionName == "Delete")
        #expect(session.document.element(groupID) == nil)
        #expect(session.document.element(child.id) == nil)
        #expect(session.document.element(other.id) == nil)
        #expect(session.document.orderedElements.map(\.type) == [.circle])

        commands.undo()
        #expect(session.document == before)
    }

    @Test func deletingAChildUpdatesTheParentList() {
        let session = EditingSession()
        let keep = CanvasElement.rectangle()
        let drop = CanvasElement.circle()
        let commands = session.commandManager
        commands.insert(keep)
        commands.insert(drop)
        let groupID = UUID()
        commands.group([keep.id, drop.id], groupID: groupID)
        let before = session.document.copy()

        commands.delete(drop.id)
        #expect(session.document.element(drop.id) == nil)
        #expect(session.document.element(groupID)?.childIDs == [keep.id])
        #expect(session.document.element(keep.id)?.parentID == groupID)

        commands.undo()
        #expect(session.document == before)
        #expect(session.document.element(groupID)?.childIDs == [keep.id, drop.id])
    }

    @Test func movingAGroupMovesChildrenTogether() {
        let session = EditingSession()
        let child = CanvasElement.rectangle(position: CanvasPoint(x: 5, y: 7), size: CanvasSize(width: 10, height: 10))
        let sibling = CanvasElement.circle(position: CanvasPoint(x: 20, y: 9), size: CanvasSize(width: 4, height: 4))
        let commands = session.commandManager
        commands.insert(child)
        commands.insert(sibling)
        let groupID = UUID()
        commands.group([child.id, sibling.id], groupID: groupID)
        let before = session.document.copy()
        let revision = session.document.revision

        commands.move(groupID, to: CanvasPoint(x: 10, y: 4))
        #expect(commands.undoActionName == "Move")
        #expect(session.document.revision == revision + 1)
        #expect(session.document.element(groupID)?.position == CanvasPoint(x: 10, y: 4))
        #expect(session.document.element(child.id)?.position == CanvasPoint(x: 10, y: 4))
        #expect(session.document.element(sibling.id)?.position == CanvasPoint(x: 25, y: 6))

        commands.undo()
        #expect(session.document == before)
    }

    @Test func resizingAGroupDoesNotMoveItsChildren() {
        let session = EditingSession()
        let child = CanvasElement.rectangle(position: CanvasPoint(x: 3, y: 4), size: CanvasSize(width: 12, height: 8))
        let sibling = CanvasElement.circle(position: CanvasPoint(x: 18, y: 4), size: CanvasSize(width: 8, height: 8))
        let commands = session.commandManager
        commands.insert(child)
        commands.insert(sibling)
        let groupID = UUID()
        commands.group([child.id, sibling.id], groupID: groupID)

        commands.resize(groupID, to: CanvasSize(width: 50, height: 50))
        #expect(session.document.element(groupID)?.size == CanvasSize(width: 50, height: 50))
        #expect(session.document.element(child.id)?.position == child.position)
        #expect(session.document.element(sibling.id)?.position == sibling.position)
    }

    @Test func translateMovesEveryRootOnce() {
        let session = EditingSession()
        let first = CanvasElement.rectangle(position: CanvasPoint(x: 1, y: 2))
        let second = CanvasElement.circle(position: CanvasPoint(x: 8, y: 9))
        let commands = session.commandManager
        commands.insert(first)
        commands.insert(second)
        let before = session.document.copy()
        let revision = session.document.revision

        commands.translate([first.id, second.id], by: CanvasPoint(x: 3, y: -1))
        #expect(commands.undoActionName == "Move")
        #expect(session.document.revision == revision + 1)
        #expect(session.document.element(first.id)?.position == CanvasPoint(x: 4, y: 1))
        #expect(session.document.element(second.id)?.position == CanvasPoint(x: 11, y: 8))

        commands.undo()
        #expect(session.document == before)
    }

    @Test func translateOfAGroupDoesNotApplyTheDeltaTwice() {
        let session = EditingSession()
        let child = CanvasElement.rectangle(position: CanvasPoint(x: 0, y: 0), size: CanvasSize(width: 5, height: 5))
        let sibling = CanvasElement.circle(position: CanvasPoint(x: 10, y: 0), size: CanvasSize(width: 5, height: 5))
        let commands = session.commandManager
        commands.insert(child)
        commands.insert(sibling)
        let groupID = UUID()
        commands.group([child.id, sibling.id], groupID: groupID)

        commands.translate([groupID, child.id], by: CanvasPoint(x: 2, y: 2))
        #expect(session.document.element(child.id)?.position == CanvasPoint(x: 2, y: 2))
        #expect(session.document.element(groupID)?.position == CanvasPoint(x: 2, y: 2))
    }

    @Test func clipboardRoundTripsAndPasteInsertsNewIds() throws {
        let session = EditingSession()
        let imageID = UUID()
        let bytes = Data([9, 8, 7])
        session.imageStore.store(bytes, for: imageID)
        let photo = CanvasElement.image(ImageRef(id: imageID), position: CanvasPoint(x: 1, y: 1))
        let note = CanvasElement.text("Note", position: CanvasPoint(x: 12, y: 3))
        let commands = session.commandManager
        commands.insert(photo)
        commands.insert(note)
        let clipboard = CanvasClipboard.capture(
            ids: [photo.id, note.id],
            order: session.document.order,
            elements: session.document.elements,
            imageData: { session.imageStore.data(for: $0) }
        )
        let encoded = try JSONEncoder().encode(clipboard)
        let decoded = try JSONDecoder().decode(CanvasClipboard.self, from: encoded)
        #expect(decoded == clipboard)
        #expect(decoded.images == [CanvasImageBlob(id: imageID, data: bytes)])

        let pastedIDs = [UUID(), UUID()]
        var index = 0
        let result = commands.paste(decoded, offset: CanvasPoint(x: 16, y: 16)) {
            let id = pastedIDs[index]
            index += 1
            return id
        }
        #expect(commands.undoActionName == "Paste")
        #expect(result.insertedIDs == pastedIDs)
        #expect(session.document.element(pastedIDs[0])?.image == ImageRef(id: imageID))
        #expect(session.document.element(pastedIDs[0])?.position == CanvasPoint(x: 17, y: 17))
        #expect(session.document.element(pastedIDs[1])?.text?.string == "Note")
        #expect(session.document.element(photo.id)?.position == photo.position)

        let withPaste = session.document.copy()
        commands.undo()
        #expect(session.document.element(pastedIDs[0]) == nil)
        commands.redo()
        #expect(session.document == withPaste)
    }

    @Test func selectionRootIsTheOutermostGroup() {
        let child = CanvasElement.rectangle()
        let inner = CanvasElement.group(childIDs: [child.id])
        var nestedChild = child
        nestedChild.parentID = inner.id
        let outer = CanvasElement.group(childIDs: [inner.id])
        var nestedInner = inner
        nestedInner.parentID = outer.id
        let loose = CanvasElement.circle()
        let elements = [
            nestedChild.id: nestedChild,
            nestedInner.id: nestedInner,
            outer.id: outer,
            loose.id: loose,
        ]
        #expect(CanvasStructure.selectionRoot(of: nestedChild.id, in: elements) == outer.id)
        #expect(CanvasStructure.selectionRoot(of: loose.id, in: elements) == loose.id)
        let order = [nestedChild.id, nestedInner.id, outer.id, loose.id]
        #expect(CanvasStructure.roots(among: [nestedChild.id, loose.id], order: order, elements: elements) == [nestedChild.id, loose.id])
        #expect(CanvasStructure.roots(among: [outer.id, nestedChild.id], order: order, elements: elements) == [outer.id])
    }

    @Test func aGroupedDocumentRoundTripsThroughThePersistenceMapping() throws {
        let session = EditingSession()
        let back = CanvasElement.rectangle(
            position: CanvasPoint(x: 0, y: 0),
            size: CanvasSize(width: 10, height: 10)
        )
        let front = CanvasElement.line(
            from: CanvasPoint(x: 20, y: 5),
            to: CanvasPoint(x: 28, y: 12)
        )
        session.commandManager.insert(back)
        session.commandManager.insert(front)
        let groupID = UUID()
        session.commandManager.group([back.id, front.id], groupID: groupID)

        let state = CanvasRecordMapping.state(from: session.document) { _ in nil }
        let loaded = try CanvasRecordMapping.makeDocument(id: session.document.id, from: state)
        #expect(loaded.document.element(groupID)?.childIDs == [back.id, front.id])
        #expect(loaded.document.element(back.id)?.parentID == groupID)
        #expect(loaded.document.element(front.id)?.parentID == groupID)
        #expect(loaded.document.order == session.document.order)
    }
}
