import Foundation
import ObjectiveC
import os
import UIKit

private final class FixtureCITraceOutput: @unchecked Sendable {
    static let shared = FixtureCITraceOutput()
    private let logger = Logger(subsystem: "jp.n624.takupoke.ci", category: "simulator")
    private let lock = NSLock()
    private var sequence: UInt64 = 0

    func emit(_ fields: String) {
        lock.lock()
        defer { lock.unlock() }
        sequence += 1
        let pid = ProcessInfo.processInfo.processIdentifier
        let time = Date().timeIntervalSince1970
        let uptime = ProcessInfo.processInfo.systemUptime
        logger.notice("CI_SIMULATOR_EVENT pid=\(pid) seq=\(sequence) time=\(time) uptime=\(uptime) \(fields, privacy: .public)")
    }
}

// Compiled only into the disposable UI fixture applications.
@MainActor
enum FixtureCITrace {
    private static var installed = false
    private static var nextDispatch: UInt64 = 0
    private static var nextTouch: UInt64 = 0
    private static var touches: [ObjectIdentifier: UInt64] = [:]
    private static let notifications: [(Notification.Name, String)] = [
        (UIApplication.didBecomeActiveNotification, "app-active"),
        (UIApplication.willResignActiveNotification, "app-inactive"),
        (UIApplication.didEnterBackgroundNotification, "app-background"),
        (UIApplication.willEnterForegroundNotification, "app-foreground"),
        (UIApplication.willTerminateNotification, "app-terminate"),
        (UIScene.didActivateNotification, "scene-active"),
        (UIScene.willDeactivateNotification, "scene-inactive"),
        (UIScene.didEnterBackgroundNotification, "scene-background"),
        (UIScene.willEnterForegroundNotification, "scene-foreground"),
        (UIWindow.didBecomeKeyNotification, "window-key"),
        (UIWindow.didResignKeyNotification, "window-resigned"),
        (UITextField.textDidBeginEditingNotification, "field-edit-began"),
        (UITextField.textDidChangeNotification, "field-edit-changed"),
        (UITextField.textDidEndEditingNotification, "field-edit-ended"),
        (UITextView.textDidBeginEditingNotification, "text-edit-began"),
        (UITextView.textDidChangeNotification, "text-edit-changed"),
        (UITextView.textDidEndEditingNotification, "text-edit-ended"),
        (UIResponder.keyboardWillShowNotification, "keyboard-will-show"),
        (UIResponder.keyboardDidShowNotification, "keyboard-did-show"),
        (UIResponder.keyboardWillHideNotification, "keyboard-will-hide"),
        (UIResponder.keyboardDidHideNotification, "keyboard-did-hide"),
        (UIResponder.keyboardWillChangeFrameNotification, "keyboard-will-change-frame"),
        (UIResponder.keyboardDidChangeFrameNotification, "keyboard-did-change-frame"),
    ]

    static func install() {
        guard !installed else { return }
        installed = true
        for (name, stage) in notifications {
            _ = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { _ in
                mark(stage)
            }
        }
        guard let original = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.sendEvent(_:))),
              let observer = class_getInstanceMethod(UIApplication.self, #selector(UIApplication.ciTraceSendEvent(_:))) else {
            mark("event-observer-unavailable")
            return
        }
        method_exchangeImplementations(original, observer)
        mark("event-observer-installed")
    }

    // Only fixed ASCII stage identifiers are accepted. Never pass labels or values.
    nonisolated static func mark(_ stage: String) {
        guard !stage.isEmpty, stage.utf8.count <= 64,
              stage.utf8.allSatisfy({ (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else { return }
        FixtureCITraceOutput.shared.emit("stage=\(stage)")
    }

    static func observe(_ event: UIEvent, deliver: () -> Void) {
        nextDispatch += 1
        let dispatch = nextDispatch
        let output = FixtureCITraceOutput.shared
        if let eventTouches = event.allTouches, !eventTouches.isEmpty {
            for touch in eventTouches {
                let identity = ObjectIdentifier(touch)
                let id: UInt64
                if let known = touches[identity] { id = known }
                else {
                    nextTouch += 1
                    id = nextTouch
                    touches[identity] = id
                }
                let point = touch.location(in: touch.window)
                if point.x.isFinite, point.y.isFinite {
                    let x = String(format: "%.2f", Double(point.x)), y = String(format: "%.2f", Double(point.y))
                    let phase = touch.phase.rawValue
                    output.emit("dispatch=\(dispatch) touch=\(id) phase=\(phase) event=\(touch.timestamp) x=\(x) y=\(y)")
                }
                if touch.phase == .ended || touch.phase == .cancelled {
                    touches.removeValue(forKey: identity)
                }
            }
        } else if let presses = event as? UIPressesEvent {
            for press in presses.allPresses {
                output.emit("dispatch=\(dispatch) press=\(press.phase.rawValue) event=\(press.timestamp)")
            }
        } else {
            output.emit("dispatch=\(dispatch) event-type=\(event.type.rawValue) event=\(event.timestamp)")
        }
        deliver()
        output.emit("delivered=\(dispatch)")
    }
}

extension UIApplication {
    @objc fileprivate dynamic func ciTraceSendEvent(_ event: UIEvent) {
        FixtureCITrace.observe(event) { self.ciTraceSendEvent(event) }
    }
}
