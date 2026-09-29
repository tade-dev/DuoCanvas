import CanvasModel

/// A reversible edit of a canvas document.
///
/// `inverse()` is self-contained: it does not read the document. Apply the inverse to undo,
/// and the inverse of the inverse to redo. The protocol is main-actor isolated because it
/// mutates a main-actor document.
@MainActor
public protocol CanvasCommand {
    var actionName: String { get }
    func apply(to document: CanvasDocument)
    func inverse() -> any CanvasCommand
}
