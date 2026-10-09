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
        print("NATIVE_TAB title=\(title);bar=\(tabs.frame);button=\(button.frame)")
        // Exactly one physical tap on the tab's recorded region. The native
        // control can be recreated as its selected appearance changes.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
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
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<6 {
            let viewport = unobscuredViewport(for: e)
            if contained(e, in: viewport) && e.isHittable { break }
            let above = e.exists && usable(e.frame) && e.frame.minY < viewport.minY
            // A virtualized preceding row keeps its known search direction;
            // a real partial frame takes precedence over that initial hint.
            if above || (!e.exists && searchEarlierRows) { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(e.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(contained(e, in: contentViewport), app.debugDescription)
        let footer = app.buttons["次へ"]
        XCTAssertFalse(
            title != "次へ" && footer.exists && footer.isHittable && e.frame.maxY > footer.frame.minY,
            "Target remains covered by the setup footer")
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
        !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.height > 0
            && [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite)
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
    private func unobscuredViewport(for element: XCUIElement, navigation: String? = nil) -> CGRect {
        var frame = contentViewport(navigation: navigation)
        let footer = app.buttons["次へ"]
        let isFooter = element.exists && element.label.hasPrefix("次へ")
        if footer.exists && footer.isHittable && !isFooter,
            usable(footer.frame), footer.frame.minY > frame.minY
        {
            frame.size.height = max(0, min(frame.maxY, footer.frame.minY) - frame.minY)
        }
        return frame
    }
    func visible(_ e: XCUIElement, navigation: String? = nil, searchEarlierRows: Bool = false) -> XCUIElement {
        for _ in 0..<6 {
            let viewport = unobscuredViewport(for: e, navigation: navigation)
            if contained(e, in: viewport) { return e }
            // Do not drag against a navigation transition or a returning
            // scroll bounce. Strict full containment still decides success.
            let settled = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in
                    self.contained(e, in: self.unobscuredViewport(for: e, navigation: navigation))
                }, object: app)
            if XCTWaiter.wait(for: [settled], timeout: 2) == .completed { return e }
            let current = unobscuredViewport(for: e, navigation: navigation)
            let frame = e.exists ? e.frame : CGRect.null
            print("UI_VISIBLE frame=\(frame);viewport=\(current);navigation=\(navigation ?? "current")")
            if (usable(frame) && frame.minY < current.minY) || (!usable(frame) && searchEarlierRows) {
                app.swipeDown()
            } else { app.swipeUp() }
        }
        let viewport = unobscuredViewport(for: e, navigation: navigation)
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
        let controls = row.descendants(matching: .switch)
        XCTAssertEqual(controls.count, 1, "The row must expose exactly one native switch")
        let control = controls.element(boundBy: 0)
        guard control.waitForExistence(timeout: 45) else {
            XCTFail("Native switch is absent")
            return
        }
        let frame = control.frame
        let outer = row.frame
        guard usable(outer), usable(frame), outer.contains(frame),
            contentViewport(navigation: navigation).contains(frame),
            control.isEnabled, control.isHittable
        else {
            XCTFail("Native switch has no safe hit region: " + app.debugDescription)
            return
        }
        let page = app.frame
        guard usable(page), page.contains(frame) else {
            XCTFail("Native switch is outside its application window")
            return
        }
        let state = control.value as? String
        let rowState = row.value as? String
        guard let state, let rowState, ["0", "1"].contains(state), rowState == state else {
            XCTFail("Native switch state must be known and agree with its row")
            return
        }
        let point = CGPoint(x: frame.minX + frame.width * (state == "0" ? 0.75 : 0.25), y: frame.midY)
        print(
            "NATIVE_SWITCH row=\(outer);control=\(frame);point=\(point);rowState=\(rowState);controlState=\(state)"
        )
        // Compare one point on the opposite side of the observed real track.
        // This is a physical operation, not a requested-value injection. A
        // nested AX reference must not resolve a different origin at touch time.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - page.minX, dy: point.y - page.minY)).press(forDuration: 0.1)
    }
}
