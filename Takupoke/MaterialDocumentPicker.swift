import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// A background anchor presents the picker directly. SwiftUI's sheet must not
/// replace its custom presentation, and the picker must not become a child VC.
struct MaterialDocumentPicker<Item: Identifiable>: UIViewControllerRepresentable {
    @Binding var item: Item?
    var type: (Item) -> UTType
    var instruction: (Item) -> String
    var selected: (Item, ScopedMaterialSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> MaterialPickerAnchor {
        let anchor = MaterialPickerAnchor()
        context.coordinator.anchor = anchor
        anchor.appeared = { [weak coordinator = context.coordinator] in coordinator?.synchronize() }
        return anchor
    }

    func updateUIViewController(_ controller: MaterialPickerAnchor, context: Context) {
        context.coordinator.parent = self
        // Binding changes and presentation happen after SwiftUI's update pass.
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in coordinator?.synchronize() }
    }

    static func dismantleUIViewController(_ controller: MaterialPickerAnchor, coordinator: Coordinator) {
        controller.appeared = nil
        coordinator.stop()
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate, UIViewControllerTransitioningDelegate {
        var parent: MaterialDocumentPicker
        weak var anchor: MaterialPickerAnchor?
        private var picker: UIDocumentPickerViewController?
        private var activeItem: Item?
        private var stopped = false

        init(parent: MaterialDocumentPicker) { self.parent = parent }

        func synchronize() {
            guard !stopped else { return }
            guard let item = parent.item else {
                if let picker, !picker.isBeingDismissed { picker.dismiss(animated: true) }
                activeItem = nil
                picker = nil
                return
            }
            guard picker == nil, let anchor, anchor.viewIfLoaded?.window != nil,
                  anchor.presentedViewController == nil else { return }
            let controller = UIDocumentPickerViewController(forOpeningContentTypes: [parent.type(item)], asCopy: false)
            controller.allowsMultipleSelection = false
            controller.delegate = self
            controller.modalPresentationStyle = .custom
            controller.transitioningDelegate = self
            activeItem = item
            picker = controller
            anchor.present(controller, animated: true)
        }

        func stop() {
            stopped = true
            activeItem = nil
            picker?.delegate = nil
            picker?.dismiss(animated: false)
            picker = nil
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard controller === picker, let item = activeItem, !stopped else { return }
            // Start security-scoped access inside the selection callback.
            let selection = urls.first.map { ScopedMaterialSelection($0) }
            activeItem = nil
            picker = nil
            parent.item = nil
            if let selection { parent.selected(item, selection) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard controller === picker, !stopped else { return }
            cancel()
        }

        private func cancel() {
            activeItem = nil
            let controller = picker
            picker = nil
            parent.item = nil
            if controller?.isBeingDismissed == false { controller?.dismiss(animated: true) }
        }

        func presentationController(forPresented presented: UIViewController,
                                    presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
            guard let picker = presented as? UIDocumentPickerViewController, let activeItem else { return nil }
            return GuidedDocumentPicker(picker: picker, presenting: presenting,
                instruction: parent.instruction(activeItem), cancel: { [weak self] in self?.cancel() })
        }

        func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                 source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            MaterialPickerTransition(presenting: true)
        }

        func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            MaterialPickerTransition(presenting: false)
        }
    }
}

final class MaterialPickerAnchor: UIViewController {
    var appeared: (() -> Void)?
    override func loadView() { view = UIView(); view.backgroundColor = .clear }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); appeared?() }
}
