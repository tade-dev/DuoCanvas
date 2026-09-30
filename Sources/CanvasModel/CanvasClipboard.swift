import Foundation

/// Image bytes carried with a copy. Keyed by `ImageRef` id so the element id can change on paste.
public struct CanvasImageBlob: Equatable, Hashable, Sendable, Codable {
    public var id: UUID
    public var data: Data

    public init(id: UUID, data: Data) {
        self.id = id
        self.data = data
    }
}

/// Elements copied out of a document, back to front, plus the image bytes they draw.
///
/// The payload is Codable so the app can hand it to Transferable. The package does not
/// touch the pasteboard. Parents outside the copied set are cleared, so a pasted child
/// does not stay inside a group that was not copied.
public struct CanvasClipboard: Equatable, Sendable, Codable {
    public var elements: [CanvasElement]
    public var images: [CanvasImageBlob]

    public init(elements: [CanvasElement], images: [CanvasImageBlob] = []) {
        self.elements = elements
        self.images = images
    }

    public static func capture(
        ids: [CanvasElement.ID],
        order: [CanvasElement.ID],
        elements: [CanvasElement.ID: CanvasElement],
        imageData: (UUID) -> Data?
    ) -> CanvasClipboard {
        let roots = CanvasStructure.roots(among: ids, order: order, elements: elements)
        var include = Set<CanvasElement.ID>()
        for root in roots {
            include.insert(root)
            include.formUnion(CanvasStructure.descendants(of: root, in: elements))
        }
        let captured: [CanvasElement] = order.compactMap { id in
            guard include.contains(id), var element = elements[id] else { return nil }
            if let parent = element.parentID, !include.contains(parent) {
                element.parentID = nil
            }
            element.childIDs = element.childIDs.filter { include.contains($0) }
            return element
        }
        var images: [CanvasImageBlob] = []
        var seenImages = Set<UUID>()
        for element in captured {
            guard let imageID = element.image?.id, seenImages.insert(imageID).inserted else { continue }
            if let data = imageData(imageID) {
                images.append(CanvasImageBlob(id: imageID, data: data))
            }
        }
        return CanvasClipboard(elements: captured, images: images)
    }
}

/// New ids and a position offset for duplicate and paste.
public struct RetargetedElements: Equatable, Sendable {
    public var elements: [CanvasElement]
    /// Old id to the id used on the copy.
    public var idMap: [CanvasElement.ID: CanvasElement.ID]

    public init(elements: [CanvasElement], idMap: [CanvasElement.ID: CanvasElement.ID]) {
        self.elements = elements
        self.idMap = idMap
    }

    public static let none = RetargetedElements(elements: [], idMap: [:])
}

public enum CanvasDuplication {
    /// How far a duplicate or the first paste sits from the source, in canvas points.
    public static let offset = CanvasPoint(x: 16, y: 16)

    public static func copies(
        of ids: [CanvasElement.ID],
        order: [CanvasElement.ID],
        elements: [CanvasElement.ID: CanvasElement],
        offset: CanvasPoint = CanvasDuplication.offset,
        makeID: () -> UUID
    ) -> RetargetedElements {
        let captured = CanvasClipboard.capture(
            ids: ids,
            order: order,
            elements: elements,
            imageData: { _ in nil }
        )
        return retarget(captured.elements, offset: offset, makeID: makeID)
    }

    /// Copies `elements` in the same order. `ImageRef` ids stay put so the bytes still match.
    public static func retarget(
        _ elements: [CanvasElement],
        offset: CanvasPoint,
        makeID: () -> UUID
    ) -> RetargetedElements {
        var idMap: [CanvasElement.ID: CanvasElement.ID] = [:]
        idMap.reserveCapacity(elements.count)
        for element in elements {
            idMap[element.id] = makeID()
        }
        let copies = elements.map { element in
            var copy = element
            copy.id = idMap[element.id] ?? makeID()
            copy.position.x += offset.x
            copy.position.y += offset.y
            if let parent = element.parentID, let mapped = idMap[parent] {
                copy.parentID = mapped
            } else {
                copy.parentID = nil
            }
            copy.childIDs = element.childIDs.compactMap { idMap[$0] }
            return copy
        }
        return RetargetedElements(elements: copies, idMap: idMap)
    }
}
