import XCTest
import UIKit

func pressNativeTabIcon(_ title: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
    guard app.tabBars.firstMatch.waitForExistence(timeout: timeout) else {
        XCTFail("Tab bar must exist: " + app.debugDescription); return false
    }
    let bars = app.tabBars.allElementsBoundByAccessibilityElement
    guard bars.count == 1 else {
        XCTFail("Tab bar must have one current native identity"); return false
    }
    let tabs = bars[0]
    guard tabs.buttons[title].waitForExistence(timeout: timeout) else {
        XCTFail("Tab button must exist: " + app.debugDescription); return false
    }
    let buttons = tabs.buttons.matching(NSPredicate(
        format: "identifier == %@ OR label == %@", title, title)).allElementsBoundByAccessibilityElement
    guard buttons.count == 1 else {
        XCTFail("Tab button must have one current native identity"); return false
    }
    let button = buttons[0], barFrame = tabs.frame, buttonFrame = button.frame
    let scale = UIScreen.main.scale
    guard ObservedScreenGeometry.usable(barFrame), ObservedScreenGeometry.usable(buttonFrame),
        ObservedScreenGeometry.contains(buttonFrame, in: barFrame, scale: scale),
        button.isEnabled, button.isHittable else {
        XCTFail("Tab has no visible native hit region: " + app.debugDescription); return false
    }
    let icons = button.images.allElementsBoundByAccessibilityElement
    guard icons.count == 1, icons[0].exists else {
        XCTFail("Tab requires one current native icon"); return false
    }
    let icon = icons[0], iconFrame = icon.frame
    guard ObservedScreenGeometry.usable(iconFrame),
        ObservedScreenGeometry.contains(iconFrame, in: buttonFrame, scale: scale),
        ObservedScreenGeometry.contains(iconFrame, in: barFrame, scale: scale), icon.isHittable else {
        XCTFail("Tab requires one visible native icon inside its current button: " + app.debugDescription); return false
    }
    print("NATIVE_TAB title=\(title);bar=\(barFrame);button=\(buttonFrame);icon=\(iconFrame)")
    // Bind this attempt's real identities and read each frame once (N213).
    // Both callers verify the selected tab after this single U63 contact.
    icon.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
    return true
}
