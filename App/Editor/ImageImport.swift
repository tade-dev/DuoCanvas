import CoreTransferable
import UniformTypeIdentifiers

/// Image bytes chosen in the photo picker. The editor keeps them for the session, and a project save writes them with the element.
struct ImportedCanvasImage: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedCanvasImage(data: data)
        }
    }
}
