import SwiftUI
import UIKit

/// Keeps the instruction above the picker's sheet without taking keyboard or touch focus.
final class GuidedDocumentPicker: UIDocumentPickerViewController {
    var instruction = ""
    private var guidanceWindow: UIWindow?
    private var guidanceHost: UIHostingController<MaterialSelectionInstruction>?
    private var guidanceWidth: NSLayoutConstraint?
    private var visible = false
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDeactivated(_:)),
                                               name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneActivated(_:)),
                                               name: UIScene.didActivateNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visible = true
        showGuidance()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        visible = false
        removeGuidance()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        reserveGuidanceSpace()
    }

    func finishGuidance() {
        finished = true
        removeGuidance()
    }

    @objc private func sceneDeactivated(_ notification: Notification) {
        guard let scene = view.window?.windowScene, notification.object as? UIScene === scene else { return }
        removeGuidance()
    }

    @objc private func sceneActivated(_ notification: Notification) {
        guard let scene = view.window?.windowScene, notification.object as? UIScene === scene else { return }
        showGuidance()
    }

    private func showGuidance() {
        guard visible, !finished, guidanceWindow == nil,
              let scene = view.window?.windowScene, scene.activationState == .foregroundActive else { return }
        let window = GuidanceWindow(windowScene: scene)
        // Stay above ordinary app sheets, below system alerts. Never make this the key window.
        window.windowLevel = .init(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        let container = UIViewController()
        container.view.backgroundColor = .clear
        container.view.accessibilityViewIsModal = false
        let host = UIHostingController(rootView: MaterialSelectionInstruction(text: instruction))
        host.view.backgroundColor = .clear
        container.addChild(host)
        container.view.addSubview(host.view)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        let width = host.view.widthAnchor.constraint(equalToConstant: max(1, view.bounds.width - 24))
        guidanceWidth = width
        NSLayoutConstraint.activate([
            host.view.centerXAnchor.constraint(equalTo: container.view.centerXAnchor),
            width,
            host.view.bottomAnchor.constraint(equalTo: container.view.keyboardLayoutGuide.topAnchor, constant: -8)
        ])
        host.sizingOptions = .intrinsicContentSize
        host.didMove(toParent: container)
        window.rootViewController = container
        guidanceHost = host
        guidanceWindow = window
        window.isHidden = false
        reserveGuidanceSpace()
    }

    private func reserveGuidanceSpace() {
        guard let host = guidanceHost else { return }
        let width = max(1, view.bounds.width - 24)
        guidanceWidth?.constant = width
        let size = host.sizeThatFits(in: CGSize(width: width, height: 1_000))
        let bottom = ceil(size.height) + 16
        // Keep the picker toolbar and last file row above the floating instruction.
        if abs(additionalSafeAreaInsets.bottom - bottom) > 0.5 {
            additionalSafeAreaInsets.bottom = bottom
        }
    }

    private func removeGuidance() {
        guidanceWindow?.isHidden = true
        guidanceWindow?.rootViewController = nil
        guidanceWindow = nil
        guidanceHost = nil
        guidanceWidth = nil
        additionalSafeAreaInsets.bottom = 0
    }
}

private final class GuidanceWindow: UIWindow {
    override var canBecomeKey: Bool { false }
}

private struct MaterialSelectionInstruction: View {
    let text: String

    var body: some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 16))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var content: some View {
        Label(text, systemImage: "doc")
            .font(.subheadline)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(12)
    }
}
