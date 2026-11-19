import XCTest
import UIKit

extension SimulatorIdentityTestCase {
    func pressNativeTabIcon(_ title: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        var deadline = ProcessInfo.processInfo.systemUptime + timeout
        var foundBar = false
        let scale = UIScreen.main.scale
        var contact: CGVector?
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
            // These frames and the enabled state come from the same AX snapshot.
            let icon = icons[0]
            let appFrame = root.frame, barFrame = bar.frame, buttonFrame = button.frame, iconFrame = icon.frame
            guard ObservedScreenGeometry.usable(appFrame), ObservedScreenGeometry.usable(barFrame),
                  ObservedScreenGeometry.usable(buttonFrame), ObservedScreenGeometry.usable(iconFrame),
                  ObservedScreenGeometry.contains(barFrame, in: appFrame, scale: scale),
                  ObservedScreenGeometry.contains(buttonFrame, in: barFrame, scale: scale),
                  ObservedScreenGeometry.contains(iconFrame, in: buttonFrame, scale: scale),
                  ObservedScreenGeometry.contains(iconFrame, in: barFrame, scale: scale),
                  button.isEnabled, ProcessInfo.processInfo.systemUptime < deadline else { return false }
            // Bind the current bar and all of the selected button's images
            // once. Compare the image's own snapshot before using its hit region.
            let liveBars = app.tabBars.allElementsBoundByAccessibilityElement
            observation += "; current native bars=\(liveBars.count)"
            if liveBars.count > 1 { return true }
            guard let liveBar = liveBars.first, liveBar.frame == barFrame else { return false }
            let candidates = liveBar.buttons.matching(identifier: title).allElementsBoundByAccessibilityElement
            var liveButtons: [(element: XCUIElement, snapshot: any XCUIElementSnapshot)] = []
            for candidate in candidates {
                guard let current = try? candidate.snapshot() else { return false }
                if current.elementType == .button && (current.identifier == title || current.label == title) {
                    liveButtons.append((candidate, current))
                }
            }
            observation += "; current matching buttons=\(liveButtons.count)"
            if liveButtons.count > 1 { return true }
            guard let (liveButton, current) = liveButtons.first,
                  current.identifier == button.identifier, current.label == button.label,
                  current.isEnabled, current.frame == buttonFrame, liveButton.isHittable else { return false }
            let liveIcons = liveButton.images.allElementsBoundByAccessibilityElement
            observation += "; current native images=\(liveIcons.count)"
            if liveIcons.count > 1 { return true }
            guard let liveIcon = liveIcons.first, let currentIcon = try? liveIcon.snapshot(),
                  currentIcon.elementType == .image, currentIcon.identifier == icon.identifier,
                  currentIcon.label == icon.label, currentIcon.frame == iconFrame, liveIcon.isHittable,
                  ProcessInfo.processInfo.systemUptime <= deadline else { return false }
            let center = CGVector(dx: iconFrame.midX - appFrame.minX, dy: iconFrame.midY - appFrame.minY)
            print("NATIVE_TAB title=\(title);bar=\(barFrame);button=\(buttonFrame);icon=\(iconFrame);contact=\(center)")
            contact = center
            return true
        }, object: app)
        guard XCTWaiter.wait(for: [ready], timeout: 2 * timeout) == .completed, let contact else {
            XCTFail("The current tab must have one visible, operable native icon: " + observation); return false
        }
        // Both callers verify the selected tab after this single U63 contact.
        app.coordinate(withNormalizedOffset: .zero).withOffset(contact).press(forDuration: 0.1)
        return true
    }
}
