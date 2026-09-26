import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MaterialDocumentPicker: UIViewControllerRepresentable {
    var type: UTType
    var selected: (ScopedMaterialSelection) -> Void
    var cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [type], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: MaterialDocumentPicker
        init(parent: MaterialDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.selected(ScopedMaterialSelection(url)) } else { parent.cancelled() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.cancelled() }
    }
}
