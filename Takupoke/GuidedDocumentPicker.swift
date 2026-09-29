import UIKit

/// The picker resets its sheet style during presentation. Keep the public
/// presentation style consistent with the transitioning delegate for its lifetime.
final class MaterialPickerController: UIDocumentPickerViewController {
    override var modalPresentationStyle: UIModalPresentationStyle {
        get { .custom }
        set { super.modalPresentationStyle = .custom }
    }
}

/// Keep UIKit's picker as a modal controller. Its complete view, including
/// remote File Provider UI, sits below a separately measured instruction.
final class GuidedDocumentPicker: UIPresentationController {
    private let chrome: MaterialPickerChrome
    private let dismissed: () -> Void

    init(picker: UIDocumentPickerViewController, presenting: UIViewController?,
         instruction: String, cancel: @escaping () -> Void, dismissed: @escaping () -> Void = {}) {
        chrome = MaterialPickerChrome(instruction: instruction, cancel: cancel)
        self.dismissed = dismissed
        super.init(presentedViewController: picker, presenting: presenting)
    }

    override var presentedView: UIView? { chrome }
    override var shouldRemovePresentersView: Bool { false }
    override var frameOfPresentedViewInContainerView: CGRect { containerView?.bounds ?? .zero }

    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        presentedViewController.view.clipsToBounds = true
        chrome.pickerView = presentedViewController.view
        chrome.addSubview(presentedViewController.view)
        containerView.addSubview(chrome)
        layoutChrome()
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        layoutChrome()
    }

    private func layoutChrome() {
        guard let containerView else { return }
        chrome.bounds = CGRect(origin: .zero, size: containerView.bounds.size)
        chrome.center = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
        chrome.topInset = containerView.safeAreaInsets.top
        chrome.setNeedsLayout()
        chrome.layoutIfNeeded()
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        if !completed { chrome.removeFromSuperview() }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            chrome.removeFromSuperview()
            // UIKit clears the modal relationship after this callback returns.
            DispatchQueue.main.async(execute: dismissed)
        }
    }
}

private final class MaterialPickerChrome: UIView {
    var pickerView: UIView?
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

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = max(1, bounds.width - 24)
        let labelHeight = label.sizeThatFits(CGSize(width: max(1, width - 24 - 18 - 8),
                                                   height: .greatestFiniteMagnitude)).height
        let layout = MaterialPickerLayout(bounds: bounds, topInset: topInset,
                                          instructionHeight: max(20, labelHeight) + 24)
        instructionView.frame = layout.instruction
        pickerView?.frame = layout.picker
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
