import Foundation

/// Copy for the three empty screens. Views present it; they do not invent the sentences.
public enum CanvasEmptyCopy {
    public static let homeTitle = "No Projects"
    public static let homeMessage = "Create a project to start a canvas."
    public static let homeAction = "New Project"

    public static let canvasTitle = "Empty Canvas"
    public static let canvasMessage = "Add a shape to start."
    public static let canvasAction = "Add Rectangle"

    public static let inspectorTitle = "No Selection"
    public static let inspectorMessage = "Select an element to edit it."
    public static let inspectorAction = "Add Rectangle"

    /// Drawn in place of image bytes that are missing or cannot be decoded.
    public static let imageUnavailable = "Image unavailable"
}

public enum CanvasImageProblem: Equatable, Sendable, Error {
    case empty
    case undecodable
    case missingFromProject

    public var message: String {
        switch self {
        case .empty:
            "The selected image had no data."
        case .undecodable:
            "That image could not be read."
        case .missingFromProject:
            "An image on this canvas has no stored data."
        }
    }
}

public enum CanvasImageAudit {
    /// Image elements whose bytes are absent. An image element with no `ImageRef` counts too.
    public static func missingIDs(
        in elements: [CanvasElement],
        hasData: (UUID) -> Bool
    ) -> [UUID] {
        elements.compactMap { element in
            guard element.type == .image else { return nil }
            guard let id = element.image?.id else { return element.id }
            return hasData(id) ? nil : id
        }
    }

    public static func notDrawnMessage(count: Int) -> String {
        switch count {
        case 0:
            ""
        case 1:
            "An image on this canvas could not be drawn."
        default:
            "\(count) images on this canvas could not be drawn."
        }
    }
}

public enum CanvasExportProblem: Equatable, Sendable, Error {
    case invalidCanvasSize
    case renderFailed

    public var message: String {
        switch self {
        case .invalidCanvasSize:
            "This page has no size, so it can't be exported."
        case .renderFailed:
            "The page could not be rendered as a PNG."
        }
    }
}

public enum CanvasExportCheck {
    /// A page needs a positive width and height before `ImageRenderer` is asked to draw it.
    public static func problem(width: Double, height: Double) -> CanvasExportProblem? {
        guard width > 0, height > 0, width.isFinite, height.isFinite else {
            return .invalidCanvasSize
        }
        return nil
    }
}

/// Sentences for failures that are not specific to one element.
public enum CanvasFailureCopy {
    public static let projectSave = "The last edit is still on the canvas, but it was not written to this project."
    public static let projectMismatch = "This canvas does not belong to the open project, so the edit was not written."
    public static let projectNotReady = "This project was not finished opening, so the edit was not written."
    public static let projectMissing = "This project is no longer on this device."
    public static let projectOpenGeneric = "This project could not be opened."
    public static let libraryUpdate = "The project list could not be updated."
    public static let storeOpen = "Projects could not be opened on this device."
}
