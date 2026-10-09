import XCTest
import UIKit
import CryptoKit

final class ApplicationChecks: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        let initialConditions: [String: [String]] = [
            "testSettingsAccountDataAndFileDetails": ["--ai-feature-probe"],
            "testTimetableDynamicTypeScalesAndRestoresStandardLayout": ["--grid-probe"],
            "testTimetableUsesSystemTextSize": ["--grid-probe", "--system-text-size"],
            "testTimetableCommonClocksAndEventOnlyWeekScale": ["--grid-probe", "--normal-only"],
            "testEmptyDataCanBeConfigured": ["--empty-fixture"],
            "testChangedAccountDataNoticeOpensSharedAcquisition": ["--updated-revisions"],
            "testFileFailuresKeepResultsAndStayInTheirOwnDetails": ["--failed-refresh"],
            "testVoiceOverReadsTimetableCard": ["--mapped-names"],
            "testNotificationControlsAndAppearance": ["--theme-probe", "--notification-permission-probe"],
            "testChangedDataProducesOneLocalNotification": ["--notification-permission-probe"],
            "testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption": ["--recovery-preview"],
            "testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis": ["--recovery-preview", "--recovery-parallel"],
            "testRecoveryClosingKeepsFormalAndModelManagementIsAccessible": ["--recovery-preview"],
            "testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption": ["--recovery-preview", "--recovery-exam"],
            "testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster": ["--recovery-ocr-probe"],
            "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork": ["--selection-snapshot", "--normal-only"],
            "testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair": ["--events-cache-corrupt"],
            "testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates": ["--events-year-coverage", "--normal-only"],
            "testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch": ["--change-row-skip"],
        ]
        for (method, arguments) in initialConditions where name.contains(method) {
            app.launchArguments += arguments
        }
        #if !TAKUPOKE_VOICEOVER_AUTOMATION
        if name.contains("testVoiceOverReadsTimetableCard") { return }
        #endif
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 30), app.debugDescription)
    }
    private func launchReady() {
        // One launch after confirmed process termination. A persistence check
        // must not overlap the previous process or be rescued by a relaunch.
        if app.state != .notRunning { app.terminate() }
        guard app.wait(for: .notRunning, timeout: 45) else {
            XCTFail("Previous fixture process did not terminate"); return
        }
        print("UI_LAUNCH terminated; starting one new process")
        app.launch()
        guard app.wait(for: .runningForeground, timeout: 45) else {
            XCTFail("New fixture process did not enter foreground"); return
        }
        XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout: 45), app.debugDescription)
    }
    private func screen(_ title: String) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), app.debugDescription)
    }

    func testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch() {
        func openChanges() {
            tab("設定")
            visible(app.buttons["時間割ファイル"]).tap(); screen("時間割ファイル")
            let detail = app.buttons["時間割変更の詳細を見る"]
            XCTAssertTrue(detail.waitForExistence(timeout: 15), app.debugDescription)
            visible(detail).tap(); screen("時間割変更")
        }
        openChanges()
        visible(app.buttons["警告を確認して内容を見る"]).tap()
        app.alerts.buttons["確認して表示"].tap(); screen("内容の確認")
        let apply = app.buttons["change-apply-skips"]
        XCTAssertTrue(apply.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(apply.isEnabled)
        for number in [3, 4] {
            let toggle = app.switches["change-skip-row-\(number)"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 15), app.debugDescription)
            tapNativeSwitch(toggle, navigation: "内容の確認")
            let changed = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed)
        }
        visible(apply).tap()
        let alert = app.alerts["選んだ行を除外して読み込む"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        alert.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["内容の確認"].exists)
        visible(apply).tap(); alert.buttons["除外して読み込む"].tap()
        let count = app.staticTexts["change-skipped-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(count.label.contains("2行"), count.label)
        XCTAssertTrue(visible(app.staticTexts["架空科目C"]).exists)
        XCTAssertFalse(app.staticTexts["架空除外科目B"].exists)
        app.terminate(); app.launchArguments.removeAll { $0 == "--reset-fixture" }; launchReady()
        openChanges()
        XCTAssertTrue(count.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(count.label.contains("2行"), count.label)
        XCTAssertTrue(visible(app.staticTexts["架空科目C"]).exists)
        XCTAssertFalse(app.staticTexts["架空除外科目B"].exists)
    }
    private func back(to title: String) {
        let old = app.navigationBars.firstMatch
        let oldTitle = old.label
        old.buttons.element(boundBy: 0).tap()
        if oldTitle != title { XCTAssertTrue(app.navigationBars[oldTitle].waitForNonExistence(timeout: 10), app.debugDescription) }
        screen(title)
    }
    private func tab(_ title: String) {
        let tabs = app.tabBars.firstMatch
        let button = tabs.buttons[title]
        guard tabs.waitForExistence(timeout: 45), button.waitForExistence(timeout: 45),
              usable(tabs.frame), contained(button, in: tabs.frame), button.isEnabled, button.isHittable else {
            XCTFail("Tab has no visible native hit region: " + app.debugDescription); return
        }
        print("NATIVE_TAB title=\(title);bar=\(tabs.frame);button=\(button.frame)")
        // Exactly one physical tap on the tab's recorded region. The native
        // control can be recreated as its selected appearance changes.
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let current = self.app.tabBars.buttons[title]
            return current.exists && current.isSelected
        }, object: app)
        guard XCTWaiter.wait(for: [selected], timeout: 45) == .completed else {
            recoveryScreenshot("tab-selection-unresolved-" + title)
            XCTFail("Native tab tap did not select its current control: " + app.debugDescription); return
        }
        screen(title == "ホーム" ? "たくポケ" : title)
    }
    private func tap(_ title: String, searchEarlierRows: Bool = false) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        for _ in 0..<6 {
            let viewport = unobscuredViewport(for: e)
            if contained(e, in: viewport) && e.isHittable { break }
            let above = e.exists && usable(e.frame) && e.frame.minY < viewport.minY
            // A virtualized preceding row keeps its known search direction;
            // a real partial frame takes precedence over that initial hint.
            if above || (!e.exists && searchEarlierRows) { app.swipeDown() }
            else { app.swipeUp() }
        }
        XCTAssertTrue(e.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(contained(e, in: contentViewport), app.debugDescription)
        let footer = app.buttons["次へ"]
        XCTAssertFalse(title != "次へ" && footer.exists && footer.isHittable && e.frame.maxY > footer.frame.minY,
                       "Target remains covered by the setup footer")
        XCTAssertTrue(e.isHittable, app.debugDescription)
        e.tap()
    }
    private func tapToolbar(_ title: String, bar: String) {
        let navigation = app.navigationBars[bar]
        XCTAssertTrue(navigation.waitForExistence(timeout: 10), app.debugDescription)
        let button = navigation.buttons[title]
        guard button.waitForExistence(timeout: 10), usable(navigation.frame),
              contained(button, in: navigation.frame), button.isEnabled, button.isHittable else {
            XCTFail("Toolbar control has no visible hit region on its own navigation bar: " + app.debugDescription)
            return
        }
        button.tap()
    }
    private func tapSetupNext(from title: String) {
        let navigation = app.navigationBars[title]
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", "次へ"))
        guard navigation.waitForExistence(timeout: 45), buttons.count == 1 else {
            XCTFail("Setup must expose one next button on its current page"); return
        }
        let button = buttons.element(boundBy: 0)
        let frame = button.frame, page = app.frame, bar = navigation.frame
        // The safe-area footer is outside the scrolling body. A tab bar from
        // the presenting Settings page must not clip this sheet's hit region.
        guard usable(frame), usable(page), usable(bar), page.contains(frame), frame.minY >= bar.maxY,
              button.isEnabled, button.isHittable else {
            XCTFail("Setup footer has no visible native hit region: " + app.debugDescription); return
        }
        print("SETUP_FOOTER page=\(title);button=\(frame)")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
    private func heading(_ title: String) -> XCUIElement {
        visible(app.staticTexts[title].firstMatch)
    }
    private func materialSection(_ title: String, on page: String) -> XCUIElement {
        let identifiers = ["状態": "material-state-section", "操作": "material-actions-section",
                           "ファイル情報": "material-file-section", "解析結果": "material-analysis-section"]
        let matches = app.staticTexts.matching(identifier: identifiers[title]!)
        let header = matches.element(boundBy: 0)
        _ = visible(header, navigation: page)
        // A List can omit an offscreen header from AX until it is scrolled in.
        XCTAssertEqual(matches.count, 1, "Require the actual section header, not its row label")
        XCTAssertEqual(header.label, title)
        return header
    }
    private func usable(_ frame: CGRect) -> Bool {
        !frame.isNull && !frame.isInfinite && frame.width > 0 && frame.height > 0 &&
            [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite)
    }
    private var contentViewport: CGRect {
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
    private func contentViewport(navigation: String?) -> CGRect {
        let frame = app.frame
        let bar = navigation.map { app.navigationBars[$0] } ?? app.navigationBars.firstMatch
        let top = bar.frame.maxY
        var bottom = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame.minY : frame.maxY
        if let keyboardFrame = observedKeyboardFrame() { bottom = min(bottom, keyboardFrame.minY) }
        return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
    }
    private func contained(_ element: XCUIElement, in viewport: CGRect) -> Bool {
        guard element.exists else { return false }
        let frame = element.frame
        return usable(frame) && usable(viewport) && viewport.contains(frame)
    }
    private func unobscuredViewport(for element: XCUIElement, navigation: String? = nil) -> CGRect {
        var frame = contentViewport(navigation: navigation)
        let footer = app.buttons["次へ"]
        let isFooter = element.exists && element.label.hasPrefix("次へ")
        if footer.exists && footer.isHittable && !isFooter,
           usable(footer.frame), footer.frame.minY > frame.minY {
            frame.size.height = max(0, min(frame.maxY, footer.frame.minY) - frame.minY)
        }
        return frame
    }
    private func visible(_ e: XCUIElement, navigation: String? = nil) -> XCUIElement {
        for _ in 0..<6 {
            let viewport = unobscuredViewport(for: e, navigation: navigation)
            if contained(e, in: viewport) { return e }
            // Do not drag against a navigation transition or a returning
            // scroll bounce. Strict full containment still decides success.
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                self.contained(e, in: self.unobscuredViewport(for: e, navigation: navigation))
            }, object: app)
            if XCTWaiter.wait(for: [settled], timeout: 2) == .completed { return e }
            let current = unobscuredViewport(for: e, navigation: navigation)
            let frame = e.exists ? e.frame : CGRect.null
            print("UI_VISIBLE frame=\(frame);viewport=\(current);navigation=\(navigation ?? "current")")
            if usable(frame) && frame.minY < current.minY { app.swipeDown() }
            else { app.swipeUp() }
        }
        let viewport = unobscuredViewport(for: e, navigation: navigation)
        print("UI_VISIBLE final-frame=\(e.exists ? e.frame : CGRect.null);viewport=\(viewport);navigation=\(navigation ?? "current")")
        XCTAssertTrue(contained(e, in: viewport), "Element remains outside the visible content: " + app.debugDescription)
        return e
    }
    private func tapNativeSwitch(_ row: XCUIElement, navigation: String? = nil) {
        _ = visible(row, navigation: navigation)
        let controls = row.descendants(matching: .switch)
        XCTAssertEqual(controls.count, 1, "The row must expose exactly one native switch")
        let control = controls.element(boundBy: 0)
        guard control.waitForExistence(timeout: 45) else { XCTFail("Native switch is absent"); return }
        let frame = control.frame, outer = row.frame
        guard usable(outer), usable(frame), outer.contains(frame), contentViewport(navigation: navigation).contains(frame),
              control.isEnabled, control.isHittable else {
            XCTFail("Native switch has no safe hit region: " + app.debugDescription); return
        }
        let page = app.frame
        guard usable(page), page.contains(frame) else {
            XCTFail("Native switch is outside its application window"); return
        }
        let state = control.value as? String
        let rowState = row.value as? String
        guard let state, let rowState, ["0", "1"].contains(state), rowState == state else {
            XCTFail("Native switch state must be known and agree with its row"); return
        }
        let point = CGPoint(x: frame.minX + frame.width * (state == "0" ? 0.75 : 0.25), y: frame.midY)
        print("NATIVE_SWITCH row=\(outer);control=\(frame);point=\(point);rowState=\(rowState);controlState=\(state)")
        // Compare one point on the opposite side of the observed real track.
        // This is a physical operation, not a requested-value injection. A
        // nested AX reference must not resolve a different origin at touch time.
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - page.minX, dy: point.y - page.minY)).tap()
    }
    private func openNotificationSettings() {
        let row = app.buttons["通知"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
        _ = visible(row)
        XCTAssertTrue(row.isEnabled, app.debugDescription)
        let bounds = row.frame
        XCTAssertTrue(bounds.width > 0 && bounds.height > 0 &&
                      bounds.minY >= app.navigationBars.firstMatch.frame.maxY &&
                      bounds.maxY <= app.tabBars.firstMatch.frame.minY, app.debugDescription)
        // iOS 27 can report a fully visible SwiftUI navigation row as
        // non-hittable. Exercise its actual visible label, then require navigation.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        screen("通知")
    }
    private func enableChangeNotifications() {
        screen("通知")
        let toggle = app.switches["時間割変更"]
        _ = visible(toggle)
        let touch = app.buttons["fixture-notification-permission-touch"]
        XCTAssertTrue(touch.waitForExistence(timeout: 45), app.debugDescription)
        let touchFrame = touch.frame
        guard usable(touchFrame), contentViewport.contains(touchFrame),
              ["時間割変更", "試験・返却"].allSatisfy({ !touchFrame.intersects(app.switches[$0].frame) }) else {
            XCTFail("Permission monitor trigger overlaps a real notification control"); return
        }
        let probe = app.staticTexts["fixture-notification-permission-state"]
        let predicate = NSPredicate(format: "label BEGINSWITH[c] %@ OR label == %@ OR label == %@ OR label == %@", "Allow", "許可", "許可する", "通知を許可")
        // Permission UI can move between system processes on iOS 27. Let
        // XCTest resolve the interrupting alert rather than retaining a
        // SpringBoard element whose accessibility server has gone away.
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let allow = alert.buttons.matching(predicate).firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        print("NOTIFICATION_SWITCH before row=\(toggle.frame) value=\(String(describing: toggle.value)) state=\(probe.label)")
        recoveryScreenshot("notification-switch-before")
        tapNativeSwitch(toggle)
        // A dedicated QA-only no-op control dispatches the real alert monitor.
        // Generic app.tap() has an unspecified activation point and may toggle
        // a setting again. This target cannot grant permission or change state.
        print("NOTIFICATION_SWITCH activated state=\(probe.label)")
        var didEnable = false
        for _ in 0..<3 {
            touch.tap()
            let enabled = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: toggle)
            if XCTWaiter.wait(for: [enabled], timeout: 15) == .completed {
                didEnable = true
                break
            }
        }
        guard didEnable else {
            print("NOTIFICATION_SWITCH unresolved value=\(String(describing: toggle.value)) enabled=\(toggle.isEnabled) tree=\(app.debugDescription)")
            recoveryScreenshot("notification-switch-unresolved")
            XCTFail("Native notification switch activation did not complete permission and enablement")
            return
        }
        print("NOTIFICATION_SWITCH after value=\(String(describing: toggle.value)) state=\(probe.label)")
        XCTAssertTrue(probe.label.contains("changes=true;saved=true"), probe.label)
        if touch.exists { touch.tap() } // Close only the QA overlay after real enablement.
        XCTAssertTrue(touch.waitForNonExistence(timeout: 10), app.debugDescription)
    }
    private func dismissLesson(title: String = "授業詳細") {
        let bar = app.navigationBars[title]
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.95)))
    }
    private func openRecoveryPreview(material: String = "通常時間割", recovery: String = "時間割の復旧") {
        tab("設定"); tap("時間割ファイル"); screen("時間割ファイル")
        tap("\(material)の詳細を見る"); screen(material)
        XCTAssertTrue(app.staticTexts["fixture-recovery-formal"].firstMatch.label == "前回の正式結果を保持", app.debugDescription)
        tap("端末内で復旧する"); screen(recovery)
        tap("端末内で復旧を開始")
        _ = recoveryVisible(app.staticTexts["採用する資料全体"].firstMatch)
        _ = recoveryVisible(app.staticTexts["選択クラスだけでなく、以下の資料全体を採用します。元のPDFと読み取り結果を確認してください。"].firstMatch)
    }
    private func recoveryScreenshot(_ name: String, marker: String = "TAKUPOKE_UI_IMAGE") {
        let bytes = app.screenshot().pngRepresentation
        XCTAssertTrue((9...2 * 1024 * 1024).contains(bytes.count))
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let encoded = bytes.base64EncodedString(), chunkSize = 6000
        print("\(marker) BEGIN \(name) \(hash) \(bytes.count)")
        let characters = Array(encoded)
        for offset in stride(from: 0, to: characters.count, by: chunkSize) {
            let chunk = String(characters[offset..<min(offset + chunkSize, characters.count)])
            print("\(marker) DATA \(name) \(offset / chunkSize) \(chunk)")
        }
        print("\(marker) END \(name) \((characters.count + chunkSize - 1) / chunkSize)")
    }
    private var recoveryList: XCUIElement {
        app.collectionViews["fixture-recovery-list"].firstMatch
    }
    private var recoveryBar: XCUIElement {
        app.navigationBars.matching(NSPredicate(format: "identifier ENDSWITH %@", "の復旧")).firstMatch
    }
    private var recoveryViewport: CGRect {
        let list = recoveryList.frame
        let top = max(list.minY, recoveryBar.frame.maxY) + 12
        let bottom = min(list.maxY, app.frame.maxY - 34) - 12
        return CGRect(x: list.minX, y: top, width: list.width, height: max(0, bottom - top))
    }
    private func recoveryDrag(earlier: Bool, distance: CGFloat? = nil) {
        guard recoveryBar.exists, recoveryList.exists else {
            XCTFail("Recovery sheet disappeared before its gesture"); return
        }
        let viewport = recoveryViewport
        guard usable(viewport) else { XCTFail("Invalid recovery viewport"); return }
        let privacy = recoveryList.staticTexts["学校の資料・OCR文字・授業情報は端末内で処理され、外部のAIへ送信されません。"].firstMatch
        guard !(earlier && contained(privacy, in: viewport)) else {
            XCTFail("Target was not found before reaching the recovery list top"); return
        }
        // Begin on a passive row inside this sheet, never an editor/button,
        // the covered underlying List, or the outer sheet's dismissible gutter.
        let candidates = recoveryList.cells.allElementsBoundByIndex.filter {
            let area = $0.frame.intersection(viewport)
            return usable(area) && area.height > 36 && $0.buttons.count == 0 && $0.switches.count == 0 &&
                $0.textFields.count == 0 && $0.textViews.count == 0 && $0.pickers.count == 0 &&
                $0.pickerWheels.count == 0 && $0.staticTexts.count > 0
        }
        guard let cell = candidates.max(by: {
            earlier ? $0.frame.minY > $1.frame.minY : $0.frame.maxY < $1.frame.maxY
        }) else { XCTFail("No passive recovery row for a safe drag"); return }
        let safe = cell.frame.intersection(viewport)
        let x = max(safe.minX + 12, min(safe.maxX - 12, viewport.minX + 100))
        let y = earlier ? safe.minY + 12 : safe.maxY - 12
        let endY = earlier ? min(viewport.maxY - 12, y + (distance ?? 120)) :
            max(viewport.minY + 12, y - (distance ?? viewport.height))
        guard abs(endY - y) > 1 else { XCTFail("No room for a recovery drag"); return }
        let base = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        let origin = app.frame.origin
        base.withOffset(CGVector(dx: x - origin.x, dy: y - origin.y)).press(forDuration: 0.1,
            thenDragTo: base.withOffset(CGVector(dx: x - origin.x, dy: endY - origin.y)))
    }
    private func recoveryVisible(_ element: XCUIElement, searchEarlierRows: Bool = false) -> XCUIElement {
        for _ in 0..<12 {
            guard recoveryBar.exists, recoveryList.exists else {
                XCTFail("The recovery sheet disappeared while locating its row: " + app.debugDescription)
                return element
            }
            let viewport = recoveryViewport
            if contained(element, in: viewport) { return element }
            let earlier = element.exists && usable(element.frame) ? element.frame.minY < viewport.minY : searchEarlierRows
            recoveryDrag(earlier: earlier)
        }
        XCTAssertTrue(recoveryBar.exists && recoveryList.exists && contained(element, in: recoveryViewport),
                      "Recovery target remains outside its own sheet viewport: " + app.debugDescription)
        return element
    }
    func testRecoveryPreviewOriginalBlankFieldsAndExplicitAdoption() {
        openRecoveryPreview()
        recoveryScreenshot("ios-recovery-normal-preview")
        let fields = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "教員: 記載なし", "架空教室A")).firstMatch
        _ = recoveryVisible(fields)
        _ = recoveryVisible(app.staticTexts["空欄"].firstMatch)
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        // Stop as soon as the original button is visible. Extra downward
        // swipes at the top can dismiss the sheet through its native gesture.
        let original = recoveryVisible(app.buttons["元のPDFを確認"].firstMatch, searchEarlierRows: true)
        XCTAssertTrue(original.isHittable, app.debugDescription)
        original.tap(); screen("元のPDF")
        XCTAssertTrue(app.navigationBars["元のPDF"].exists, app.debugDescription)
        recoveryScreenshot("ios-recovery-original")
        app.navigationBars["元のPDF"].buttons["閉じる"].tap(); screen("時間割の復旧")
        let adoption = app.buttons["この資料全体の結果を使用"]
        _ = recoveryVisible(adoption)
        XCTAssertTrue(adoption.isHittable, app.debugDescription)
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        adoption.tap()
        XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout: 20), app.debugDescription)
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み")
        app.terminate(); app.launchArguments = ["--recovery-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]; launchReady()
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み", app.debugDescription)
    }
    func testSpecialRecoveryShowsMergedAndDifferentDayClocksBeforeAdoption() {
        for (index, item) in [("試験時間割", "試験時間割の復旧", "--recovery-exam", "08:05〜08:30"),
                              ("試験返却時間割", "試験返却時間割の復旧", "--recovery-return", "08:50〜09:35")].enumerated() {
            if index > 0 {
                app.terminate(); app.launchArguments = ["--reset-fixture", "--recovery-preview", item.2, "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]; launchReady()
            }
            openRecoveryPreview(material: item.0, recovery: item.1)
            _ = recoveryVisible(app.staticTexts["08:00〜09:00"].firstMatch)
            _ = recoveryVisible(app.staticTexts[item.3].firstMatch)
            recoveryScreenshot(index == 0 ? "ios-recovery-exam-preview" : "ios-recovery-return-preview")
            XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
            let adoption = app.buttons["この資料全体の結果を使用"]
            _ = recoveryVisible(adoption)
            XCTAssertTrue(adoption.isHittable, app.debugDescription); adoption.tap()
            XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout: 20), app.debugDescription)
            XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み")
            app.terminate(); app.launchArguments = ["--recovery-probe", item.2, "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]; launchReady()
            XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み", app.debugDescription)
        }
    }
    func testParallelRecoveryKeepsBothLessonsInPreviewAndFormalAnalysis() {
        openRecoveryPreview()
        for suffix in ["A", "B"] {
            _ = recoveryVisible(app.staticTexts["架空並記科目\(suffix)"])
            let paired = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                "架空並記担当\(suffix)", "架空並記教室\(suffix)")).firstMatch
            _ = recoveryVisible(paired)
        }
        let pairedFields = ["A", "B"].flatMap { suffix in
            [app.staticTexts["架空並記科目\(suffix)"],
             app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                "架空並記担当\(suffix)", "架空並記教室\(suffix)")).firstMatch]
        }
        // Align the whole pair group before measuring it. Full-list swipes
        // used to expose the last field can move the first behind the bar.
        for _ in 0..<10 {
            let top = recoveryViewport.minY
            let bottom = recoveryViewport.maxY
            guard recoveryBar.exists, recoveryList.exists,
                  pairedFields.allSatisfy({ $0.exists && usable($0.frame) }) else {
                XCTFail("Parallel fields lost their recovery sheet or geometry"); return
            }
            let first = pairedFields.first!.frame.minY, last = pairedFields.last!.frame.maxY
            if first >= top && last <= bottom { break }
            let delta = first < top ? min(140, top - first + 12) : -min(140, last - bottom + 12)
            recoveryDrag(earlier: delta > 0, distance: abs(delta))
        }
        var previousBottom: CGFloat = 0
        for suffix in ["A", "B"] {
            let subject = app.staticTexts["架空並記科目\(suffix)"]
            let metadata = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@",
                "架空並記担当\(suffix)", "架空並記教室\(suffix)")).firstMatch
            for field in [subject, metadata] {
                print("SYNTHETIC_PARALLEL_UI \(field.label) frame=\(field.frame)")
                XCTAssertTrue(field.exists && !field.frame.isEmpty && field.frame.minY >= app.navigationBars["時間割の復旧"].frame.maxY &&
                    field.frame.maxY <= app.frame.maxY && field.frame.minY >= previousBottom - 1, app.debugDescription)
                previousBottom = field.frame.maxY
            }
        }
        recoveryScreenshot("ios-recovery-parallel", marker: "TAKUPOKE_PARALLEL_UI_IMAGE")
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        let adoption = app.buttons["この資料全体の結果を使用"]
        _ = recoveryVisible(adoption)
        XCTAssertTrue(adoption.isHittable, app.debugDescription); adoption.tap()
        XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout: 20), app.debugDescription)
        app.terminate(); app.launchArguments = ["--recovery-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]; launchReady()
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "確認後に正式採用済み")
        tab("設定"); tap("時間割ファイル"); tap("通常時間割の詳細を見る"); screen("通常時間割")
        _ = heading("解析結果")
        for suffix in ["A", "B"] {
            let paired = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@ AND label CONTAINS %@",
                "架空並記科目\(suffix)", "架空並記担当\(suffix)", "架空並記教室\(suffix)")).firstMatch
            _ = visible(paired)
            XCTAssertTrue(paired.label.contains("3-IT · 月曜 · 1限"), app.debugDescription)
        }
    }
    func testRecoveryClosingKeepsFormalAndModelManagementIsAccessible() {
        openRecoveryPreview()
        app.navigationBars["時間割の復旧"].buttons["閉じる"].tap(); screen("通常時間割")
        XCTAssertEqual(app.staticTexts["fixture-recovery-formal"].firstMatch.label, "前回の正式結果を保持")
        back(to: "時間割ファイル"); back(to: "設定")
        tap("端末内AIモデル"); screen("端末内AIモデル")
        _ = heading("追加モデルは品質評価後に提供します。OSの端末内AIが利用可能な端末では追加ダウンロードは不要です。")
        XCTAssertFalse(app.buttons["モデルをダウンロード"].exists, app.debugDescription)
        recoveryScreenshot("ios-recovery-models")
    }
    func testRecoveryImageOnlyPDFUsesNativeOCRAndTopLeftRaster() {
        let result = app.staticTexts["fixture-ocr-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 10), app.debugDescription)
        let finished = expectation(for: NSPredicate(format: "label != %@", "OCR実行中"), evaluatedWith: result)
        wait(for: [finished], timeout: 60)
        let accepted = "CropBox/footer検証済み; OCR・上端座標・罫線・未読インク検証済み"
        let safelyRejected = "CropBox/footer検証済み; 低信頼OCRを安全拒否・実raster・上端座標・罫線・未読インク・空欄検証済み; confidence="
        let observedConfidence = result.label.hasPrefix(safelyRejected) ? Double(result.label.dropFirst(safelyRejected.count)) : nil
        let rejectedLowConfidence = observedConfidence.map { $0.isFinite && $0 >= 0 && $0 < 0.85 } ?? false
        XCTAssertTrue(result.label == accepted || rejectedLowConfidence, app.debugDescription)
        print("SYNTHETIC_NATIVE_OCR_RESULT " + result.label)
        let table=app.staticTexts["fixture-native-table-capture"]
        XCTAssertTrue(table.waitForExistence(timeout:5),app.debugDescription)
        XCTAssertTrue(table.label.contains("wholeDocumentQuality=UNASSESSED"),app.debugDescription)
        print(table.label)
    }

    func testMergedCardsFromAllSources() {
        tab("時間割")
        for subject in ["架空科目A", "架空試験A", "架空返却A", "架空変更A"] {
            let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", subject)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
            for _ in 0..<8 {
                let top = app.navigationBars.firstMatch.frame.maxY
                let bottom = app.tabBars.firstMatch.frame.minY
                if card.isHittable && card.frame.midY > top && card.frame.midY < bottom { break }
                if card.frame.midY <= top { app.swipeDown() } else { app.swipeUp() }
            }
            let ready = expectation(for: NSPredicate { _, _ in
                card.isHittable && card.frame.midY > self.app.navigationBars.firstMatch.frame.maxY &&
                    card.frame.midY < self.app.tabBars.firstMatch.frame.minY
            }, evaluatedWith: card)
            wait(for: [ready], timeout: 10)
            XCTAssertGreaterThan(card.frame.height, 72)
            card.tap()
            let title = subject == "架空変更A" ? "時間割変更" : "授業詳細"
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), app.debugDescription)
            dismissLesson(title: title)
        }
        XCTAssertTrue(app.staticTexts["架空行事A"].firstMatch.exists || app.buttons["架空行事A"].exists)
    }
    func testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork() {
        func openFirstLesson(_ surface: String) {
            tab(surface)
            let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目")).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
            for _ in 0..<8 {
                if card.exists && card.isHittable && card.frame.midY > app.navigationBars.firstMatch.frame.maxY && card.frame.midY < app.tabBars.firstMatch.frame.minY { break }
                if card.exists && card.frame.midY <= app.navigationBars.firstMatch.frame.maxY { app.swipeDown() } else { app.swipeUp() }
            }
            XCTAssertTrue(card.exists && card.isHittable, app.debugDescription); card.tap()
            screen("授業詳細")
        }
        for surface in ["ホーム", "時間割"] {
            // A changed raw source deliberately retains the last good analysis.
            // Start each surface from a fresh, matching source/analysis pair.
            if surface == "時間割" { app.terminate(); launchReady() }
            let initial = app.staticTexts["fixture-selection-data"].label
            openFirstLesson(surface)
            app.buttons["架空処理のみ"].tap()
            let busy = app.staticTexts["fixture-selection-busy"]
            let started = expectation(for: NSPredicate(format: "label == %@", "架空処理中"), evaluatedWith: busy)
            wait(for: [started], timeout: 5)
            XCTAssertTrue(app.navigationBars["授業詳細"].exists, app.debugDescription)
            let outcome = app.staticTexts["fixture-selection-busy-outcome"]
            XCTAssertEqual(outcome.label, "released=false;completion=pending")
            app.buttons["架空処理を終了"].tap()
            let finished = expectation(for: NSPredicate(format: "label == %@", "架空待機中"), evaluatedWith: busy)
            wait(for: [finished], timeout: 10)
            let completed = expectation(for: NSPredicate(format: "label == %@", "released=true;completion=success"), evaluatedWith: outcome)
            wait(for: [completed], timeout: 10)
            XCTAssertEqual(app.staticTexts["fixture-selection-data"].label, initial)
            XCTAssertTrue(app.navigationBars["授業詳細"].exists, app.debugDescription)
            app.buttons["架空正式更新"].tap()
            XCTAssertTrue(app.navigationBars["授業詳細"].waitForNonExistence(timeout: 15), app.debugDescription)
            XCTAssertNotEqual(app.staticTexts["fixture-selection-data"].label, initial, app.debugDescription)
            let adopted = app.staticTexts["fixture-selection-data"].label
            openFirstLesson(surface)
            app.buttons["架空原本更新"].tap()
            XCTAssertTrue(app.navigationBars["授業詳細"].waitForNonExistence(timeout: 15), app.debugDescription)
            XCTAssertNotEqual(app.staticTexts["fixture-selection-data"].label, adopted, app.debugDescription)
            print("SYNTHETIC_SELECTION_UI \(surface): busy-only kept detail; actual formal and source writes closed detail")
        }
    }
    func testHomeTimetableAndWeekCalendar() {
        XCTAssertTrue(app.staticTexts["今日の予定"].waitForExistence(timeout: 10))
        tab("時間割")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目A")).firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        // Actual merged cards must stay within the app frame.
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目A"))
        XCTAssertGreaterThan(cards.count, 0)
        let first = cards.element(boundBy: 0)
        XCTAssertGreaterThan(first.frame.height, 0)
        XCTAssertLessThanOrEqual(first.frame.maxX, app.frame.maxX + 1)
        first.tap()
        XCTAssertTrue(app.staticTexts["架空教員A"].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        dismissLesson()
        let calendar = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "月", "日から")).firstMatch
        XCTAssertTrue(calendar.waitForExistence(timeout: 5), app.debugDescription)
        calendar.tap()
        XCTAssertTrue(app.buttons["この週へ移動"].waitForExistence(timeout: 5))
        tapToolbar("キャンセル", bar: "週を選ぶ")
        XCTAssertFalse(app.buttons["この週へ移動"].exists)
        if app.buttons["翌週"].exists { tap("翌週"); XCTAssertTrue(app.buttons["前週"].exists); tap("前週") }
    }

    private func gridMetrics() throws -> [String: Any] {
        let probe = app.staticTexts["fixture-grid-metrics"]
        for _ in 0..<8 {
            if probe.exists { break }
            app.swipeUp()
        }
        XCTAssertTrue(probe.waitForExistence(timeout: 10), app.debugDescription)
        let json = try XCTUnwrap(probe.value as? String)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func selectTypeSize(_ title: String) throws -> [String: Any] {
        app.buttons["fixture-type-size"].tap()
        app.buttons[title].tap()
        return try gridMetrics()
    }

    func testTimetableDynamicTypeScalesAndRestoresStandardLayout() throws {
        tab("時間割")
        let standard = try gridMetrics()
        func number(_ key: String, in value: [String: Any]) throws -> Double {
            try XCTUnwrap(value[key] as? Double)
        }
        func assertLayout(_ metrics: [String: Any]) throws {
            let scale = try number("scale", in: metrics)
            let width = try number("width", in: metrics)
            let baseWidth = try number("baseWidth", in: metrics)
            XCTAssertGreaterThanOrEqual(scale, 1)
            XCTAssertEqual(width, baseWidth * scale, accuracy: 0.1)
            XCTAssertEqual(baseWidth * 5 + (try number("basePeriodWidth", in: metrics)) + 12,
                           try number("viewport", in: metrics), accuracy: 0.1)
            for (key, base) in [("subjectFont", 11.0), ("metadataFont", 9.0), ("eventFont", 14.0), ("periodFont", 15.0)] {
                XCTAssertEqual(try number(key, in: metrics), base * scale, accuracy: 0.01)
            }
            let heights = try XCTUnwrap(metrics["heights"] as? [Double])
            XCTAssertEqual(heights.count, 8)
            XCTAssertTrue(heights.allSatisfy { $0 >= 72 * scale })
            let cards = try XCTUnwrap(metrics["cards"] as? [[String: Any]])
            XCTAssertTrue(cards.contains { ($0["cancellation"] as? Bool) == true })
            XCTAssertEqual(Set(cards.compactMap { $0["source"] as? String }), Set(["normal", "change", "exam", "examReturn"]))
            for card in cards {
                let frame = try XCTUnwrap(card["frame"] as? [String: Double])
                XCTAssertEqual(try XCTUnwrap(frame["width"]), width, accuracy: 1)
                XCTAssertEqual(try XCTUnwrap(frame["height"]), try number("height", in: card), accuracy: 1)
                XCTAssertGreaterThanOrEqual(try XCTUnwrap(frame["height"]), try number("required", in: card) - 1)
            }
            for source in ["normal", "change", "exam", "examReturn"] {
                XCTAssertTrue(cards.contains { ($0["source"] as? String) == source &&
                    ($0["end"] as? Int ?? 0) > ($0["start"] as? Int ?? 0) })
            }
            for day in Set(cards.compactMap { $0["day"] as? String }) {
                let entries = cards.filter { ($0["day"] as? String) == day }
                for (i, first) in entries.enumerated() {
                    for second in entries.dropFirst(i + 1) where (first["lane"] as? Int) == (second["lane"] as? Int) {
                        let a = try XCTUnwrap(first["start"] as? Int)...(try XCTUnwrap(first["end"] as? Int))
                        let b = try XCTUnwrap(second["start"] as? Int)...(try XCTUnwrap(second["end"] as? Int))
                        XCTAssertFalse(a.overlaps(b))
                        let firstFrame = try XCTUnwrap(first["frame"] as? [String: Double])
                        let secondFrame = try XCTUnwrap(second["frame"] as? [String: Double])
                        let upper = a.lowerBound < b.lowerBound ? firstFrame : secondFrame
                        let lower = a.lowerBound < b.lowerBound ? secondFrame : firstFrame
                        XCTAssertLessThanOrEqual(try XCTUnwrap(upper["y"]) + (try XCTUnwrap(upper["height"])),
                                                 (try XCTUnwrap(lower["y"])) - 1)
                    }
                }
            }
        }
        try assertLayout(standard)
        XCTAssertEqual(try number("scale", in: standard), 1)
        let small = try selectTypeSize("小")
        try assertLayout(small)
        for key in ["width", "baseWidth", "subjectFont", "metadataFont", "eventFont", "periodFont", "periodWidth"] {
            XCTAssertEqual(try number(key, in: small), try number(key, in: standard), accuracy: 0.1)
        }
        var previous = standard
        for title in ["大", "最大"] {
            let enlarged = try selectTypeSize(title)
            try assertLayout(enlarged)
            XCTAssertGreaterThan(try number("scale", in: enlarged), try number("scale", in: previous))
            XCTAssertEqual(try number("baseWidth", in: enlarged), try number("baseWidth", in: standard), accuracy: 0.1)
            let oldTimes = try XCTUnwrap(previous["cards"] as? [[String: Any]]).compactMap { $0["timeFont"] as? Double }.filter { $0 > 0 }
            let newTimes = try XCTUnwrap(enlarged["cards"] as? [[String: Any]]).compactMap { $0["timeFont"] as? Double }.filter { $0 > 0 }
            XCTAssertEqual(oldTimes.count, newTimes.count)
            for (old, new) in zip(oldTimes, newTimes) { XCTAssertGreaterThan(new, old) }
            // Read actual rendered card bounds as well as the layout metrics.
            let first = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "架空科目A", "月")).firstMatch
            XCTAssertTrue(first.exists)
            XCTAssertEqual(first.frame.width, try number("width", in: enlarged), accuracy: 1)
            previous = enlarged
        }
        let restored = try selectTypeSize("標準")
        try assertLayout(restored)
        for key in ["width", "baseWidth", "subjectFont", "metadataFont", "periodWidth"] {
            XCTAssertEqual(try number(key, in: restored), try number(key, in: standard), accuracy: 0.1)
        }
        XCTAssertEqual(try XCTUnwrap(restored["heights"] as? [Double]), try XCTUnwrap(standard["heights"] as? [Double]))
    }

    func testTimetableUsesSystemTextSize() throws {
        tab("時間割")
        let metrics = try gridMetrics()
        let scale = try XCTUnwrap(metrics["scale"] as? Double)
        let category = try XCTUnwrap(metrics["systemSize"] as? String)
        XCTAssertEqual(category, try XCTUnwrap(metrics["expectedSystemSize"] as? String),
                       "The requested Simulator OS setting must actually reach the app")
        let standardOrSmaller = [UIContentSizeCategory.extraSmall, .small, .medium, .large].map(\.rawValue)
        if standardOrSmaller.contains(category) { XCTAssertEqual(scale, 1) }
        else { XCTAssertGreaterThan(scale, 1, category) }
        XCTAssertEqual(try XCTUnwrap(metrics["subjectFont"] as? Double), 11 * scale, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(metrics["width"] as? Double),
                       (try XCTUnwrap(metrics["baseWidth"] as? Double)) * scale, accuracy: 0.1)
        print("System text size: \(category); timetable scale: \(scale)")
    }

    func testTimetableCommonClocksAndEventOnlyWeekScale() throws {
        for eventsOnly in [false, true] {
            if eventsOnly {
                app.terminate()
                app.launchArguments = ["--reset-fixture", "--grid-probe", "--normal-only", "--events-only",
                    "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
                launchReady()
            }
            tab("時間割")
            for title in ["標準", "最大", "標準"] {
                let metrics = try selectTypeSize(title)
                let scale = try XCTUnwrap(metrics["scale"] as? Double)
                let heights = try XCTUnwrap(metrics["heights"] as? [Double])
                XCTAssertEqual(metrics["eventsOnly"] as? Bool, eventsOnly)
                let days = try XCTUnwrap(metrics["days"] as? [String])
                let headers = days.map { app.descendants(matching: .any)["timetable-day-" + $0].firstMatch }
                XCTAssertTrue(headers.allSatisfy(\.exists))
                // Combined accessibility elements report their text bounds.
                // Measure the actual outer view, including its aligned frame.
                let frames = try XCTUnwrap(metrics["headerFrames"] as? [String: [String: Double]])
                XCTAssertEqual(Set(frames.keys), Set(days))
                let headerHeight = try XCTUnwrap(frames[days[0]]?["height"])
                XCTAssertGreaterThan(headerHeight, 0)
                for day in days {
                    XCTAssertEqual(try XCTUnwrap(frames[day]?["height"]), headerHeight, accuracy: 1)
                }
                if eventsOnly {
                    XCTAssertEqual((metrics["cards"] as? [[String: Any]])?.count, 0)
                    let event = app.descendants(matching: .any)["timetable-event-架空行事A"].firstMatch
                    XCTAssertTrue(event.exists)
                    let sizes = try XCTUnwrap(metrics["eventSizes"] as? [String: [String: Double]])
                    XCTAssertEqual(try XCTUnwrap(sizes["架空行事A"]?["height"]), 72 * scale, accuracy: 1)
                    XCTAssertEqual(try XCTUnwrap(sizes["架空行事A"]?["width"]), try XCTUnwrap(metrics["width"] as? Double), accuracy: 1)
                    let grid = app.scrollViews["timetable-week-grid"]
                    XCTAssertTrue(grid.exists)
                    XCTAssertEqual(try XCTUnwrap(frames[days[0]]?["x"]),
                                   (try XCTUnwrap(metrics["periodWidth"] as? Double)) + 2, accuracy: 1)
                } else {
                    XCTAssertEqual((metrics["commonClocks"] as? [String])?.count, 8)
                    XCTAssertGreaterThanOrEqual(try XCTUnwrap(metrics["periodWidth"] as? Double),
                                              try XCTUnwrap(metrics["basePeriodWidth"] as? Double))
                    XCTAssertTrue(heights.allSatisfy { $0 >= 72 * scale })
                }
            }
        }
    }
    func testSettingsAccountDataAndFileDetails() {
        tab("設定")
        let ai = app.switches["use-ai-features"]
        _ = visible(ai)
        XCTAssertTrue(ai.waitForExistence(timeout: 10)); XCTAssertEqual(ai.value as? String, "0")
        XCTAssertTrue(ai.label.contains("OCR"))
        XCTAssertEqual(app.staticTexts["fixture-recovery-off-blocked"].label,"1")
        let stored = app.staticTexts["fixture-stored-ai-permission"]
        XCTAssertEqual(stored.label, "0")
        var changeOrdinal = 0
        func changeAI(to value: String) {
            changeOrdinal += 1
            XCTAssertTrue(ai.isHittable, app.debugDescription)
            XCTAssertGreaterThan(ai.frame.width, 40)
            print("AI_SWITCH before frame=\(ai.frame) UI=\(String(describing: ai.value)) stored=\(stored.label)")
            recoveryScreenshot("ai-switch-before-\(changeOrdinal)")
            // The labelled row and the inner native switch have different
            // accessibility bounds. Activate the unique real control directly.
            tapNativeSwitch(ai)
            let reflected = expectation(for:NSPredicate(format:"value == %@",value),evaluatedWith:ai)
            let saved = expectation(for:NSPredicate(format:"label == %@",value),evaluatedWith:stored)
            let completion = XCTWaiter.wait(for:[reflected,saved],timeout:45)
            guard completion == .completed else {
                print("AI_SWITCH unresolved UI=\(String(describing: ai.value)) stored=\(stored.label) tree=\(app.debugDescription)")
                recoveryScreenshot("ai-switch-unresolved-\(changeOrdinal)")
                XCTFail("Physical AI/OCR switch tap did not update both UI and stored permission")
                return
            }
            XCTAssertEqual(ai.value as? String,value)
            XCTAssertEqual(stored.label,value)
            print("AI_SWITCH after UI=\(String(describing: ai.value)) stored=\(stored.label)")
        }
        for value in ["1","0","1"] { changeAI(to:value) }
        app.terminate(); app.launchArguments.removeAll { $0 == "--reset-fixture" }; launchReady()
        tab("設定"); _ = visible(ai)
        XCTAssertEqual(ai.value as? String,"1"); XCTAssertEqual(stored.label,"1")
        changeAI(to:"0")
        app.terminate(); launchReady(); tab("設定"); _ = visible(ai)
        XCTAssertEqual(ai.value as? String,"0"); XCTAssertEqual(stored.label,"0")
        XCTAssertEqual(app.staticTexts["fixture-recovery-off-blocked"].label,"1")
        for _ in 0..<4 { app.swipeDown() }
        tap("リンク・名称・授業時刻")
        screen("リンク・名称・授業時刻")
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            tap(title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(app.staticTexts["最終取得"].exists, app.debugDescription)
            XCTAssertTrue(app.staticTexts["件数"].exists, app.debugDescription)
            back(to: "リンク・名称・授業時刻")
        }
        back(to: "設定")
        tap("学校行事")
        XCTAssertTrue(app.buttons["学校行事を更新"].waitForExistence(timeout: 5), app.debugDescription)
        let eventDetails = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "年度の学校行事の詳細を見る")).firstMatch
        XCTAssertTrue(eventDetails.waitForExistence(timeout: 5), app.debugDescription)
        eventDetails.tap()
        XCTAssertTrue(app.staticTexts["件数"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        screen("学校行事")
        back(to: "設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        XCTAssertFalse(app.buttons["学校行事を更新"].exists)
        for title in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            tap("\(title)の詳細を見る")
            screen(title)
            let stateY = materialSection("状態", on: title).frame.minY
            let operationY = materialSection("操作", on: title).frame.minY
            XCTAssertLessThan(stateY, operationY)
            _ = materialSection("ファイル情報", on: title)
            _ = materialSection("解析結果", on: title)
            _ = heading("件数")
            XCTAssertFalse(app.staticTexts["解析件数"].exists)
            XCTAssertFalse(app.staticTexts["授業枠"].exists)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "解析する")).firstMatch.exists)
            back(to: "時間割ファイル")
        }
        // Actual picker interactions are exercised by the dedicated picker suite.
    }
    func testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair() {
        let warningText = "2033年度の保存済み学校行事を読み取れません。正常な年度の結果は表示しています。該当年度を再取得してください。端末内の結果は削除していません。"
        func selectYear(_ digits: String, replacing: Bool) {
            let field = app.textFields["学校年度（空欄なら現在の学校年度）"]
            for _ in 0..<6 {
                if field.exists && field.isHittable && field.frame.minY >= app.navigationBars["学校行事"].frame.maxY { break }
                app.swipeDown()
            }
            XCTAssertTrue(field.exists && field.isHittable, app.debugDescription)
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
            field.typeText((replacing ? String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) : "") + digits)
            let entered = expectation(for: NSPredicate { _, _ in
                field.exists && field.value as? String == digits
            }, evaluatedWith: field)
            wait(for: [entered], timeout: 10)
            XCTAssertEqual(field.value as? String, digits, app.debugDescription)
            app.swipeUp() // Dismiss the number pad through the List's standard behavior.
        }
        func openSavedEvent(_ year: Int, title: String) {
            let detail = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "年度の学校行事の詳細を見る")).firstMatch
            XCTAssertTrue(detail.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertEqual(detail.label.replacingOccurrences(of: ",", with: ""), "\(year)年度の学校行事の詳細を見る", app.debugDescription)
            tap(detail.label)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), app.debugDescription)
            back(to: "学校行事")
        }
        tab("設定"); tap("学校行事"); screen("学校行事")
        selectYear("2032", replacing: false)
        let warning = app.staticTexts[warningText].firstMatch
        _ = visible(warning)
        XCTAssertTrue(app.buttons["学校行事を更新"].isEnabled, app.debugDescription)
        recoveryScreenshot("ios-events-cache-warning")
        openSavedEvent(2032, title: "架空正常行事2032")
        tap("学校行事を更新")
        let healthyUpdated = expectation(for: NSPredicate { _, _ in
            self.app.buttons["学校行事を更新"].isEnabled && self.app.staticTexts[warningText].firstMatch.exists
        }, evaluatedWith: app)
        wait(for: [healthyUpdated], timeout: 20)
        openSavedEvent(2032, title: "架空行事更新2032")
        XCTAssertTrue(warning.exists, app.debugDescription)
        selectYear("2033", replacing: true)
        _ = heading("再取得が必要")
        XCTAssertTrue(app.buttons["学校行事を再取得"].isEnabled, app.debugDescription)
        tap("学校行事を再取得")
        XCTAssertTrue(warning.waitForNonExistence(timeout: 20), app.debugDescription)
        openSavedEvent(2033, title: "架空行事更新2033")
        app.terminate()
        app.launchArguments = ["--events-cache-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady(); tab("設定"); tap("学校行事"); screen("学校行事")
        XCTAssertFalse(app.staticTexts[warningText].exists, app.debugDescription)
        XCTAssertFalse(app.staticTexts["再取得が必要"].exists, app.debugDescription)
        openSavedEvent(2033, title: "架空行事更新2033")
        print("SYNTHETIC_EVENTS_CACHE_UI healthy visible/fetch enabled; other-year fetch kept warning; actual same-year repair and process restart cleared warning")
    }
    func testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates() {
        let notice = "学校行事は未取得です。"
        let noClasses = "授業はありません。"
        func relaunch(_ arguments: [String]) {
            app.terminate()
            app.launchArguments = ["--reset-fixture", "--events-year-coverage", "--normal-only",
                "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"] + arguments
            launchReady()
        }
        func home(hasNotice: Bool, hasLesson: Bool, saysNoClasses: Bool) {
            tab("ホーム")
            _ = heading("今日の予定")
            XCTAssertTrue(app.staticTexts["3月31日（木）"].exists, app.debugDescription)
            XCTAssertEqual(app.staticTexts[notice].firstMatch.exists, hasNotice, app.debugDescription)
            XCTAssertEqual(app.staticTexts[noClasses].firstMatch.exists, saysNoClasses, app.debugDescription)
            let lesson = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空年度確認科目A")).firstMatch
            if hasLesson {
                XCTAssertTrue(lesson.waitForExistence(timeout: 10), app.debugDescription)
                XCTAssertTrue(lesson.isHittable, app.debugDescription)
            } else { XCTAssertFalse(lesson.exists, app.debugDescription) }
        }
        func boundaryWeek(hasNotice: Bool) {
            tab("時間割")
            XCTAssertTrue(app.buttons["3月28日から4月3日"].waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertEqual(app.staticTexts[notice].firstMatch.exists, hasNotice, app.debugDescription)
        }
        // The only saved year is 2031; current 2032 lessons stay usable.
        home(hasNotice: true, hasLesson: true, saysNoClasses: false)
        boundaryWeek(hasNotice: true)
        relaunch(["--events-year-no-lessons"])
        home(hasNotice: true, hasLesson: false, saysNoClasses: false)
        // A valid 2032 payload contains one other day, not March 31.
        relaunch(["--events-year-current", "--events-year-no-lessons"])
        home(hasNotice: false, hasLesson: false, saysNoClasses: true)
        relaunch(["--events-year-current"])
        home(hasNotice: false, hasLesson: true, saysNoClasses: false)
        boundaryWeek(hasNotice: true) // April 1–3 still need school year 2033.
        relaunch(["--events-year-both"])
        home(hasNotice: false, hasLesson: true, saysNoClasses: false)
        boundaryWeek(hasNotice: false)
        print("SYNTHETIC_EVENTS_YEAR_UI past-only cache kept missing notice and usable lessons; no false no-classes; other-day yearly coverage; March28-April3 week required both school years")
    }
    func testUsageHelpIsOrganizedByTask() {
        tab("設定")
        tap("使い方")
        screen("使い方")
        for (title, headings) in [("はじめに", ["1. OneDriveを準備する", "2. データを取得する", "3. 時間割ファイルを選ぶ", "4. 学校行事を取得する", "5. クラスを選ぶ"]),
                                 ("時間割を見る", ["今日の予定", "週の時間割", "時間割変更"]),
                                 ("リンクを使う", ["リンクを開く", "お気に入り・色・非表示"]),
                                 ("更新と通知", ["ファイルと学校行事", "リンク・名称・授業時刻", "通知", "バックグラウンドの確認", "4月・10月の切り替え"]),
                                 ("困ったとき", ["ファイルが更新されない", "解析に失敗する", "時間割変更の日付がおかしい", "ファイル選択が消えた"])] {
            tap(title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            for title in headings { _ = heading(title) }
            back(to: "使い方")
        }
    }
    func testSettingsGroupsAndCompactDataOverviews() {
        tab("設定")
        _ = heading("データ")
        _ = heading("アプリ設定")
        _ = heading("サポート")
        XCTAssertTrue(app.buttons["初期設定"].exists)
        app.swipeDown()
        tap("リンク・名称・授業時刻")
        screen("リンク・名称・授業時刻")
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.exists, app.debugDescription)
        }
        XCTAssertFalse(app.staticTexts["最終取得"].exists)
        XCTAssertFalse(app.staticTexts["件数"].exists)
        XCTAssertFalse(app.staticTexts["名称対応表"].exists)
        back(to: "設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        XCTAssertFalse(app.staticTexts["学校行事"].exists)
        XCTAssertFalse(app.staticTexts["最終取得"].exists)
        XCTAssertFalse(app.staticTexts["件数"].exists)
        XCTAssertTrue(app.buttons["自動確認を中止"].exists)
    }
    func testEmptyDataCanBeConfigured() {
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        tap("リンク・名称・授業時刻")
        screen("リンク・名称・授業時刻")
        XCTAssertTrue(app.buttons["学校アカウントで取得"].waitForExistence(timeout: 5), app.debugDescription)
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "未取得")).firstMatch
            XCTAssertTrue(row.exists, app.debugDescription)
        }
        back(to: "設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        for title in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            _ = heading(title)
            XCTAssertTrue(app.buttons["\(title)のファイルを選ぶ"].exists, app.debugDescription)
            XCTAssertFalse(app.buttons["\(title)の詳細を見る"].exists)
        }
    }
    func testChangedAccountDataNoticeOpensSharedAcquisition() {
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 30))
        let notice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "名称データ", "更新があります")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10), app.debugDescription)
        notice.tap()
        XCTAssertTrue(app.navigationBars["リンク・名称・授業時刻"].waitForExistence(timeout: 5))
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "更新あり")).firstMatch.exists, app.debugDescription)
        }
    }
    func testFileFailuresKeepResultsAndStayInTheirOwnDetails() {
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        tap("通常時間割の詳細を見る")
        screen("通常時間割")
        XCTAssertFalse(app.staticTexts["架空の変更ファイル取得エラー"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "解析済み")).firstMatch.exists, app.debugDescription)
        back(to: "時間割ファイル")
        tap("時間割変更の詳細を見る")
        screen("時間割変更")
        XCTAssertTrue(app.staticTexts["架空の変更ファイル取得エラー"].exists, app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "取得失敗（前回結果あり）")).firstMatch.exists, app.debugDescription)
        _ = heading("件数")
        back(to: "時間割ファイル")
        tap("試験時間割の詳細を見る")
        screen("試験時間割")
        XCTAssertFalse(app.staticTexts["架空の変更ファイル取得エラー"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "解析失敗（前回結果あり）")).firstMatch.exists, app.debugDescription)
        _ = heading("件数")
    }
    func testSettingsClassSelectionSharesTimetablePreference() {
        tab("設定")
        tap("クラス")
        tap("クラス")
        tap("4-IT")
        XCTAssertTrue(app.switches["留学生向けの授業も表示"].exists, app.debugDescription)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tab("時間割")
        let predicate = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "クラス", "4-IT")
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.exists, app.debugDescription)
    }
    func testLinkPreferencesSurviveRelaunch() {
        tab("一覧")
        let link = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 10), app.debugDescription)
        linkContextAction(link, title: "お気に入りを解除")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["一覧"].waitForExistence(timeout: 30))
        tab("一覧")
        let restored = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        linkContextAction(restored, title: "お気に入りに追加")
    }
    private func linkContextAction(_ link: XCUIElement, title: String) {
        let bar = app.navigationBars["一覧"]
        let tabs = app.tabBars.firstMatch
        recoveryScreenshot("link-context-before-" + title)
        // Bound existence separately. A predicate with seven AX queries can
        // expire while a query is still resolving, despite valid final frames.
        guard bar.waitForExistence(timeout:45),tabs.waitForExistence(timeout:45),link.waitForExistence(timeout:45) else {
            XCTFail("Link list controls are absent: " + app.debugDescription);return
        }
        let rowFrame=link.frame,barFrame=bar.frame,tabsFrame=tabs.frame
        let enabled=link.isEnabled
        guard enabled,[rowFrame,barFrame,tabsFrame].allSatisfy({
            !$0.isNull && !$0.isInfinite && $0.width>0 && $0.height>0
                && [$0.minX,$0.minY,$0.maxX,$0.maxY].allSatisfy(\.isFinite)
        }),rowFrame.minY>=barFrame.maxY,rowFrame.maxY<=tabsFrame.minY else {
            print("LINK_CONTEXT boundaries row=\(rowFrame);bar=\(barFrame);tabs=\(tabsFrame);enabled=\(enabled)")
            print("LINK_CONTEXT unresolved tree=\(app.debugDescription)")
            recoveryScreenshot("link-context-unresolved-" + title)
            XCTFail("Link row is not wholly visible on its actual list screen")
            return
        }
        // A visible native context-menu row may report isHittable=false after
        // relaunch on iOS27. Its actual coordinate gesture and menu/action
        // assertions verify interaction, rather than that AX prerequisite.
        print("LINK_CONTEXT physical row=\(link.frame);AX-hittable=\(link.isHittable);action=\(title)")
        if link.isHittable { link.press(forDuration: 2) }
        else if #available(iOS 27.0, *) {
            link.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).press(forDuration: 2)
        } else { XCTFail("The visible link is not hittable"); return }
        recoveryScreenshot("link-context-after-press-" + title)
        print("LINK_CONTEXT after-press tree=" + app.debugDescription)
        let action = app.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 45), app.debugDescription)
        XCTAssertTrue(action.isHittable, app.debugDescription)
        action.tap()
    }
    func testLegalDocumentsAndIndividualLicenses() {
        tab("設定")
        tap("このアプリについて")
        screen("このアプリについて")
        _ = heading("アプリ情報")
        _ = heading("規約・プライバシー")
        XCTAssertTrue(app.buttons["たくにんの利用規約"].exists)
        XCTAssertTrue(app.buttons["たくにんのプライバシーポリシー"].exists)
        tap("利用規約")
        XCTAssertFalse(app.staticTexts["文書を読み込めませんでした。"].exists)
        XCTAssertTrue(app.navigationBars["利用規約"].exists)
        back(to: "このアプリについて")
        tap("プライバシーポリシー")
        XCTAssertTrue(app.navigationBars["プライバシーポリシー"].exists)
        back(to: "このアプリについて")
        tap("オープンソースライセンス")
        screen("オープンソースライセンス")
        for (index, name) in ["ZIPFoundation", "denpa-schedule-csv", "GRDB.swift"].enumerated() {
            tap(name, searchEarlierRows: index > 0)
            XCTAssertFalse(app.staticTexts["ライセンス情報を読み取れません。"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Copyright")).firstMatch.exists, app.debugDescription)
            back(to: "オープンソースライセンス")
        }
        back(to: "このアプリについて")
        _ = heading("問い合わせ・配布")
        for title in ["ソースコード", "問い合わせ", "AltStore SourceのURLを共有"] {
            // SwiftUI Link has its own accessibility role; it need not have a
            // static-text child. ShareLink is exposed as a button.
            _ = visible(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch)
        }
    }
    func testSetupCanBeSkippedAndOffersAllFiles() {
        tab("設定")
        tap("初期設定")
        screen("データを取得")
        XCTAssertTrue(app.buttons["あとで設定"].waitForExistence(timeout: 5))
        tapSetupNext(from: "データを取得")
        screen("時間割ファイル")
        for name in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            _ = heading(name)
        }
        tap("学校行事を取得")
        screen("学校行事")
        back(to: "時間割ファイル")
        tapSetupNext(from: "時間割ファイル")
        screen("クラス")
        XCTAssertTrue(app.staticTexts["3 / 3"].exists, app.debugDescription)
        tapToolbar("あとで設定", bar: "クラス")
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 5))
    }
    func testNotificationControlsAndAppearance() {
        tab("設定")
        openNotificationSettings()
        XCTAssertTrue(app.switches["時間割変更"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["試験・返却"].exists)
        enableChangeNotifications()
        let specialToggle = app.switches["試験・返却"]
        tapNativeSwitch(specialToggle)
        let enabled = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: specialToggle)
        wait(for: [enabled], timeout: 10)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let color = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "メインカラー")).firstMatch
        XCTAssertTrue(color.exists, app.debugDescription)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "デフォルト")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "未設定")
        color.tap()
        for name in ["デフォルト", "青", "緑", "黄色", "オレンジ", "赤", "ピンク", "紫"] {
            XCTAssertTrue(app.buttons[name].exists, app.debugDescription)
        }
        tap("緑")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "緑")).firstMatch.exists)
        tap("リンクの開き方")
        tap("デフォルトのブラウザ")
        app.terminate()
        app.launchArguments = ["--theme-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "緑")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "リンクの開き方", "デフォルトのブラウザ")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "green")
        tap("メインカラー")
        app.buttons["デフォルト"].tap()
        let cleared = expectation(for: NSPredicate(format: "label == %@", "未設定"),
                                  evaluatedWith: app.staticTexts["fixture-stored-color"])
        wait(for: [cleared], timeout: 10)
        app.terminate()
        launchReady()
        tab("設定")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "デフォルト")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "未設定")
        tap("メインカラー")
        tap("青")
        app.terminate()
        launchReady()
        tab("設定")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "青")).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "blue")
    }
    func testChangedDataProducesOneLocalNotification() {
        tab("設定")
        openNotificationSettings()
        enableChangeNotifications()
        app.terminate()
        app.launchArguments = ["--updated-changes", "--notification-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        let result = app.staticTexts["fixture-notification-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        let received = expectation(for: NSPredicate(format: "label == %@", "1件の時間割変更を確認してください。"), evaluatedWith: result)
        wait(for: [received], timeout: 30)
        XCTAssertEqual(app.staticTexts["fixture-notification-delivery-proof"].label,
                       "delivered=1;fresh=1;revision=true", "Require one actual new delivery carrying its source revision")
    }
    #if TAKUPOKE_VOICEOVER_AUTOMATION
    @MainActor func testVoiceOverReadsTimetableCard() throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("VoiceOver automation requires iOS 27") }
        tab("時間割")
        let service = XCUIDevice.shared.voiceOverService
        try service.enable()
        defer { try? service.disable() }
        var utterances: [String] = []
        for _ in 0..<60 {
            let output = try service.moveForward()
            utterances.append(output.utterance)
            if output.utterance.contains("架空科目甲") { break }
        }
        for name in ["架空科目甲", "架空教員甲", "架空教室甲"] {
            XCTAssertTrue(utterances.contains { $0.contains(name) }, utterances.joined(separator: " | "))
        }
    }

    #else
    func testVoiceOverReadsTimetableCard() throws {
        throw XCTSkip("VoiceOver automation requires Xcode 27 and iOS 27")
    }
    #endif

}
