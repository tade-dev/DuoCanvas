import Foundation

/// Document mutations for group, ungroup, delete, and multi-element move.
///
/// Callers that need one undo step wrap these in a command. Calling them directly changes
/// the document and advances `revision` once per insert, update, or removal.
@MainActor
public enum CanvasEditing {
    /// Groups the roots of `ids`. Returns nil when fewer than two members remain.
    ///
    /// The group frame is the union of the members' unrotated frames. Children keep their
    /// positions. A member that already belonged to another group leaves that group.
    /// The new group is inserted just in front of its front-most member.
    @discardableResult
    public static func group(
        _ ids: [CanvasElement.ID],
        in document: CanvasDocument,
        groupID: CanvasElement.ID = UUID()
    ) -> CanvasElement.ID? {
        let members = CanvasStructure.roots(
            among: ids,
            order: document.order,
            elements: document.elements
        )
        guard members.count >= 2, document.element(groupID) == nil else { return nil }
        guard let frame = CanvasStructure.unionFrame(of: members, elements: document.elements) else {
            return nil
        }

        for member in members {
            detach(member, in: document)
        }
        for member in members {
            document.update(member) { element in
                element.parentID = groupID
            }
        }
        let frontmost = members.compactMap { document.zIndex(of: $0) }.max() ?? (document.order.count - 1)
        let group = CanvasElement.group(
            id: groupID,
            childIDs: members,
            position: frame.origin,
            size: frame.size
        )
        document.insert(group, at: frontmost + 1)
        return groupID
    }

    /// Dissolves every group in `ids`. Nested groups stay groups unless they are listed too.
    ///
    /// Released children keep their place and take the removed group's parent.
    /// The returned ids are those children that are still in the document, back to front.
    @discardableResult
    public static func ungroup(
        _ ids: [CanvasElement.ID],
        in document: CanvasDocument
    ) -> [CanvasElement.ID] {
        let groups = ids.filter { document.element($0)?.type == .group }
        let deepestFirst = groups.sorted { depth(of: $0, in: document) > depth(of: $1, in: document) }
        var released: [CanvasElement.ID] = []
        for groupID in deepestFirst {
            released.append(contentsOf: ungroupOne(groupID, in: document))
        }
        let stillThere = Set(released.filter { document.element($0) != nil })
        return document.order.filter { stillThere.contains($0) }
    }

    /// Removes the roots of `ids` and their descendants.
    ///
    /// A child deleted out of a group is taken off that group's `childIDs`. Deleting a group
    /// deletes its contents as well.
    public static func remove(_ ids: [CanvasElement.ID], from document: CanvasDocument) {
        let roots = CanvasStructure.roots(
            among: ids,
            order: document.order,
            elements: document.elements
        )
        var removing = Set<CanvasElement.ID>()
        for root in roots {
            removing.insert(root)
            removing.formUnion(CanvasStructure.descendants(of: root, in: document.elements))
        }
        guard !removing.isEmpty else { return }

        var parents = Set<CanvasElement.ID>()
        for id in removing {
            if let parent = document.element(id)?.parentID, !removing.contains(parent) {
                parents.insert(parent)
            }
        }
        for parent in parents {
            document.update(parent) { element in
                element.childIDs.removeAll { removing.contains($0) }
            }
        }
        for id in document.order where removing.contains(id) {
            document.remove(id: id)
        }
    }

    /// Moves each root in `ids` and that root's descendants by `delta`.
    public static func translate(
        _ ids: [CanvasElement.ID],
        by delta: CanvasPoint,
        in document: CanvasDocument
    ) {
        guard delta.x != 0 || delta.y != 0 else { return }
        let targets = CanvasStructure.translationTargets(
            among: ids,
            order: document.order,
            elements: document.elements
        )
        for id in targets {
            document.update(id) { element in
                element.position.x += delta.x
                element.position.y += delta.y
            }
        }
    }

    private static func detach(_ id: CanvasElement.ID, in document: CanvasDocument) {
        guard let parentID = document.element(id)?.parentID else { return }
        document.update(parentID) { parent in
            parent.childIDs.removeAll { $0 == id }
        }
        document.update(id) { element in
            element.parentID = nil
        }
    }

    private static func ungroupOne(
        _ groupID: CanvasElement.ID,
        in document: CanvasDocument
    ) -> [CanvasElement.ID] {
        guard let group = document.element(groupID), group.type == .group else { return [] }
        let children = group.childIDs.filter { document.element($0) != nil }
        let parentID = group.parentID
        if let parentID {
            document.update(parentID) { parent in
                guard let index = parent.childIDs.firstIndex(of: groupID) else { return }
                var childIDs = parent.childIDs
                childIDs.remove(at: index)
                childIDs.insert(contentsOf: children, at: index)
                parent.childIDs = childIDs
            }
        }
        for child in children {
            document.update(child) { element in
                element.parentID = parentID
            }
        }
        document.remove(id: groupID)
        return children
    }

    private static func depth(of id: CanvasElement.ID, in document: CanvasDocument) -> Int {
        var depth = 0
        var current = document.element(id)?.parentID
        var seen = Set<CanvasElement.ID>()
        while let parent = current, seen.insert(parent).inserted {
            depth += 1
            current = document.element(parent)?.parentID
        }
        return depth
    }
}
