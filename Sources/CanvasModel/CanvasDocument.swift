import Foundation
import Observation

public struct CanvasConfig: Equatable, Hashable, Sendable {
    public var size: CanvasSize
    public var background: CanvasColor

    public init(
        size: CanvasSize = .defaultArtboard,
        background: CanvasColor = .white
    ) {
        self.size = size
        self.background = background
    }
}

/// Content used for equality, undo, and coalesced edits. `revision` is not part of the snapshot.
public struct CanvasDocumentSnapshot: Equatable, Sendable {
    public var canvasConfig: CanvasConfig
    public var elements: [CanvasElement.ID: CanvasElement]
    public var order: [CanvasElement.ID]

    public init(
        canvasConfig: CanvasConfig,
        elements: [CanvasElement.ID: CanvasElement],
        order: [CanvasElement.ID]
    ) {
        self.canvasConfig = canvasConfig
        self.elements = elements
        self.order = order
    }
}

/// In-memory canvas. One editing session owns one document.
///
/// `order` is back to front: index 0 is the back-most element and the last index is the front.
/// `revision` advances once per recorded mutation, including undo and redo. It does not advance
/// during a preview. Equality compares content and `id`, not `revision`, so an undo restores an
/// equal document.
@MainActor
@Observable
public final class CanvasDocument: Equatable {
    public let id: UUID
    public private(set) var canvasConfig: CanvasConfig
    public private(set) var elements: [CanvasElement.ID: CanvasElement]
    public private(set) var order: [CanvasElement.ID]
    public private(set) var revision: UInt64

    @ObservationIgnored
    private var recordsRevision = true

    public init(
        id: UUID = UUID(),
        canvasConfig: CanvasConfig = CanvasConfig(),
        elements: [CanvasElement] = []
    ) {
        self.id = id
        self.canvasConfig = canvasConfig
        self.elements = [:]
        self.order = []
        self.revision = 0
        self.recordsRevision = false
        for element in elements {
            insert(element, at: nil)
        }
        self.recordsRevision = true
        self.revision = 0
    }

    /// `Equatable` requires a nonisolated witness. The document is only compared on the main actor.
    public nonisolated static func == (lhs: CanvasDocument, rhs: CanvasDocument) -> Bool {
        MainActor.assumeIsolated {
            lhs.id == rhs.id && lhs.snapshot() == rhs.snapshot()
        }
    }

    public var orderedElements: [CanvasElement] {
        order.compactMap { elements[$0] }
    }

    public func element(_ id: CanvasElement.ID) -> CanvasElement? {
        elements[id]
    }

    public func zIndex(of id: CanvasElement.ID) -> Int? {
        order.firstIndex(of: id)
    }

    public func snapshot() -> CanvasDocumentSnapshot {
        CanvasDocumentSnapshot(
            canvasConfig: canvasConfig,
            elements: elements,
            order: order
        )
    }

    /// A distinct document with the same id and content. Its revision starts at zero.
    public func copy() -> CanvasDocument {
        let copy = CanvasDocument(id: id, canvasConfig: canvasConfig)
        copy.withoutRecordingRevision {
            copy.restoreContent(from: snapshot())
        }
        return copy
    }

    public func setCanvasConfig(_ canvasConfig: CanvasConfig) {
        guard self.canvasConfig != canvasConfig else { return }
        self.canvasConfig = canvasConfig
        recordRevision()
    }

    /// Inserts `element`. Pass `nil` to place it at the front (the end of `order`).
    public func insert(_ element: CanvasElement, at zIndex: Int?) {
        precondition(elements[element.id] == nil, "Duplicate canvas element \(element.id)")
        let index = zIndex ?? order.count
        precondition(
            index >= 0 && index <= order.count,
            "z-index \(index) is outside 0...\(order.count)"
        )
        elements[element.id] = element
        order.insert(element.id, at: index)
        recordRevision()
        assertInvariant()
    }

    @discardableResult
    public func remove(id: CanvasElement.ID) -> CanvasElement? {
        guard let index = order.firstIndex(of: id), let element = elements[id] else {
            return nil
        }
        order.remove(at: index)
        elements.removeValue(forKey: id)
        recordRevision()
        assertInvariant()
        return element
    }

    public func update(_ id: CanvasElement.ID, _ body: (inout CanvasElement) -> Void) {
        guard var element = elements[id] else { return }
        let original = element
        body(&element)
        precondition(element.id == id, "Canvas element ids are stable")
        guard element != original else { return }
        elements[id] = element
        recordRevision()
    }

    public func restoreContent(from snapshot: CanvasDocumentSnapshot) {
        guard self.snapshot() != snapshot else { return }
        canvasConfig = snapshot.canvasConfig
        elements = snapshot.elements
        order = snapshot.order
        recordRevision()
        assertInvariant()
    }

    /// Mutations inside `body` change the live document and do not advance `revision`.
    public func withoutRecordingRevision<T>(_ body: () throws -> T) rethrows -> T {
        let previous = recordsRevision
        recordsRevision = false
        defer { recordsRevision = previous }
        return try body()
    }

    private func recordRevision() {
        guard recordsRevision else { return }
        revision &+= 1
    }

    private func assertInvariant() {
        precondition(
            Set(order) == Set(elements.keys) && order.count == elements.count,
            "Element storage and z-order diverged"
        )
    }
}
