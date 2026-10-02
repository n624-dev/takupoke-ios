import UIKit

/// The picker resets its sheet style during presentation. Keep the public
/// presentation style consistent with the transitioning delegate for its lifetime.
final class MaterialPickerController: UIDocumentPickerViewController {
    var presentationChanged: (() -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitUserInterfaceLevel.self,
                                UITraitAccessibilityContrast.self]) { (picker: MaterialPickerController, _) in
            picker.viewIfLoaded?.setNeedsLayout()
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (presentationController as? GuidedDocumentPicker)?.updateBackground()
    }
    override var modalPresentationStyle: UIModalPresentationStyle {
        get { .custom }
        set { super.modalPresentationStyle = .custom }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in self?.presentationChanged?() }
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.main.async { [weak self] in self?.presentationChanged?() }
    }
}

/// The instruction is a sibling of the native picker. UIKit receives the
/// picker's actual rectangle, so its safe area matches its on-screen position.
final class GuidedDocumentPicker: UIPresentationController {
    private let chrome: MaterialPickerChrome
    private let presented: (Bool) -> Void
    private let dismissed: () -> Void

    init(picker: UIDocumentPickerViewController, presenting: UIViewController?,
         instruction: String, cancel: @escaping () -> Void,
         presented: @escaping (Bool) -> Void = { _ in }, dismissed: @escaping () -> Void = {}) {
        chrome = MaterialPickerChrome(instruction: instruction, cancel: cancel)
        self.presented = presented
        self.dismissed = dismissed
        super.init(presentedViewController: picker, presenting: presenting)
    }

    override var shouldRemovePresentersView: Bool { false }
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView else { return .zero }
        return chrome.layout(in: containerView.bounds, topInset: containerView.safeAreaInsets.top).picker
    }

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        containerView.insertSubview(chrome, at: 0)
        layoutChrome()
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        layoutChrome()
    }

    private func layoutChrome() {
        guard let containerView else { return }
        updateBackground()
        chrome.frame = containerView.bounds
        chrome.topInset = containerView.safeAreaInsets.top
        chrome.setNeedsLayout()
        chrome.layoutIfNeeded()
        let frame = frameOfPresentedViewInContainerView
        // Bounds/center remain valid while the transition applies a transform.
        presentedViewController.view.bounds = CGRect(origin: .zero, size: frame.size)
        presentedViewController.view.center = CGPoint(x: frame.midX, y: frame.midY)
    }

    func updateBackground() {
        guard let pickerView = presentedViewController.viewIfLoaded else { return }
        let color = pickerView.backgroundColor?.resolvedColor(with: pickerView.traitCollection)
        if let color, color.cgColor.alpha == 1 {
            chrome.backgroundColor = color
        } else {
            // A transparent picker root doesn't expose the remote Files view's
            // fill. Use the system background for an elevated presentation.
            let traits = UITraitCollection(traitsFrom: [pickerView.traitCollection,
                UITraitCollection(userInterfaceLevel: .elevated)])
            chrome.backgroundColor = UIColor.systemBackground.resolvedColor(with: traits)
        }
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        if !completed { chrome.removeFromSuperview() }
#if TAKUPOKE_PICKER_TESTS
        MaterialPickerTestTrace.record?("presentation transition ended \(completed), instructionAttached=\(chrome.window != nil), controller=\(ObjectIdentifier(presentedViewController))")
#endif
        presented(completed)
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            chrome.removeFromSuperview()
            DispatchQueue.main.async(execute: dismissed)
        }
#if TAKUPOKE_PICKER_TESTS
        MaterialPickerTestTrace.record?("dismissal transition ended \(completed), instructionAttached=\(chrome.window != nil), controller=\(ObjectIdentifier(presentedViewController))")
#endif
    }
}

private final class MaterialPickerChrome: UIView {
    var topInset: CGFloat = 0
    private let instructionView: UIVisualEffectView
    private let label = UILabel()
    private let stack: UIStackView
    private let cancel: () -> Void

    init(instruction: String, cancel: @escaping () -> Void) {
        self.cancel = cancel
        if #available(iOS 26.0, *) {
            instructionView = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
        } else {
            instructionView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        }
        let icon = UIImageView(image: UIImage(systemName: "doc"))
        icon.tintColor = .label
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        stack = UIStackView(arrangedSubviews: [icon, label])
        super.init(frame: .zero)
        backgroundColor = .systemGroupedBackground
        clipsToBounds = true
        label.text = instruction
        label.textColor = .label
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textAlignment = .center
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        instructionView.layer.cornerRadius = 16
        instructionView.clipsToBounds = true
        addSubview(instructionView)
        instructionView.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 20),
            stack.leadingAnchor.constraint(equalTo: instructionView.contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: instructionView.contentView.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: instructionView.contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: instructionView.contentView.bottomAnchor, constant: -12),
        ])
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(close))
        swipe.direction = .down
        instructionView.addGestureRecognizer(swipe)
        label.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "閉じる", target: self, selector: #selector(accessibilityClose))]
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(in bounds: CGRect, topInset: CGFloat) -> MaterialPickerLayout {
        let width = max(1, bounds.width - 24)
        let labelHeight = label.sizeThatFits(CGSize(width: max(1, width - 24 - 18 - 8),
                                                   height: .greatestFiniteMagnitude)).height
        return MaterialPickerLayout(bounds: bounds, topInset: topInset,
                                    instructionHeight: max(20, labelHeight) + 24)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        instructionView.frame = layout(in: bounds, topInset: topInset).instruction
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.preferredContentSizeCategory != traitCollection.preferredContentSizeCategory {
            label.font = .preferredFont(forTextStyle: .subheadline)
            setNeedsLayout()
        }
    }

    @objc private func close() { cancel() }
    @objc private func accessibilityClose() -> Bool { cancel(); return true }
}

final class MaterialPickerTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let presenting: Bool
    init(presenting: Bool) { self.presenting = presenting }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0 : 0.25
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let view = context.view(forKey: presenting ? .to : .from) else {
            context.completeTransition(false)
            return
        }
        let translation = CGAffineTransform(translationX: 0, y: context.containerView.bounds.height)
        if presenting {
            if let controller = context.viewController(forKey: .to) {
                view.frame = context.finalFrame(for: controller)
            }
            context.containerView.addSubview(view)
            view.transform = translation
        }
        UIView.animate(withDuration: transitionDuration(using: context), animations: {
            view.transform = self.presenting ? .identity : translation
        }, completion: { _ in
            view.transform = .identity
            context.completeTransition(!context.transitionWasCancelled)
        })
    }
}
