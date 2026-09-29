import UIKit
import UniformTypeIdentifiers

/// Runs only in a disposable simulator with the local Files provider.
@main
final class PickerChecks: UIResponder, UIApplicationDelegate, UIViewControllerTransitioningDelegate {
    var window: UIWindow?
    private var root = UIViewController()
    private var step = 0
    private let instructions = ["架空ファイルを選んでください", String(repeating: "架空ファイルの選択案内です。", count: 8)]

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = root
        self.window = window
        window.makeKeyAndVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.open() }
        return true
    }

    private func open() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: false)
        picker.modalPresentationStyle = .custom
        picker.transitioningDelegate = self
        root.present(picker, animated: true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.check(picker) }
        }
    }

    private func check(_ picker: UIDocumentPickerViewController) {
        guard let presentation = picker.presentationController as? GuidedDocumentPicker,
              let chrome = presentation.presentedView,
              let label = descendants(chrome).compactMap({ $0 as? UILabel }).first(where: { $0.text == instructions[step] }),
              picker.presentingViewController != nil,
              picker.parent == nil else { finish("FAIL: modal presentation"); return }
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
