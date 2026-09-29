import SwiftUI
import UIKit

/// SwiftUI has no font picker. This presents `UIFontPickerViewController` for the family only,
/// so the weight control stays the source of the face.
struct FontFamilyPicker: UIViewControllerRepresentable {
    var onPick: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIFontPickerViewController {
        let configuration = UIFontPickerViewController.Configuration()
        configuration.includeFaces = false
        let picker = UIFontPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIFontPickerViewController, context: Context) {
        context.coordinator.onPick = onPick
        context.coordinator.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    @MainActor
    final class Coordinator: NSObject, UIFontPickerViewControllerDelegate {
        var onPick: (String) -> Void
        var onCancel: () -> Void

        init(onPick: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func fontPickerViewControllerDidPickFont(_ viewController: UIFontPickerViewController) {
            let font = UIFont(descriptor: viewController.selectedFontDescriptor, size: 12)
            let family = font.familyName.isEmpty ? font.fontName : font.familyName
            onPick(family)
        }

        func fontPickerViewControllerDidCancel(_ viewController: UIFontPickerViewController) {
            onCancel()
        }
    }
}
