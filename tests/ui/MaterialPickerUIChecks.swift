import UIKit
import UniformTypeIdentifiers

/// Runs only in a disposable simulator with the local Files provider.
@main
final class PickerChecks: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Picker checks", sessionRole: session.role)
        configuration.sceneClass = UIWindowScene.self
        configuration.delegateClass = PickerCheckScene.self
        return configuration
    }
}

final class PickerCheckScene: UIResponder, UIWindowSceneDelegate, UIViewControllerTransitioningDelegate {
    var window: UIWindow?
    private var root = UIViewController()
    private var step = 0
    private let instructions = ["架空ファイルを選んでください", String(repeating: "架空ファイルの選択案内です。", count: 8)]

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        progress("scene connected")
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.open() }
    }

    private func open() {
        progress("opening picker \(step), window: \(root.view.window != nil)")
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: false)
        picker.loadViewIfNeeded()
        picker.modalPresentationStyle = .custom
        picker.transitioningDelegate = self
        root.present(picker, animated: true) {
            self.progress("presentation completed \(self.step)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.check(picker) }
        }
    }

    private func check(_ picker: UIDocumentPickerViewController) {
        progress("checking picker \(step)")
        guard let presentation = picker.presentationController as? GuidedDocumentPicker else {
            finish("FAIL: presentation controller = \(String(describing: picker.presentationController)), style = \(picker.modalPresentationStyle.rawValue)")
            return
        }
        guard let chrome = presentation.presentedView else { finish("FAIL: missing chrome"); return }
        guard let label = descendants(chrome).compactMap({ $0 as? UILabel }).first(where: { $0.text == instructions[step] }) else {
            finish("FAIL: missing instruction, subviews = \(chrome.subviews.map { String(describing: type(of: $0)) })")
            return
        }
        guard picker.presentingViewController != nil else { finish("FAIL: no presenting controller"); return }
        guard picker.parent == nil else { finish("FAIL: picker parent = \(String(describing: picker.parent))"); return }
        chrome.layoutIfNeeded()
        let text = label.convert(label.bounds, to: chrome)
        let content = picker.view.convert(picker.view.bounds, to: chrome)
        guard text.height > 0, text.maxY < content.minY,
              text.minY >= chrome.safeAreaInsets.top,
              abs(content.width - chrome.bounds.width) < 1,
              abs(content.maxY - chrome.bounds.maxY) < 1,
              content.height > 200 else { finish("FAIL: instruction/picker overlap or clipped bounds"); return }
        root.dismiss(animated: true) {
            guard self.root.presentedViewController == nil else { self.finish("FAIL: dismiss"); return }
            self.step += 1
            if self.step < self.instructions.count { self.open() }
            else { self.finish("PASS: native modal, separate instruction, wrapped text, dismiss and reopen") }
        }
    }

    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }
    private func progress(_ message: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("progress.txt")
        try? message.write(to: url, atomically: true, encoding: .utf8)
    }
    private func finish(_ result: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("result.txt")
        try! result.write(to: url, atomically: true, encoding: .utf8)
    }
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        GuidedDocumentPicker(picker: presented as! UIDocumentPickerViewController, presenting: presenting,
                             instruction: instructions[step], cancel: { self.root.dismiss(animated: true) })
    }
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        MaterialPickerTransition(presenting: true)
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        MaterialPickerTransition(presenting: false)
    }
}
