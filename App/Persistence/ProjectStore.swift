import CanvasModel
import Foundation
import PersistenceMapping
import SwiftData

enum ProjectStoreError: Error {
    case missingProject
}

/// Loads one project into a `CanvasDocument` and writes it back when a command commits.
///
/// Gesture previews do not change `CanvasDocument.revision`, and this store is only asked
/// to save after a commit (or after open edits have been turned into a commit). Each save
/// is one `ModelContext.save()`.
@MainActor
final class ProjectStore {
    let project: ProjectRecord
    private let context: ModelContext
    private var lastState: PersistedCanvasState?
    private(set) var lastErrorMessage: String?

    var projectName: String { project.name }

    init(context: ModelContext, projectID: UUID) throws {
        self.context = context
        self.project = try Self.project(id: projectID, in: context)
    }

    func load() throws -> LoadedCanvas {
        let stored = state(from: project)
        let loaded = try CanvasRecordMapping.makeDocument(id: project.id, from: stored)
        lastState = CanvasRecordMapping.state(from: loaded.document) { id in
            loaded.imageDataByID[id]
        }
        return loaded
    }

    /// Writes the document if it differs from the last successful save.
    func saveCommitted(document: CanvasDocument, images: CanvasImageStore) {
        guard document.id == project.id, let lastState else { return }
        let state = CanvasRecordMapping.state(from: document) { id in
            images.data(for: id)
        }
        let changes = CanvasRecordMapping.changes(from: lastState.elements, to: state.elements)
        let configChanged = canvasDiffers(from: state)
        guard configChanged || !changes.isEmpty else { return }

        if configChanged {
            project.canvasWidth = state.canvasWidth
            project.canvasHeight = state.canvasHeight
            project.backgroundRed = state.backgroundRed
            project.backgroundGreen = state.backgroundGreen
            project.backgroundBlue = state.backgroundBlue
            project.backgroundAlpha = state.backgroundAlpha
        }
        apply(changes)
        project.modifiedAt = Date()
        do {
            try context.save()
            self.lastState = state
            lastErrorMessage = nil
        } catch {
            context.rollback()
            lastErrorMessage = error.localizedDescription
        }
    }

    private func apply(_ changes: ElementChangeSet) {
        var existing: [UUID: ElementRecord] = [:]
        existing.reserveCapacity(project.elements.count)
        for record in project.elements {
            existing[record.id] = record
        }
        for element in changes.inserted {
            let record = makeRecord(element)
            context.insert(record)
            record.project = project
        }
        for element in changes.updated {
            if let record = existing[element.id] {
                apply(element, to: record)
            } else {
                let record = makeRecord(element)
                context.insert(record)
                record.project = project
            }
        }
        for id in changes.deletedIDs {
            if let record = existing[id] {
                context.delete(record)
            }
        }
    }

    private func makeRecord(_ element: PersistedElement) -> ElementRecord {
        ElementRecord(
            id: element.id,
            zIndex: element.zIndex,
            typeRaw: element.typeRaw,
            positionX: element.positionX,
            positionY: element.positionY,
            width: element.width,
            height: element.height,
            rotationDegrees: element.rotationDegrees,
            opacity: element.opacity,
            cornerRadius: element.cornerRadius,
            parentID: element.parentID,
            childIDsJSON: element.childIDsJSON,
            textJSON: element.textJSON,
            fillJSON: element.fillJSON,
            strokeJSON: element.strokeJSON,
            imageID: element.imageID,
            imageData: element.imageData
        )
    }

    private func apply(_ element: PersistedElement, to record: ElementRecord) {
        record.zIndex = element.zIndex
        record.typeRaw = element.typeRaw
        record.positionX = element.positionX
        record.positionY = element.positionY
        record.width = element.width
        record.height = element.height
        record.rotationDegrees = element.rotationDegrees
        record.opacity = element.opacity
        record.cornerRadius = element.cornerRadius
        record.parentID = element.parentID
        record.childIDsJSON = element.childIDsJSON
        record.textJSON = element.textJSON
        record.fillJSON = element.fillJSON
        record.strokeJSON = element.strokeJSON
        record.imageID = element.imageID
        if record.imageData != element.imageData {
            record.imageData = element.imageData
        }
    }

    private func canvasDiffers(from state: PersistedCanvasState) -> Bool {
        project.canvasWidth != state.canvasWidth
            || project.canvasHeight != state.canvasHeight
            || project.backgroundRed != state.backgroundRed
            || project.backgroundGreen != state.backgroundGreen
            || project.backgroundBlue != state.backgroundBlue
            || project.backgroundAlpha != state.backgroundAlpha
    }

    private func state(from project: ProjectRecord) -> PersistedCanvasState {
        let elements = project.elements.map { record in
            PersistedElement(
                id: record.id,
                zIndex: record.zIndex,
                typeRaw: record.typeRaw,
                positionX: record.positionX,
                positionY: record.positionY,
                width: record.width,
                height: record.height,
                rotationDegrees: record.rotationDegrees,
                opacity: record.opacity,
                cornerRadius: record.cornerRadius,
                parentID: record.parentID,
                childIDsJSON: record.childIDsJSON,
                textJSON: record.textJSON,
                fillJSON: record.fillJSON,
                strokeJSON: record.strokeJSON,
                imageID: record.imageID,
                imageData: record.imageData
            )
        }
        return PersistedCanvasState(
            canvasWidth: project.canvasWidth,
            canvasHeight: project.canvasHeight,
            backgroundRed: project.backgroundRed,
            backgroundGreen: project.backgroundGreen,
            backgroundBlue: project.backgroundBlue,
            backgroundAlpha: project.backgroundAlpha,
            elements: elements
        )
    }

    private static func project(id: UUID, in context: ModelContext) throws -> ProjectRecord {
        let identifier = id
        var descriptor = FetchDescriptor<ProjectRecord>(
            predicate: #Predicate { $0.id == identifier }
        )
        descriptor.fetchLimit = 1
        if let project = try context.fetch(descriptor).first {
            return project
        }
        throw ProjectStoreError.missingProject
    }
}
