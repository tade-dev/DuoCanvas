import Foundation
import Observation

/// In-memory image bytes for one editing session.
///
/// `ImageRef` on an element is only an id. This map is what the canvas draws. Opening a
/// project copies bytes in under the same id, and a project save copies them back out.
/// The map is not part of the document snapshot, so undo and redo do not drop bytes:
/// removing the element leaves the id's data in place and a later redo can draw it again.
@MainActor
@Observable
public final class CanvasImageStore {
    public private(set) var dataByID: [UUID: Data] = [:]

    public init() {}

    public func store(_ data: Data, for id: UUID) {
        dataByID[id] = data
    }

    public func data(for id: UUID) -> Data? {
        dataByID[id]
    }
}
