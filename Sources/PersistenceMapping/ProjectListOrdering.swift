import Foundation

/// Recents order for the home list.
///
/// A project with a later `lastOpenedAt` comes first. A project that has never been
/// opened comes after every project that has. Ties fall back to `createdAt`, then id.
public enum ProjectListOrdering {
    public static func recentsFirst<T>(
        _ items: [T],
        id: (T) -> UUID,
        lastOpenedAt: (T) -> Date?,
        createdAt: (T) -> Date
    ) -> [T] {
        items.sorted { lhs, rhs in
            comesBefore(
                id: id(lhs),
                lastOpenedAt: lastOpenedAt(lhs),
                createdAt: createdAt(lhs),
                thanID: id(rhs),
                lastOpenedAt: lastOpenedAt(rhs),
                createdAt: createdAt(rhs)
            )
        }
    }

    public static func comesBefore(
        id lhsID: UUID,
        lastOpenedAt lhsOpened: Date?,
        createdAt lhsCreated: Date,
        thanID rhsID: UUID,
        lastOpenedAt rhsOpened: Date?,
        createdAt rhsCreated: Date
    ) -> Bool {
        switch (lhsOpened, rhsOpened) {
        case let (left?, right?) where left != right:
            return left > right
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        default:
            if lhsCreated != rhsCreated {
                return lhsCreated > rhsCreated
            }
            return lhsID.uuidString < rhsID.uuidString
        }
    }
}
