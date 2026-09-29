import CanvasModel
import Foundation

/// Maps a `CanvasDocument` to flat element fields and back.
///
/// `zIndex` is the index in `order` (0 is the back). Nothing else defines that order.
/// Image bytes are copied through `imageData` and the `ImageRef` id is left unchanged.
@MainActor
public enum CanvasRecordMapping {
    public static func state(
        from document: CanvasDocument,
        imageData: (UUID) -> Data?
    ) -> PersistedCanvasState {
        let background = document.canvasConfig.background
        let elements = document.orderedElements.enumerated().map { index, element in
            persisted(element, zIndex: index, imageData: imageData)
        }
        return PersistedCanvasState(
            canvasWidth: document.canvasConfig.size.width,
            canvasHeight: document.canvasConfig.size.height,
            backgroundRed: background.red,
            backgroundGreen: background.green,
            backgroundBlue: background.blue,
            backgroundAlpha: background.alpha,
            elements: elements
        )
    }

    /// Builds a document whose id is `id`. Element order follows `zIndex`.
    /// The returned image map is keyed by `ImageRef` id.
    public static func makeDocument(id: UUID, from state: PersistedCanvasState) throws -> LoadedCanvas {
        let sorted = state.elements.sorted { lhs, rhs in
            if lhs.zIndex != rhs.zIndex { return lhs.zIndex < rhs.zIndex }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        var images: [UUID: Data] = [:]
        var elements: [CanvasElement] = []
        elements.reserveCapacity(sorted.count)
        for record in sorted {
            let element = try element(from: record)
            elements.append(element)
            if let imageID = record.imageID, let data = record.imageData {
                images[imageID] = data
            }
        }
        let document = CanvasDocument(
            id: id,
            canvasConfig: CanvasConfig(
                size: CanvasSize(width: state.canvasWidth, height: state.canvasHeight),
                background: CanvasColor(
                    red: state.backgroundRed,
                    green: state.backgroundGreen,
                    blue: state.backgroundBlue,
                    alpha: state.backgroundAlpha
                )
            ),
            elements: elements
        )
        return LoadedCanvas(document: document, imageDataByID: images)
    }

    /// Inserts, updates, and deletions from `existing` to `updated`.
    /// Unchanged elements, including unchanged image bytes, are omitted.
    public static func changes(
        from existing: [PersistedElement],
        to updated: [PersistedElement]
    ) -> ElementChangeSet {
        var oldByID: [UUID: PersistedElement] = [:]
        oldByID.reserveCapacity(existing.count)
        for element in existing {
            oldByID[element.id] = element
        }
        var inserted: [PersistedElement] = []
        var updatedRecords: [PersistedElement] = []
        var seen = Set<UUID>()
        seen.reserveCapacity(updated.count)
        for element in updated {
            seen.insert(element.id)
            if let old = oldByID[element.id] {
                if old != element {
                    updatedRecords.append(element)
                }
            } else {
                inserted.append(element)
            }
        }
        let deletedIDs = existing
            .map(\.id)
            .filter { !seen.contains($0) }
            .sorted { $0.uuidString < $1.uuidString }
        return ElementChangeSet(inserted: inserted, updated: updatedRecords, deletedIDs: deletedIDs)
    }

    private static func persisted(
        _ element: CanvasElement,
        zIndex: Int,
        imageData: (UUID) -> Data?
    ) -> PersistedElement {
        let imageID = element.image?.id
        return PersistedElement(
            id: element.id,
            zIndex: zIndex,
            typeRaw: element.type.rawValue,
            positionX: element.position.x,
            positionY: element.position.y,
            width: element.size.width,
            height: element.size.height,
            rotationDegrees: element.rotation.degrees,
            opacity: element.opacity,
            cornerRadius: element.cornerRadius,
            parentID: element.parentID,
            childIDsJSON: encoded(element.childIDs),
            textJSON: element.text.map { encoded(TextBlob($0)) },
            fillJSON: element.fill.map { encoded(PaintBlob($0)) },
            strokeJSON: element.stroke.map { encoded(StrokeBlob($0)) },
            imageID: imageID,
            imageData: imageID.flatMap(imageData)
        )
    }

    private static func element(from record: PersistedElement) throws -> CanvasElement {
        guard let type = CanvasElementType(rawValue: record.typeRaw) else {
            throw CanvasRecordMappingError.unknownElementType(record.typeRaw)
        }
        let text = try record.textJSON.map { try TextBlob.decode($0).attributes() }
        let fill = try record.fillJSON.map { try PaintBlob.decode($0).paint }
        let stroke = try record.strokeJSON.map { try StrokeBlob.decode($0).stroke }
        let childIDs = try decode([UUID].self, from: record.childIDsJSON)
        return CanvasElement(
            id: record.id,
            type: type,
            position: CanvasPoint(x: record.positionX, y: record.positionY),
            size: CanvasSize(width: record.width, height: record.height),
            rotation: CanvasRotation(degrees: record.rotationDegrees),
            opacity: record.opacity,
            fill: fill,
            stroke: stroke,
            cornerRadius: record.cornerRadius,
            text: text,
            image: record.imageID.map { ImageRef(id: $0) },
            parentID: record.parentID,
            childIDs: childIDs
        )
    }

    private static func encoded<T: Encodable>(_ value: T) -> Data {
        do {
            return try encoder.encode(value)
        } catch {
            preconditionFailure("Persistence blob encoding failed: \(error)")
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw CanvasRecordMappingError.corruptBlob
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()
}

@MainActor
public struct LoadedCanvas {
    public var document: CanvasDocument
    public var imageDataByID: [UUID: Data]

    public init(document: CanvasDocument, imageDataByID: [UUID: Data]) {
        self.document = document
        self.imageDataByID = imageDataByID
    }
}

private struct TextBlob: Codable, Equatable {
    var string: String
    var fontName: String
    var fontSize: Double
    var fontWeight: String
    var alignment: String
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ text: TextAttributes) {
        string = text.string
        fontName = text.fontName
        fontSize = text.fontSize
        fontWeight = text.fontWeight.rawValue
        alignment = text.alignment.rawValue
        red = text.color.red
        green = text.color.green
        blue = text.color.blue
        alpha = text.color.alpha
    }

    static func decode(_ data: Data) throws -> TextBlob {
        do {
            return try JSONDecoder().decode(TextBlob.self, from: data)
        } catch {
            throw CanvasRecordMappingError.corruptBlob
        }
    }

    func attributes() throws -> TextAttributes {
        guard let weight = CanvasFontWeight(rawValue: fontWeight) else {
            throw CanvasRecordMappingError.unknownFontWeight(fontWeight)
        }
        guard let textAlignment = CanvasTextAlignment(rawValue: alignment) else {
            throw CanvasRecordMappingError.unknownTextAlignment(alignment)
        }
        return TextAttributes(
            string: string,
            fontName: fontName,
            fontSize: fontSize,
            fontWeight: weight,
            alignment: textAlignment,
            color: CanvasColor(red: red, green: green, blue: blue, alpha: alpha)
        )
    }
}

private struct PaintBlob: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(_ paint: Paint) {
        red = paint.color.red
        green = paint.color.green
        blue = paint.color.blue
        alpha = paint.color.alpha
    }

    static func decode(_ data: Data) throws -> PaintBlob {
        do {
            return try JSONDecoder().decode(PaintBlob.self, from: data)
        } catch {
            throw CanvasRecordMappingError.corruptBlob
        }
    }

    var paint: Paint {
        Paint(color: CanvasColor(red: red, green: green, blue: blue, alpha: alpha))
    }
}

private struct StrokeBlob: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    var width: Double

    init(_ stroke: Stroke) {
        red = stroke.color.red
        green = stroke.color.green
        blue = stroke.color.blue
        alpha = stroke.color.alpha
        width = stroke.width
    }

    static func decode(_ data: Data) throws -> StrokeBlob {
        do {
            return try JSONDecoder().decode(StrokeBlob.self, from: data)
        } catch {
            throw CanvasRecordMappingError.corruptBlob
        }
    }

    var stroke: Stroke {
        Stroke(color: CanvasColor(red: red, green: green, blue: blue, alpha: alpha), width: width)
    }
}
