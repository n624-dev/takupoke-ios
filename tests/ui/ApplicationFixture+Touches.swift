import SwiftUI
import UIKit

// Diagnostic only: observe native touch delivery in the disposable fictional app.
// Never recognize a gesture, delay/cancel touches, or modify controls/preferences.
struct FixtureTouchProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> FixtureTouchView { FixtureTouchView() }
    func updateUIView(_ view: FixtureTouchView, context: Context) {}
    static func dismantleUIView(_ view: FixtureTouchView, coordinator: ()) { view.detach() }
}

final class FixtureTouchView: UIView {
    private weak var observedWindow: UIWindow?
    private let observer = FixtureTouchObserver(target: nil, action: nil)

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window !== observedWindow else { return }
        detach()
        guard let window else { return }
        observer.cancelsTouchesInView = false
        observer.delaysTouchesBegan = false
        observer.delaysTouchesEnded = false
        window.addGestureRecognizer(observer)
        observedWindow = window
    }

    func detach() {
        observedWindow?.removeGestureRecognizer(observer)
        observedWindow = nil
    }
}

private final class FixtureTouchObserver: UIGestureRecognizer {
    private var recorded = 0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // Fail immediately, so the diagnostic cannot win gesture arbitration.
        state = .failed
        guard recorded < 32, touches.count == 1, let touch = touches.first,
              let window = touch.window else { return }
        recorded += 1
        let point = touch.location(in: window)
        guard point.x.isFinite, point.y.isFinite else { return }
        var parent = touch.view
        var control: UISwitch?
        for _ in 0..<16 {
            guard let current = parent else { break }
            if let found = current as? UISwitch { control = found; break }
            parent = current.superview
        }
        let rawName = touch.view.map { NSStringFromClass(type(of: $0)) } ?? "none"
        let name = String(rawName.filter { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == ".") }.prefix(128))
        FixtureLaunchDiagnostics.recordTouch(
            point: point, view: name, control: control != nil,
            value: control.map { $0.isOn ? 1 : 0 } ?? -1,
            enabled: control.map { $0.isEnabled ? 1 : 0 } ?? -1)
    }
}
