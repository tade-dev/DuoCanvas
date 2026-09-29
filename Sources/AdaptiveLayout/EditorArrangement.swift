import CanvasModel

/// How the editor presents the canvas and the inspector.
///
/// Regular width uses a split: the canvas and the inspector sit side by side when the
/// container is wider than it is tall, and the canvas stacks above the inspector when
/// the container is taller. Compact width, and a size class that has not been reported
/// yet, keep the canvas full width and present the inspector as a sheet.
public enum EditorArrangement: String, Equatable, Sendable {
    case split
    case sheet

    public static func forHorizontalSizeClass(_ sizeClass: CanvasSizeClass) -> EditorArrangement {
        switch sizeClass {
        case .regular:
            .split
        case .compact, .unspecified:
            .sheet
        }
    }
}
