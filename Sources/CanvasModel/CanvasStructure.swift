import Foundation

/// Parent and child links on canvas elements.
///
/// `parentID` points at a group. `childIDs` lists that group's direct children, back to front.
/// Queries walk those links and stop if a cycle appears. They do not change the document.
public enum CanvasStructure {
    /// `ids` that are present, in back-to-front `order`, excluding any element whose ancestor is also in the set.
    public static func roots(
        among ids: [CanvasElement.ID],
        order: [CanvasElement.ID],
        elements: [CanvasElement.ID: CanvasElement]
    ) -> [CanvasElement.ID] {
        let wanted = Set(ids)
        let ordered = order.filter { wanted.contains($0) && elements[$0] != nil }
        let missingFromOrder = ids.filter { wanted.contains($0) && elements[$0] != nil && !order.contains($0) }
        return (ordered + missingFromOrder).filter { !hasAncestor(in: wanted, id: $0, elements: elements) }
    }

    /// Direct and nested children of `id`, not including `id`. Order follows `childIDs`.
    public static func descendants(
        of id: CanvasElement.ID,
        in elements: [CanvasElement.ID: CanvasElement]
    ) -> [CanvasElement.ID] {
        var result: [CanvasElement.ID] = []
        var seen: Set<CanvasElement.ID> = [id]
        func walk(_ parent: CanvasElement.ID) {
            for child in elements[parent]?.childIDs ?? [] {
                guard elements[child] != nil, seen.insert(child).inserted else { continue }
                result.append(child)
                walk(child)
            }
        }
        walk(id)
        return result
    }

    /// The outermost group that contains `id`, or `id` when it is not inside a group.
    public static func selectionRoot(
        of id: CanvasElement.ID,
        in elements: [CanvasElement.ID: CanvasElement]
    ) -> CanvasElement.ID {
        var current = id
        var seen: Set<CanvasElement.ID> = []
        while let parent = elements[current]?.parentID,
              elements[parent]?.type == .group,
              seen.insert(parent).inserted {
            current = parent
        }
        return current
    }

    /// Roots in `ids`, plus each root's descendants, with each id once.
    ///
    /// A selected group and one of its children count as the group only, so a move does not
    /// apply the same delta twice.
    public static func translationTargets(
        among ids: [CanvasElement.ID],
        order: [CanvasElement.ID],
        elements: [CanvasElement.ID: CanvasElement]
    ) -> [CanvasElement.ID] {
        var seen = Set<CanvasElement.ID>()
        var targets: [CanvasElement.ID] = []
        for root in roots(among: ids, order: order, elements: elements) {
            if seen.insert(root).inserted {
                targets.append(root)
            }
            for child in descendants(of: root, in: elements) where seen.insert(child).inserted {
                targets.append(child)
            }
        }
        return targets
    }

    /// Axis-aligned union of the elements' unrotated frames. Missing ids are skipped.
    public static func unionFrame(
        of ids: [CanvasElement.ID],
        elements: [CanvasElement.ID: CanvasElement]
    ) -> CanvasRect? {
        var union: CanvasRect?
        for id in ids {
            guard let element = elements[id] else { continue }
            let box = CanvasRect(origin: element.position, size: element.size).standardized
            if let existing = union {
                union = unite(existing, box)
            } else {
                union = box
            }
        }
        return union
    }

    private static func hasAncestor(
        in wanted: Set<CanvasElement.ID>,
        id: CanvasElement.ID,
        elements: [CanvasElement.ID: CanvasElement]
    ) -> Bool {
        var current = elements[id]?.parentID
        var seen = Set<CanvasElement.ID>()
        while let parent = current {
            guard seen.insert(parent).inserted else { return false }
            if wanted.contains(parent) { return true }
            current = elements[parent]?.parentID
        }
        return false
    }

    private static func unite(_ lhs: CanvasRect, _ rhs: CanvasRect) -> CanvasRect {
        let minX = min(lhs.origin.x, rhs.origin.x)
        let minY = min(lhs.origin.y, rhs.origin.y)
        let maxX = max(lhs.origin.x + lhs.size.width, rhs.origin.x + rhs.size.width)
        let maxY = max(lhs.origin.y + lhs.size.height, rhs.origin.y + rhs.size.height)
        return CanvasRect(
            origin: CanvasPoint(x: minX, y: minY),
            size: CanvasSize(width: maxX - minX, height: maxY - minY)
        )
    }
}
