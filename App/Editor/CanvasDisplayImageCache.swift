import CanvasModel
import UIKit

/// Decoded images for one editing session.
///
/// The canvas reads a `UIImage` it already holds. Decoding happens when an image
/// arrives, not inside a view body, so a 120 Hz drag does not decode again.
@MainActor
final class CanvasDisplayImageCache {
    private var images: [UUID: UIImage] = [:]
    private var failed: Set<UUID> = []

    var undecodableIDs: [UUID] {
        failed.sorted { $0.uuidString < $1.uuidString }
    }

    func image(for id: UUID?) -> UIImage? {
        guard let id else { return nil }
        return images[id]
    }

    @discardableResult
    func prepare(id: UUID, data: Data) -> UIImage? {
        if data.isEmpty {
            images.removeValue(forKey: id)
            failed.insert(id)
            return nil
        }
        guard let image = UIImage(data: data) else {
            images.removeValue(forKey: id)
            failed.insert(id)
            return nil
        }
        failed.remove(id)
        images[id] = image
        return image
    }

    func store(_ image: UIImage, for id: UUID) {
        failed.remove(id)
        images[id] = image
    }
}

@MainActor
enum CanvasImagePreparation {
    struct Prepared {
        var data: Data
        var pixelWidth: Double
        var pixelHeight: Double
        var image: UIImage
    }

    static func prepare(_ data: Data) -> Result<Prepared, CanvasImageProblem> {
        guard !data.isEmpty else { return .failure(.empty) }
        guard let image = UIImage(data: data) else { return .failure(.undecodable) }
        return .success(
            Prepared(
                data: data,
                pixelWidth: Double(image.size.width),
                pixelHeight: Double(image.size.height),
                image: image
            )
        )
    }
}
