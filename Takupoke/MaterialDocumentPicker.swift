import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// The standard picker stays modal. A pending request survives a temporarily
/// unavailable presenter; native results are tracked separately from animation.
struct MaterialDocumentPicker<Item: Identifiable>: UIViewControllerRepresentable {
    @Binding var item: Item?
    var type: (Item) -> UTType
    var instruction: (Item) -> String
    var selected: (Item, ScopedMaterialSelection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> MaterialPickerAnchor {
        let anchor = MaterialPickerAnchor()
        context.coordinator.anchor = anchor
        anchor.availabilityChanged = { [weak coordinator = context.coordinator] in coordinator?.synchronize() }
        return anchor
    }

    func updateUIViewController(_ controller: MaterialPickerAnchor, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in coordinator?.synchronize() }
    }

    static func dismantleUIViewController(_ controller: MaterialPickerAnchor, coordinator: Coordinator) {
        controller.availabilityChanged = nil
        coordinator.stop()
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate, UIViewControllerTransitioningDelegate {
        private enum Phase { case idle, presenting, visible, dismissing }
        private final class ResultContext {
            weak var controller: UIDocumentPickerViewController?
            let item: Item
            init(_ controller: UIDocumentPickerViewController, item: Item) {
                self.controller = controller
                self.item = item
            }
        }
        var parent: MaterialDocumentPicker
        weak var anchor: MaterialPickerAnchor?
        private var picker: UIDocumentPickerViewController?
        private var activeItem: Item?
        private var phase = Phase.idle
        private var results: [ObjectIdentifier: ResultContext] = [:]
        private var retry: DispatchWorkItem?
        private var stopped = false

        init(parent: MaterialDocumentPicker) { self.parent = parent }
        deinit { retry?.cancel() }

        func synchronize() {
            retry?.cancel()
            retry = nil
            guard !stopped else { return }
            if let picker {
                // Keep ownership until the actual dismissal finishes. A newer
                // binding remains pending and cannot be cleared by an old callback.
                if phase == .visible, parent.item?.id != activeItem?.id {
                    close(picker)
                }
                return
            }
            guard let item = parent.item, let anchor,
                  anchor.viewIfLoaded?.window != nil, !anchor.disappeared else { return }
            guard anchor.presentedViewController == nil,
                  anchor.transitionCoordinator == nil else {
                retryWhenAvailable()
                return
            }
            results = results.filter { $0.value.controller != nil }
            guard !results.values.contains(where: { $0.item.id == item.id }) else { return }
            let controller = MaterialPickerController(forOpeningContentTypes: [parent.type(item)], asCopy: false)
            controller.allowsMultipleSelection = false
            controller.delegate = self
            controller.modalPresentationStyle = .custom
            controller.transitioningDelegate = self
            activeItem = item
            picker = controller
            phase = .presenting
            results[ObjectIdentifier(controller)] = ResultContext(controller, item: item)
            anchor.present(controller, animated: true) { [weak self, weak controller] in
                guard let controller else { return }
                self?.didPresent(controller, completed: true)
            }
            DispatchQueue.main.async { [weak self, weak controller] in
                guard let self, let controller, self.picker === controller,
                      self.phase == .presenting, controller.presentingViewController == nil,
                      !controller.isBeingPresented else { return }
                self.didPresent(controller, completed: false)
            }
        }

        private func retryWhenAvailable() {
            let work = DispatchWorkItem { [weak self] in self?.synchronize() }
            retry = work
            // Only a live, visible, pending request is polled. Closing the screen,
            // cancelling the request, or starting presentation ends this wait.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
        }

        private func didPresent(_ controller: UIDocumentPickerViewController, completed: Bool) {
            guard !stopped, picker === controller, phase == .presenting else { return }
            if completed {
                phase = .visible
                synchronize()
            } else {
                results.removeValue(forKey: ObjectIdentifier(controller))
                if parent.item?.id == activeItem?.id { parent.item = nil }
                picker = nil
                activeItem = nil
                phase = .idle
                synchronize()
            }
        }

        private func didDismiss(_ controller: UIDocumentPickerViewController) {
            guard !stopped, picker === controller else { return }
            picker = nil
            activeItem = nil
            phase = .idle
            // Native selection can arrive after the dismissal callback. Its
            // immutable request remains in results until the delegate receives it.
            DispatchQueue.main.async { [weak self] in self?.synchronize() }
        }

        func stop() {
            stopped = true
            retry?.cancel()
            retry = nil
            results.removeAll()
            picker?.delegate = nil
            picker?.dismiss(animated: false)
            picker = nil
            activeItem = nil
            phase = .idle
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard !stopped, let result = results.removeValue(forKey: ObjectIdentifier(controller)) else { return }
            let selection = urls.first.map { ScopedMaterialSelection($0) }
            if parent.item?.id == result.item.id { parent.item = nil }
            close(controller)
            if let selection { parent.selected(result.item, selection) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            guard !stopped, let result = results.removeValue(forKey: ObjectIdentifier(controller)) else { return }
            if parent.item?.id == result.item.id { parent.item = nil }
            close(controller)
        }

        private func close(_ controller: UIDocumentPickerViewController) {
            guard picker === controller, phase != .presenting, phase != .dismissing else { return }
            phase = .dismissing
            if controller.isBeingDismissed { return }
            if controller.presentingViewController == nil { didDismiss(controller); return }
            controller.dismiss(animated: true) { [weak self, weak controller] in
                guard let controller else { return }
                self?.didDismiss(controller)
            }
        }

        func presentationController(forPresented presented: UIViewController,
                                    presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
            guard let controller = presented as? UIDocumentPickerViewController,
                  let result = results[ObjectIdentifier(controller)] else { return nil }
            return GuidedDocumentPicker(picker: controller, presenting: presenting,
                instruction: parent.instruction(result.item), cancel: { [weak self, weak controller] in
                    guard let controller else { return }
                    self?.documentPickerWasCancelled(controller)
                }, presented: { [weak self, weak controller] completed in
                    guard let controller else { return }
                    self?.didPresent(controller, completed: completed)
                }, dismissed: { [weak self, weak controller] in
                    guard let controller else { return }
                    self?.didDismiss(controller)
                })
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
    var availabilityChanged: (() -> Void)?
    private(set) var disappeared = false
    override func loadView() {
        let content = MaterialPickerAnchorView()
        content.backgroundColor = .clear
        content.attached = { [weak self] in self?.availabilityChanged?() }
        view = content
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disappeared = false
        availabilityChanged?()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disappeared = true
        availabilityChanged?()
    }
}

private final class MaterialPickerAnchorView: UIView {
    var attached: (() -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        DispatchQueue.main.async { [weak self] in self?.attached?() }
    }
}
