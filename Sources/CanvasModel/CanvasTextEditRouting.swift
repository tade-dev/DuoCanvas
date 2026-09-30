import Foundation

/// When a finished tap on the canvas should open inline text editing.
///
/// The first tap selects. A later tap on that same text element edits it, which is the
/// touch form of Figma's second click. Shift-tap keeps changing the selection. A shape,
/// a group, or a press that is not on the body does not edit.
public enum CanvasTextEditRouting {
    public static func shouldBeginInlineEdit(
        elementType: CanvasElementType?,
        hitID: CanvasElement.ID?,
        primarySelection: CanvasElement.ID?,
        additive: Bool,
        onBody: Bool
    ) -> Bool {
        guard onBody, !additive, let hitID, hitID == primarySelection else { return false }
        return elementType == .text
    }
}
