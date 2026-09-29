import Foundation

/// Flat fields for one element, in the shape a project record stores.
///
/// Text, paint, and stroke are JSON blobs. Image bytes travel with the element
/// and keep the same id as `ImageRef`. This type does not know about a database.
public struct PersistedElement: Equatable, Sendable {
    public var id: UUID
    public var zIndex: Int
    public var typeRaw: String
    public var positionX: Double
    public var positionY: Double
    public var width: Double
    public var height: Double
    public var rotationDegrees: Double
    public var opacity: Double
    public var cornerRadius: Double
    public var parentID: UUID?
    /// JSON array of UUID strings. Empty when the element has no children.
    public var childIDsJSON: Data
    public var textJSON: Data?
    public var fillJSON: Data?
    public var strokeJSON: Data?
    public var imageID: UUID?
    public var imageData: Data?

    public init(
        id: UUID,
        zIndex: Int,
        typeRaw: String,
        positionX: Double,
        positionY: Double,
        width: Double,
        height: Double,
        rotationDegrees: Double,
        opacity: Double,
        cornerRadius: Double,
        parentID: UUID?,
        childIDsJSON: Data,
        textJSON: Data?,
        fillJSON: Data?,
        strokeJSON: Data?,
        imageID: UUID?,
        imageData: Data?
    ) {
        self.id = id
        self.zIndex = zIndex
        self.typeRaw = typeRaw
        self.positionX = positionX
        self.positionY = positionY
        self.width = width
        self.height = height
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
        self.cornerRadius = cornerRadius
        self.parentID = parentID
        self.childIDsJSON = childIDsJSON
        self.textJSON = textJSON
        self.fillJSON = fillJSON
        self.strokeJSON = strokeJSON
        self.imageID = imageID
        self.imageData = imageData
    }
}

/// Canvas configuration and elements for one project. Names and dates stay with the record.
public struct PersistedCanvasState: Equatable, Sendable {
    public var canvasWidth: Double
    public var canvasHeight: Double
    public var backgroundRed: Double
    public var backgroundGreen: Double
    public var backgroundBlue: Double
    public var backgroundAlpha: Double
    public var elements: [PersistedElement]

    public init(
        canvasWidth: Double,
        canvasHeight: Double,
        backgroundRed: Double,
        backgroundGreen: Double,
        backgroundBlue: Double,
        backgroundAlpha: Double,
        elements: [PersistedElement]
    ) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.backgroundRed = backgroundRed
        self.backgroundGreen = backgroundGreen
        self.backgroundBlue = backgroundBlue
        self.backgroundAlpha = backgroundAlpha
        self.elements = elements
    }
}

/// What changed between two element lists. The caller writes these, then saves once.
public struct ElementChangeSet: Equatable, Sendable {
    public var inserted: [PersistedElement]
    public var updated: [PersistedElement]
    public var deletedIDs: [UUID]

    public init(inserted: [PersistedElement], updated: [PersistedElement], deletedIDs: [UUID]) {
        self.inserted = inserted
        self.updated = updated
        self.deletedIDs = deletedIDs
    }

    public var isEmpty: Bool {
        inserted.isEmpty && updated.isEmpty && deletedIDs.isEmpty
    }
}

public enum CanvasRecordMappingError: Error, Equatable, Sendable {
    case unknownElementType(String)
    case unknownFontWeight(String)
    case unknownTextAlignment(String)
    case corruptBlob
}
