import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct MaterialDocumentPicker: UIViewControllerRepresentable {
    var type: UTType
    var instruction: String
    var selected: (ScopedMaterialSelection) -> Void
    var cancelled: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> GuidedDocumentPicker {
        let picker = GuidedDocumentPicker(forOpeningContentTypes: [type], asCopy: false)
        picker.instruction = instruction
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: GuidedDocumentPicker, context: Context) {}

    static func dismantleUIViewController(_ controller: GuidedDocumentPicker, coordinator: Coordinator) {
        controller.finishGuidance()
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: MaterialDocumentPicker
        init(parent: MaterialDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            (controller as? GuidedDocumentPicker)?.finishGuidance()
            if let url = urls.first { parent.selected(ScopedMaterialSelection(url)) } else { parent.cancelled() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            (controller as? GuidedDocumentPicker)?.finishGuidance()
            parent.cancelled()
        }
    }
}
