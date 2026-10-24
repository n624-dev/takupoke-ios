import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func back(to title: String) {
        let old = app.navigationBars.firstMatch
        let oldTitle = old.label
        old.buttons.element(boundBy: 0).tap()
        if oldTitle != title {
            XCTAssertTrue(app.navigationBars[oldTitle].waitForNonExistence(timeout: 10), app.debugDescription)
        }
        screen(title)
    }
    func tab(_ title: String) {
        let tabs = app.tabBars.firstMatch
        let button = tabs.buttons[title]
        guard tabs.waitForExistence(timeout: 45), button.waitForExistence(timeout: 45),
            usable(tabs.frame), contained(button, in: tabs.frame), button.isEnabled, button.isHittable
        else {
            XCTFail("Tab has no visible native hit region: " + app.debugDescription)
            return
        }
        let icons = button.images.allElementsBoundByIndex
        guard icons.count == 1, contained(icons[0], in: button.frame),
            contained(icons[0], in: tabs.frame), icons[0].isHittable
        else {
            XCTFail("Tab requires one visible native icon inside its current button: " + app.debugDescription)
            return
        }
        print("NATIVE_TAB title=\(title);bar=\(tabs.frame);button=\(button.frame);icon=\(icons[0].frame)")
        // Observe the unique icon inside this same native button for each tap.
        // U63: compare one bounded contact with the unsuccessful tap() route.
        // Keep the same observed point and the original 45-second selection check.
        icons[0].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let current = self.app.tabBars.buttons[title]
                return current.exists && current.isSelected
            }, object: app)
        guard XCTWaiter.wait(for: [selected], timeout: 45) == .completed else {
            recoveryScreenshot("tab-selection-unresolved-" + title)
            XCTFail("Native tab tap did not select its current control: " + app.debugDescription)
            return
        }
        screen(title == "ホーム" ? "たくポケ" : title)
    }
    func tap(_ title: String, searchEarlierRows: Bool = false) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).element(boundBy: 0)
        for _ in 0..<6 {
            let viewport = bodyViewport()
            if contained(e, in: viewport) && e.isHittable { break }
            let above = e.exists && usable(e.frame) && e.frame.minY < viewport.minY
            // A virtualized preceding row keeps its known search direction;
            // a real partial frame takes precedence over that initial hint.
            if above || (!e.exists && searchEarlierRows) { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(e.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(contained(e, in: bodyViewport()), app.debugDescription)
        XCTAssertTrue(e.isHittable, app.debugDescription)
        e.tap()
    }
    func tapToolbar(_ title: String, bar: String) {
        let navigation = app.navigationBars[bar]
        XCTAssertTrue(navigation.waitForExistence(timeout: 10), app.debugDescription)
        let button = navigation.buttons[title]
        guard button.waitForExistence(timeout: 10), usable(navigation.frame),
            contained(button, in: navigation.frame), button.isEnabled, button.isHittable
        else {
            XCTFail(
                "Toolbar control has no visible hit region on its own navigation bar: " + app.debugDescription
            )
            return
        }
        button.tap()
    }
    func tapSetupNext(from title: String) {
        let navigation = app.navigationBars[title]
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", "次へ"))
        guard navigation.waitForExistence(timeout: 45), buttons.count == 1 else {
            XCTFail("Setup must expose one next button on its current page")
            return
        }
        let button = buttons.element(boundBy: 0)
        let frame = button.frame
        let page = app.frame
        let bar = navigation.frame
        // The safe-area footer is outside the scrolling body. A tab bar from
        // the presenting Settings page must not clip this sheet's hit region.
        guard usable(frame), usable(page), usable(bar), page.contains(frame), frame.minY >= bar.maxY,
            button.isEnabled, button.isHittable
        else {
            XCTFail("Setup footer has no visible native hit region: " + app.debugDescription)
            return
        }
        print("SETUP_FOOTER page=\(title);button=\(frame)")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    func heading(_ title: String) -> XCUIElement {
        visible(app.staticTexts[title].firstMatch)
    }
    func materialSection(_ title: String, on page: String) -> XCUIElement {
        let identifiers = [
            "状態": "material-state-section", "操作": "material-actions-section",
            "ファイル情報": "material-file-section", "解析結果": "material-analysis-section",
        ]
        let matches = app.staticTexts.matching(identifier: identifiers[title]!)
        let header = matches.element(boundBy: 0)
        _ = visible(header, navigation: page)
        // A List can omit an offscreen header from AX until it is scrolled in.
        XCTAssertEqual(matches.count, 1, "Require the actual section header, not its row label")
        XCTAssertEqual(header.label, title)
        return header
    }
    func usable(_ frame: CGRect) -> Bool {
        ObservedScreenGeometry.usable(frame)
    }
    var contentViewport: CGRect {
        contentViewport(navigation: nil)
    }
    private func observedKeyboardFrame() -> CGRect? {
        let keyboards = app.keyboards.allElementsBoundByIndex
        XCTAssertLessThanOrEqual(keyboards.count, 1, "Keyboard geometry must be unique")
        guard keyboards.count == 1 else { return nil }
        let frame = keyboards[0].frame
        XCTAssertTrue(usable(frame), "Present keyboard must have finite positive geometry")
        return frame
    }
    func contentViewport(navigation: String?) -> CGRect {
        let frame = app.frame
        let bar = navigation.map { app.navigationBars[$0] } ?? app.navigationBars.firstMatch
        let top = bar.frame.maxY
        var bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : frame.maxY
        if let keyboardFrame = observedKeyboardFrame() { bottom = min(bottom, keyboardFrame.minY) }
        return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
    }
    func contained(_ element: XCUIElement, in viewport: CGRect) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return usable(frame) && usable(viewport)
            && ObservedScreenGeometry.contains(frame, in: viewport, scale: UIScreen.main.scale)
    }
    func bodyViewport(navigation: String? = nil) -> CGRect {
        let frame = contentViewport(navigation: navigation)
        // These helpers search scrolling content. The separate tapSetupNext
        // observes and operates the footer without using the body viewport.
        return ObservedScreenGeometry.excludingFooter(observedSetupFooterFrame(), from: frame)
    }
    private func observedSetupFooterFrame() -> CGRect? {
        let footers = app.buttons.matching(NSPredicate(format: "label == %@", "次へ"))
            .allElementsBoundByIndex
        XCTAssertLessThanOrEqual(footers.count, 1, "Setup footer geometry must be unique")
        guard !footers.isEmpty else { return nil }
        guard footers.count == 1 else { return .null }
        let frame = footers[0].frame
        // A visible footer obscures the body even when it cannot be tapped.
        // Query interactive hittability only when actually operating a control.
        return usable(frame) ? frame : .null
    }
    func visible(_ e: XCUIElement, navigation: String? = nil, searchEarlierRows: Bool = false) -> XCUIElement {
        for _ in 0..<6 {
            let viewport = bodyViewport(navigation: navigation)
            if contained(e, in: viewport) { return e }
            // Do not drag against a navigation transition or a returning
            // scroll bounce. Strict full containment still decides success.
            let settled = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    self.contained(e, in: self.bodyViewport(navigation: navigation))
                }, object: app)
            if XCTWaiter.wait(for: [settled], timeout: 2) == .completed { return e }
            let current = bodyViewport(navigation: navigation)
            guard usable(current) else {
                print("UI_VISIBLE unresolved-viewport;navigation=\(navigation ?? "current")")
                continue
            }
            let frame = e.exists ? e.frame : CGRect.null
            print("UI_VISIBLE frame=\(frame);viewport=\(current);navigation=\(navigation ?? "current")")
            if let drag = ObservedScreenGeometry.scrollDrag(for: frame, in: current) {
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let appFrame = app.frame
                let start = origin.withOffset(CGVector(dx: drag.start.x - appFrame.minX, dy: drag.start.y - appFrame.minY))
                let end = origin.withOffset(CGVector(dx: drag.end.x - appFrame.minX, dy: drag.end.y - appFrame.minY))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0)
            } else if (usable(frame) && frame.minY < current.minY) || (!usable(frame) && searchEarlierRows) {
                app.swipeDown()
            } else { app.swipeUp() }
        }
        let viewport = bodyViewport(navigation: navigation)
        print(
            "UI_VISIBLE final-frame=\(e.exists ? e.frame : CGRect.null);viewport=\(viewport);navigation=\(navigation ?? "current")"
        )
        XCTAssertTrue(
            contained(e, in: viewport), "Element remains outside the visible content: " + app.debugDescription
        )
        return e
    }
    func tapNativeSwitch(_ row: XCUIElement, navigation: String? = nil) {
        _ = visible(row, navigation: navigation)
        // Observe the surrounding layout before retaining a native identity.
        // Keep the outer row as a logical query while it can be recycled.
        let viewport = contentViewport(navigation: navigation)
        let page = app.frame
        let outer = row.frame
        let rowEnabled = row.isEnabled, rowHittable = row.isHittable
        let rowState = row.value as? String
        var capturedControl: XCUIElement?
        var ambiguous = false
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let current = row.descendants(matching: .switch).allElementsBoundByAccessibilityElement
            if current.count > 1 { ambiguous = true; return true }
            guard let control = current.first, control.exists else { return false }
            capturedControl = control
            return true
        }, object: app)
        let outcome = XCTWaiter.wait(for: [ready], timeout: 45)
        guard outcome == .completed, !ambiguous, let control = capturedControl else {
            XCTFail("The row must expose exactly one native switch within 45 seconds")
            return
        }
        let frame = control.frame
        let state = control.value as? String
        guard usable(outer), usable(frame), outer.contains(frame),
            viewport.contains(outer), rowEnabled, rowHittable,
            control.isEnabled, control.isHittable
        else {
            XCTFail("Native switch has no safe hit region: " + app.debugDescription)
            return
        }
        guard usable(page), page.contains(outer) else {
            XCTFail("Native switch is outside its application window")
            return
        }
        guard let state, let rowState, ["0", "1"].contains(state), rowState == state else {
            XCTFail("Native switch state must be known and agree with its row")
            return
        }
        let point = CGPoint(x: frame.minX + frame.width * (state == "0" ? 0.25 : 0.75), y: frame.midY)
        print(
            "NATIVE_SWITCH row=\(outer);control=\(frame);observedPoint=\(point);rowState=\(rowState);controlState=\(state);target=native-element;method=brief-contact;duration=0.1"
        )
        // Retain U64's one brief contact and point, now bound to the observed
        // native identity instead of re-traversing the row's indexed child.
        // The caller must still verify actual UI and saved values within 45 seconds.
        control.coordinate(withNormalizedOffset: CGVector(
            dx: state == "0" ? 0.25 : 0.75, dy: 0.5)).press(forDuration: 0.1)
    }
}
