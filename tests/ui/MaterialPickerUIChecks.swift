import Darwin
import SwiftUI
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
        let picker = MaterialPickerController(forOpeningContentTypes: [.pdf], asCopy: false)
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
        guard let chrome = presentation.containerView else { finish("FAIL: missing chrome"); return }
        guard let label = descendants(chrome).compactMap({ $0 as? UILabel }).first(where: { $0.text == instructions[step] }) else {
            finish("FAIL: missing instruction, subviews = \(chrome.subviews.map { String(describing: type(of: $0)) })")
            return
        }
        guard picker.presentingViewController != nil else { finish("FAIL: no presenting controller"); return }
        guard picker.parent == nil else { finish("FAIL: picker parent = \(String(describing: picker.parent))"); return }
        chrome.layoutIfNeeded()
        let text = label.convert(label.bounds, to: chrome)
        let content = picker.view.convert(picker.view.bounds, to: chrome)
        print("PICKER GEOMETRY: frame=\(content), safeArea=\(picker.view.safeAreaInsets), instruction=\(text)")
        fflush(stdout)
        guard picker.view.safeAreaInsets.top < 1 else { finish("FAIL: duplicated top safe area \(picker.view.safeAreaInsets.top)"); return }
        guard text.height > 0, text.maxY < content.minY,
              text.minY >= chrome.safeAreaInsets.top,
              abs(content.width - chrome.bounds.width) < 1,
              abs(content.maxY - chrome.bounds.maxY) < 1,
              content.height > 200 else { finish("FAIL: layout text=\(text), picker=\(content), bounds=\(chrome.bounds)"); return }
        root.dismiss(animated: true) {
            guard self.root.presentedViewController == nil else { self.finish("FAIL: dismiss"); return }
            self.step += 1
            if self.step < self.instructions.count { self.open() }
            else { self.checkBridge() }
        }
    }

    private var driver = PickerHarnessDriver()

    private func checkBridge() {
        progress("starting SwiftUI bridge")
        let host = UIHostingController(rootView: PickerHarness(driver: driver))
        root = host
        window?.rootViewController = host
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.bridgeCycle(0) }
    }

    private func bridgeCycle(_ index: Int) {
        progress("SwiftUI request \(index)")
        driver.choose(index % 4)
        waitForPicker(remaining: 40) { picker in
            guard let picker else { self.finish("FAIL: SwiftUI request \(index) did not present"); return }
            guard let delegate = picker.delegate else { self.finish("FAIL: missing native delegate"); return }
            // Exercise the same callback the native Cancel control delivers.
            delegate.documentPickerWasCancelled?(picker)
            if index < 7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.bridgeCycle(index + 1) }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.checkNavigationReturn() }
            }
        }
    }

    private func checkNavigationReturn() {
        progress("detail navigation and return")
        driver.path.append(2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.driver.path.removeLast()
            // Request during the return transition, without waiting for appearance.
            self.driver.choose(3)
            self.waitForPicker(remaining: 40) { picker in
                guard let picker else { self.finish("FAIL: request during navigation return"); return }
                picker.dismiss(animated: true) {
                    // A native result can arrive after dismissal and after a new request.
                    self.driver.choose(2)
                    self.waitForPicker(remaining: 40) { next in
                        guard let next else { self.finish("FAIL: request after native dismissal"); return }
                        picker.delegate?.documentPickerWasCancelled?(picker)
                        guard self.driver.request?.kind == 2 else {
                            self.finish("FAIL: old cancellation cleared the new request"); return
                        }
                        next.delegate?.documentPickerWasCancelled?(next)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.checkBlockedRequest() }
                    }
                }
            }
        }
    }

    private func checkBlockedRequest() {
        progress("request while another presentation is active")
        let blocker = UIViewController()
        blocker.modalPresentationStyle = .overFullScreen
        root.present(blocker, animated: false) {
            self.driver.choose(0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                blocker.dismiss(animated: false) {
                    self.waitForPicker(remaining: 40) { picker in
                        guard let picker else { self.finish("FAIL: pending SwiftUI request did not resume after dismissal"); return }
                        picker.delegate?.documentPickerWasCancelled?(picker)
                        self.finish("PASS: native layout, SwiftUI binding, repeated cancellation/reselection, deferred presentation")
                    }
                }
            }
        }
    }

    private func waitForPicker(remaining: Int, completion: @escaping (UIDocumentPickerViewController?) -> Void) {
        if let picker = root.presentedViewController as? UIDocumentPickerViewController,
           !picker.isBeingPresented, !picker.isBeingDismissed {
            completion(picker)
        } else if remaining == 0 { completion(nil) }
        else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.waitForPicker(remaining: remaining - 1, completion: completion)
            }
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

// The UI fixture uses the app's actual representable and security-scope lease.
// Only the unrelated acquisition error type is substituted for this small app.
enum MaterialError: Error { case cancelled, accessExpired }

struct PickerHarnessRequest: Identifiable {
    let id = UUID()
    let kind: Int
}

final class PickerHarnessDriver: ObservableObject {
    @Published var request: PickerHarnessRequest?
    @Published var path: [Int] = [1]
    func choose(_ kind: Int) { request = PickerHarnessRequest(kind: kind) }
}

struct PickerHarness: View {
    @ObservedObject var driver: PickerHarnessDriver
    var body: some View {
        TabView {
            NavigationStack(path: $driver.path) {
                List { NavigationLink("ファイル選択", value: 1) }
                    .navigationTitle("設定")
                    .navigationDestination(for: Int.self) { value in
                        if value == 1 { fileList } else { Text("架空の詳細") }
                    }
            }
            .tabItem { Text("設定") }
        }
    }
    private var fileList: some View {
        List {
            ForEach(0..<4) { kind in
                Button("ファイル\(kind)を選び直す") { driver.choose(kind) }
            }
            NavigationLink("詳細を見る", value: 2)
        }
        .background {
            MaterialDocumentPicker(item: $driver.request, type: { _ in .pdf },
                instruction: { "架空ファイル\($0.kind)を選んでください" }, selected: { _, _ in })
        }
    }
}
