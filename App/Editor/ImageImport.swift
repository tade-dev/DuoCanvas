import CoreTransferable
import UniformTypeIdentifiers

/// Image bytes chosen in the photo picker. The editor stores them in the session until persistence exists.
struct ImportedCanvasImage: Transferable {
    var data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedCanvasImage(data: data)
        }
    }
}
