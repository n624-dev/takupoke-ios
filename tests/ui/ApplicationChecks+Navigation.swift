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
        guard pressNativeTabIcon(title, in: app, timeout: 45) else { return }
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let current = self.app.tabBars.buttons[title]
                return current.exists && current.isSelected
            }, object: nil)
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
        guard navigation.waitForExistence(timeout: 10) else {
            XCTFail("Toolbar navigation bar did not appear: " + bar)
            return
        }
        let controls = navigation.buttons.matching(NSPredicate(format: "label == %@ OR identifier == %@", title, title))
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        let scale = UIScreen.main.scale
        var observed: XCUIElement?
        var observation = "no matching control observation"
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline else { return false }
            let buttons = controls.allElementsBoundByAccessibilityElement
            observation = "matching native buttons=\(buttons.count)"
            if buttons.count > 1 { return true }
            guard let button = buttons.first, ProcessInfo.processInfo.systemUptime < deadline,
                let snapshot = try? button.snapshot(),
                snapshot.elementType == .button, (snapshot.label == title || snapshot.identifier == title),
                ProcessInfo.processInfo.systemUptime < deadline
            else { return false }
            let barFrame = navigation.frame
            let frame = snapshot.frame
            observation += ";bar=\(barFrame);button=\(frame);enabled=\(snapshot.isEnabled)"
            guard self.usable(frame), self.usable(barFrame),
                ObservedScreenGeometry.contains(frame, in: barFrame, scale: scale), snapshot.isEnabled,
                ProcessInfo.processInfo.systemUptime < deadline, button.isHittable,
                ProcessInfo.processInfo.systemUptime <= deadline
            else { return false }
            observed = button
            return true
        }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: 10) == .completed, let button = observed else {
            XCTFail("Toolbar control has no visible hit region on \(bar): \(title);\(observation)")
            return
        }
        print("NATIVE_TOOLBAR bar=\(bar);title=\(title);\(observation)")
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
        let keyboards = app.keyboards.allElementsBoundByAccessibilityElement
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
    func visible(_ e: XCUIElement, navigation: String? = nil, searchEarlierRows: Bool = false,
                 scrollLabels: XCUIElementQuery? = nil) -> XCUIElement {
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
                var points = drag
                if let scrollLabels {
                    // The center of the viewport can be an input or a control.
                    // Start on a visible list label with room for the same vertical drag.
                    let offset = drag.end.y - drag.start.y
                    var anchor: CGPoint?
                    for label in scrollLabels.allElementsBoundByAccessibilityElement {
                        let bounds = label.frame
                        let center = CGPoint(x: bounds.midX, y: bounds.midY)
                        let end = CGPoint(x: center.x, y: center.y + offset)
                        if ObservedScreenGeometry.contains(bounds, in: current, scale: UIScreen.main.scale),
                           current.contains(end), label.isHittable {
                            anchor = center
                            break
                        }
                    }
                    guard let anchor else {
                        XCTFail("No visible list label with room for the vertical drag")
                        return e
                    }
                    points = (anchor, CGPoint(x: anchor.x, y: anchor.y + offset))
                    print("UI_VISIBLE anchor-start=\(points.start);anchor-end=\(points.end)")
                }
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let appFrame = app.frame
                let start = origin.withOffset(CGVector(dx: points.start.x - appFrame.minX, dy: points.start.y - appFrame.minY))
                let end = origin.withOffset(CGVector(dx: points.end.x - appFrame.minX, dy: points.end.y - appFrame.minY))
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
    func tapNativeSwitch(_ row: XCUIElement, navigation: String? = nil, dragThumb: Bool = false,
                         thumbDragDuration: TimeInterval? = nil) {
        _ = visible(row, navigation: navigation)
        // Observe the surrounding layout before retaining a native identity.
        // Revalidate every safety condition inside the original native deadline.
        var captured: (control: XCUIElement, outer: CGRect, frame: CGRect, state: String, rowState: String)?
        var ambiguous = false
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let page = self.app.frame
            let outer = row.frame
            guard self.usable(page), self.usable(outer), page.contains(outer),
                  self.contentViewport(navigation: navigation).contains(outer),
                  row.isEnabled, row.isHittable,
                  let rowState = row.value as? String, ["0", "1"].contains(rowState) else { return false }
            let current = row.descendants(matching: .switch).allElementsBoundByAccessibilityElement
            if current.count > 1 { ambiguous = true; return true }
            // Read this exact child's geometry, state and availability in one AX
            // snapshot. Keep hittability live on the same element used for input.
            guard let control = current.first, let observed = try? control.snapshot(),
                  observed.elementType == .switch else { return false }
            let frame = observed.frame
            guard self.usable(frame), outer.contains(frame), observed.isEnabled,
                  let state = observed.value as? String, ["0", "1"].contains(state),
                  rowState == state, control.isHittable else { return false }
            captured = (control, outer, frame, state, rowState)
            return true
        }, object: app)
        let outcome = XCTWaiter.wait(for: [ready], timeout: 45)
        guard outcome == .completed, !ambiguous, let proof = captured else {
            XCTFail("The row must expose one operable, fully visible native switch with matching state within 45 seconds")
            return
        }
        let control = proof.control, outer = proof.outer, frame = proof.frame
        let state = proof.state, rowState = proof.rowState
        let point = CGPoint(x: frame.minX + frame.width * (state == "0" ? 0.25 : 0.75), y: frame.midY)
        let gesture = thumbDragDuration.map { "timed-thumb-drag-\($0)" }
            ?? (dragThumb ? "thumb-drag" : "short-contact-50ms")
        print(
            "NATIVE_SWITCH row=\(outer);control=\(frame);observedPoint=\(point);rowState=\(rowState);controlState=\(state);target=native-element;method=\(gesture)"
        )
        if let thumbDragDuration {
            // Preserve the observed switch and move its thumb once at explicit times.
            let stop = CGPoint(x: frame.minX + frame.width * (state == "0" ? 0.75 : 0.25), y: frame.midY)
            do {
                try NativeTestContacts.send([.init(start: point, end: stop, duration: thumbDragDuration, pauseAfterLift: 0)],
                                            named: "Native switch thumb drag")
            } catch {
                XCTFail("Native switch thumb drag failed: \(error)")
            }
            return
        }
        if dragThumb {
            // Move the observed thumb once across this switch. The native pan
            // recognizer can commit even when the simulator coalesces touch times.
            let start = control.coordinate(withNormalizedOffset: CGVector(dx: state == "0" ? 0.25 : 0.75, dy: 0.5))
            let finish = control.coordinate(withNormalizedOffset: CGVector(dx: state == "0" ? 0.75 : 0.25, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: finish, withVelocity: .slow, thenHoldForDuration: 0)
            return
        }
        // N239: the normal tap delivered only 5.58ms after relaunch, while
        // successful contacts took 73-85ms. Request one short 50ms contact;
        // do not restore N212's cancelled 100ms hold or resend input.
        // The caller must still verify actual UI and saved values within 45 seconds.
        control.coordinate(withNormalizedOffset: CGVector(
            dx: state == "0" ? 0.25 : 0.75, dy: 0.5)).press(forDuration: 0.05)
    }
}
