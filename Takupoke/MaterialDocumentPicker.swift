import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// The standard picker stays modal. A pending request survives a temporarily
/// unavailable presenter; native results are tracked separately from animation.
struct MaterialDocumentPicker<Item: Identifiable>: View {
    @Binding var item: Item?
    var type: (Item) -> UTType
    var instruction: (Item) -> String
    var selected: (Item, ScopedMaterialSelection) -> Void

    var body: some View {
        // Read the request in a SwiftUI body. Passing only its Binding through
        // a background builder did not invalidate the UIKit bridge on a tap.
        MaterialPickerBridge(item: $item, requestID: item?.id, type: type,
                             instruction: instruction, selected: selected)
    }
}

private struct MaterialPickerBridge<Item: Identifiable>: UIViewControllerRepresentable {
    @Binding var item: Item?
    let requestID: Item.ID?
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
        var parent: MaterialPickerBridge
        weak var anchor: MaterialPickerAnchor?
        private var picker: UIDocumentPickerViewController?
        private var activeItem: Item?
        private var phase = Phase.idle
        private var results: [ObjectIdentifier: ResultContext] = [:]
        private var retry: DispatchWorkItem?
        private var dismissalCheck: DispatchWorkItem?
        private weak var presenter: UIViewController?
        private var stopped = false

        init(parent: MaterialPickerBridge) { self.parent = parent }
        deinit { retry?.cancel(); dismissalCheck?.cancel() }

        func synchronize() {
            trace("synchronize")
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
            guard let item = parent.item, let anchor else { return }
            guard let host = anchor.visiblePresentationHost else {
                trace("waiting for visible host")
                if anchor.viewIfLoaded?.window != nil { retryWhenAvailable() }
                return
            }
            guard host.presentedViewController == nil, host.transitionCoordinator == nil,
                  !host.isBeingPresented, !host.isBeingDismissed else {
                trace("waiting for host transition")
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
            presenter = host
            results[ObjectIdentifier(controller)] = ResultContext(controller, item: item)
            controller.presentationChanged = { [weak self, weak controller] in
                guard let controller else { return }
                self?.reconcile(controller)
            }
            host.present(controller, animated: true) { [weak self, weak controller] in
                guard let controller else { return }
                self?.didPresent(controller, completed: true)
            }
            // The native browser may still be preparing its content. Only
            // UIKit's transition and lifecycle callbacks complete presentation.
        }

        private func reconcile(_ controller: UIDocumentPickerViewController) {
            guard !stopped, picker === controller else { return }
            if phase == .presenting, controller.presentingViewController != nil,
               controller.viewIfLoaded?.window != nil, !controller.isBeingPresented,
               !controller.isBeingDismissed {
                didPresent(controller, completed: true)
            } else if phase != .presenting, controller.presentingViewController == nil,
                      presenter?.presentedViewController !== controller, !controller.isBeingDismissed {
                didDismiss(controller)
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
            trace("presented \(completed)")
            if completed {
                presenter = controller.presentingViewController ?? presenter
                phase = .visible
                synchronize()
            } else {
                results.removeValue(forKey: ObjectIdentifier(controller))
                if parent.item?.id == activeItem?.id { parent.item = nil }
                picker = nil
                activeItem = nil
                presenter = nil
                phase = .idle
                synchronize()
            }
        }

        private func didDismiss(_ controller: UIDocumentPickerViewController) {
            guard !stopped, picker === controller else { return }
            trace("dismissed callback")
            phase = .dismissing
            dismissalCheck?.cancel()
            if controller.presentingViewController != nil || presenter?.presentedViewController === controller ||
                controller.isBeingDismissed {
                let work = DispatchWorkItem { [weak self, weak controller] in
                    guard let controller else { return }
                    self?.didDismiss(controller)
                }
                dismissalCheck = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
                return
            }
            dismissalCheck = nil
            (controller as? MaterialPickerController)?.presentationChanged = nil
            presenter = nil
            picker = nil
            activeItem = nil
            phase = .idle
            // Native selection can arrive after the dismissal callback. Its
            // immutable request remains in results until the delegate receives it.
            DispatchQueue.main.async { [weak self] in self?.synchronize() }
        }

        func stop() {
            stopped = true
            dismissalCheck?.cancel()
            dismissalCheck = nil
            retry?.cancel()
            retry = nil
            results.removeAll()
            (picker as? MaterialPickerController)?.presentationChanged = nil
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
            trace("cancel callback \(ObjectIdentifier(controller))")
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

        private func trace(_ event: String) {
#if TAKUPOKE_PICKER_TESTS
            MaterialPickerTestTrace.record?("\(event) phase=\(phase) request=\(String(describing: parent.item?.id)) active=\(String(describing: activeItem?.id)) picker=\(String(describing: picker.map(ObjectIdentifier.init))) attached=\(anchor?.viewIfLoaded?.window != nil)")
#endif
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
    private var activationObserver: NSObjectProtocol?

    /// Resolve the actual containing screen afresh for each request. Appearance
    /// callbacks on a SwiftUI background controller are not a visibility record.
    var visiblePresentationHost: UIViewController? {
        guard let content = viewIfLoaded, let window = content.window,
              window.windowScene?.activationState == .foregroundActive else { return nil }
        var visibleView: UIView? = content
        while let current = visibleView, current !== window {
            guard !current.isHidden, current.alpha > 0 else { return nil }
            visibleView = current.superview
        }
        guard var host = parent else { return nil }
        var child: UIViewController = self
        while true {
            if let navigation = host as? UINavigationController,
               navigation.topViewController !== child { return nil }
            if let tabs = host as? UITabBarController,
               tabs.selectedViewController !== child { return nil }
            guard host.viewIfLoaded?.window === window else { return nil }
            guard let next = host.parent else { return host }
            child = host
            host = next
        }
    }
    override func loadView() {
        let content = MaterialPickerAnchorView()
        content.backgroundColor = .clear
        content.isUserInteractionEnabled = false
        content.attached = { [weak self] in self?.availabilityChanged?() }
        view = content
        activationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self, let scene = notification.object as? UIScene,
                      self.viewIfLoaded?.window?.windowScene === scene else { return }
                self.availabilityChanged?()
            }
    }
    deinit { if let activationObserver { NotificationCenter.default.removeObserver(activationObserver) } }
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        availabilityChanged?()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        availabilityChanged?()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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

#if TAKUPOKE_PICKER_TESTS
// Compiled only into the disposable UI test app; no file data is recorded.
enum MaterialPickerTestTrace {
    static var record: ((String) -> Void)?
}
#endif
