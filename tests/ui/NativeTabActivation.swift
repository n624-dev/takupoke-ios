import XCTest
import UIKit

extension SimulatorIdentityTestCase {
    func pressNativeTabIcon(_ title: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        var deadline = ProcessInfo.processInfo.systemUptime + timeout
        var foundBar = false
        let scale = UIScreen.main.scale
        var contact: CGPoint?
        var observation = "app snapshot unavailable"
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline else { return true }
            guard let root = try? app.snapshot(), let nodes = self.snapshotNodes(in: root) else { return false }
            guard ProcessInfo.processInfo.systemUptime < deadline else { return true }
            let bars = nodes.filter { $0.elementType == .tabBar }
            observation = "native tab bars=\(bars.count)"
            if bars.count > 1 { return true }
            guard let bar = bars.first, let barNodes = self.snapshotNodes(in: bar) else { return false }
            if !foundBar {
                foundBar = true
                deadline = ProcessInfo.processInfo.systemUptime + timeout
            }
            let buttons = barNodes.filter { $0.elementType == .button && ($0.identifier == title || $0.label == title) }
            observation += "; matching buttons=\(buttons.count)"
            if buttons.count > 1 { return true }
            guard let button = buttons.first, let descendants = self.snapshotNodes(in: button) else { return false }
            let icons = descendants.filter { $0.elementType == .image }
            observation += "; native images=\(icons.count)"
            if icons.count > 1 { return true }
            guard icons.count == 1 else { return false }
            // The observed icon belongs to the same current, enabled button.
            let icon = icons[0]
            let appFrame = root.frame, barFrame = bar.frame, buttonFrame = button.frame, iconFrame = icon.frame
            guard ObservedScreenGeometry.usable(appFrame), ObservedScreenGeometry.usable(barFrame),
                  ObservedScreenGeometry.usable(buttonFrame), ObservedScreenGeometry.usable(iconFrame),
                  ObservedScreenGeometry.contains(barFrame, in: appFrame, scale: scale),
                  ObservedScreenGeometry.contains(buttonFrame, in: barFrame, scale: scale),
                  ObservedScreenGeometry.contains(iconFrame, in: buttonFrame, scale: scale),
                  ObservedScreenGeometry.contains(iconFrame, in: barFrame, scale: scale),
                  button.isEnabled, ProcessInfo.processInfo.systemUptime < deadline else { return false }
            let center = CGPoint(x: iconFrame.midX, y: iconFrame.midY)
            print("NATIVE_TAB title=\(title);bar=\(barFrame);button=\(buttonFrame);icon=\(iconFrame);contact=\(center)")
            contact = center
            return true
        }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: 2 * timeout) == .completed,
              let contact, app.state == .runningForeground,
              ProcessInfo.processInfo.systemUptime <= deadline else {
            XCTFail("The current tab must have one visible, enabled native target: " + observation)
            return false
        }
        // Both callers verify the selected tab after this single U63 contact.
        do {
            try NativeTestContacts.send([.init(start: contact, end: contact, duration: 0.1, pauseAfterLift: 0)],
                                        named: "Tab icon")
            return true
        } catch {
            XCTFail("Native tab icon contact failed: \(error)")
            return false
        }
    }
}
