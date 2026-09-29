import Foundation
import SwiftData

/// First persisted schema. Later versions become stages on `DuoCanvasMigrationPlan`.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [ProjectRecord.self, ElementRecord.self]
    }

    @Model
    final class ProjectRecord {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        var modifiedAt: Date
        /// Drives the home recents list. Nil only if a project has never been opened.
        var lastOpenedAt: Date?
        var canvasWidth: Double
        var canvasHeight: Double
        var backgroundRed: Double
        var backgroundGreen: Double
        var backgroundBlue: Double
        var backgroundAlpha: Double
        @Relationship(deleteRule: .cascade, inverse: \ElementRecord.project)
        var elements: [ElementRecord] = []
        /// Reserved for a later thumbnail. Milestone 4 does not generate one.
        @Attribute(.externalStorage) var thumbnail: Data?

        init(
            id: UUID,
            name: String,
            createdAt: Date,
            modifiedAt: Date,
            lastOpenedAt: Date?,
            canvasWidth: Double,
            canvasHeight: Double,
            backgroundRed: Double,
            backgroundGreen: Double,
            backgroundBlue: Double,
            backgroundAlpha: Double,
            thumbnail: Data? = nil
        ) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.modifiedAt = modifiedAt
            self.lastOpenedAt = lastOpenedAt
            self.canvasWidth = canvasWidth
            self.canvasHeight = canvasHeight
            self.backgroundRed = backgroundRed
            self.backgroundGreen = backgroundGreen
            self.backgroundBlue = backgroundBlue
            self.backgroundAlpha = backgroundAlpha
            self.thumbnail = thumbnail
            self.elements = []
        }
    }

    /// One row per canvas element. `zIndex` is the stored order because a relationship has none.
    @Model
    final class ElementRecord {
        @Attribute(.unique) var id: UUID
        var zIndex: Int
        var typeRaw: String
        var positionX: Double
        var positionY: Double
        var width: Double
        var height: Double
        var rotationDegrees: Double
        var opacity: Double
        var cornerRadius: Double
        var parentID: UUID?
        var childIDsJSON: Data
        var textJSON: Data?
        var fillJSON: Data?
        var strokeJSON: Data?
        var imageID: UUID?
        /// Bytes for `imageID`. External storage keeps them out of the row itself.
        @Attribute(.externalStorage) var imageData: Data?
        var project: ProjectRecord?

        init(
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
            imageData: Data?,
            project: ProjectRecord? = nil
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
            self.project = project
        }
    }
}

typealias ProjectRecord = SchemaV1.ProjectRecord
typealias ElementRecord = SchemaV1.ElementRecord

/// No stages yet. The plan exists so the next schema change is an explicit migration.
enum DuoCanvasMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
