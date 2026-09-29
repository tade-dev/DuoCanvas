import CanvasModel
import SwiftUI

extension CanvasSizeClass {
    init(_ sizeClass: UserInterfaceSizeClass?) {
        switch sizeClass {
        case .regular:
            self = .regular
        case .compact:
            self = .compact
        case nil:
            self = .unspecified
        @unknown default:
            self = .unspecified
        }
    }
}
