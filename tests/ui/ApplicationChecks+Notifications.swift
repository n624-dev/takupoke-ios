import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func testCountdownNotificationRouteOpensCurrentDetailAndMissingTargetList() {
        tab("設定")
        tap("カウントダウン")
        screen("カウントダウン")
        XCTAssertTrue(app.staticTexts["架空の通知予定"].waitForExistence(timeout:10),app.debugDescription)
        tab("ホーム")
        let existing = app.buttons["fixture-countdown-route-existing"], missing = app.buttons["fixture-countdown-route-missing"]
        XCTAssertTrue(existing.waitForExistence(timeout:10))
        XCTAssertTrue(existing.isHittable)
        existing.tap()
        let detail = app.navigationBars["予定の詳細"]
        XCTAssertTrue(detail.waitForExistence(timeout:10),app.debugDescription)
        let close = detail.buttons["閉じる"]
        XCTAssertTrue(app.staticTexts["開始日"].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertTrue(app.staticTexts["架空の通知予定"].exists)
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout:10))
        screen("たくポケ")

        XCTAssertTrue(missing.waitForExistence(timeout:10))
        XCTAssertTrue(missing.isHittable)
        missing.tap()
        XCTAssertTrue(app.staticTexts["通知の対象は変更または削除されています。現在の予定を表示しています。"]
            .waitForExistence(timeout:10),app.debugDescription)
        let management = app.navigationBars["カウントダウン"]
        XCTAssertTrue(management.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"identifier == %@ AND label CONTAINS %@",
            "countdown-list-card","架空の通知予定")).firstMatch.exists)
        let closeManagement = management.buttons["閉じる"]
        XCTAssertTrue(closeManagement.isHittable)
        closeManagement.tap()
        XCTAssertTrue(closeManagement.waitForNonExistence(timeout:10))
        screen("たくポケ")
        XCTAssertEqual(app.state,.runningForeground)
    }

    func testCountdownCorruptStorageAllowsConfirmedRecoveryAndNewRegistration() {
        let management = "カウントダウン"
        let warning = "保存したカウントダウンを読み込めません。端末内の登録は保持しています。"
        let added = app.buttons["countdown-add"]
        func tapDialog(_ button: XCUIElement) {
            let ready = XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                button.exists && button.isEnabled && button.isHittable
            },object:nil)
            guard XCTWaiter.wait(for:[ready],timeout:10) == .completed else {
                XCTFail("Dialog button never became tappable: \(button)\n\(app.debugDescription)")
                return
            }
            button.tap()
        }
        func openCountdown() {
            tab("設定")
            tap(management)
            screen(management)
        }

        openCountdown()
        XCTAssertTrue(app.staticTexts[warning].waitForExistence(timeout:10), app.debugDescription)
        XCTAssertTrue(added.exists)
        XCTAssertFalse(added.isEnabled)
        XCTAssertFalse(app.buttons["countdown-automatic"].exists)
        tap("読み込みを再試行")
        XCTAssertTrue(app.staticTexts[warning].exists)
        XCTAssertFalse(added.isEnabled)

        tap("予約済み通知を取り消す")
        tapDialog(app.buttons["通知を取り消す"])
        XCTAssertTrue(app.staticTexts["予約済みのカウントダウン通知を取り消しました。元のファイルは保持しています。"]
            .waitForExistence(timeout:10), app.debugDescription)
        XCTAssertFalse(added.isEnabled)
        tap("読み込みを再試行")
        XCTAssertTrue(app.staticTexts[warning].waitForExistence(timeout:10), app.debugDescription)
        tap("元のファイルを保全して初期化")
        let confirmation = app.alerts["カウントダウンを初期化しますか？"]
        XCTAssertTrue(confirmation.waitForExistence(timeout:10),app.debugDescription)
        tapDialog(confirmation.buttons["キャンセル"])
        XCTAssertTrue(app.staticTexts[warning].exists)
        XCTAssertFalse(added.isEnabled)
        tap("元のファイルを保全して初期化")
        XCTAssertTrue(confirmation.waitForExistence(timeout:10),app.debugDescription)
        tapDialog(confirmation.buttons["初期化"])
        XCTAssertTrue(app.staticTexts["元のファイルを保全して、カウントダウンを初期化しました。"]
            .waitForExistence(timeout:10), app.debugDescription)
        XCTAssertTrue(added.isEnabled)

        tapToolbar("countdown-add",bar:management)
        tapDialog(app.buttons["自分で入力"])
        let name = app.textFields["countdown-name"]
        XCTAssertTrue(name.waitForExistence(timeout:10), app.debugDescription)
        name.tap()
        name.typeText("Fictional Recovery")
        XCTAssertEqual(name.value as? String,"Fictional Recovery")
        tapToolbar("countdown-save",bar:"カウントダウンを設定")
        XCTAssertTrue(app.staticTexts["Fictional Recovery"].waitForExistence(timeout:10), app.debugDescription)

        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" || $0 == "--countdown-storage-corrupt" }
        launchReady()
        openCountdown()
        XCTAssertTrue(app.staticTexts["Fictional Recovery"].waitForExistence(timeout:10), app.debugDescription)
        XCTAssertFalse(app.staticTexts[warning].exists)
    }

    private func permissionAllowButton(_ allowPredicate: NSPredicate) -> XCUIElement? {
        // Resolve the actual system surface afresh; never retain an element
        // belonging to a previous permission alert or accessibility server.
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alerts = system.alerts.matching(NSPredicate(
            format: "label CONTAINS %@ AND (label CONTAINS[c] %@ OR label CONTAINS %@)",
            app.label, "notification", "通知"))
        let current = alerts.allElementsBoundByIndex
        guard current.count == 1 else { return nil }
        let allow = current[0].buttons.matching(allowPredicate).allElementsBoundByIndex
        guard allow.count == 1 else { return nil }
        let button = allow[0]
        guard usable(button.frame), current[0].frame.contains(button.frame),
            button.isEnabled, button.isHittable else { return nil }
        return button
    }
    private func openNotificationSettings() {
        let row = app.buttons["通知"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
        _ = visible(row)
        XCTAssertTrue(row.isEnabled, app.debugDescription)
        let bounds = row.frame
        XCTAssertTrue(
            bounds.width > 0 && bounds.height > 0 && bounds.minY >= app.navigationBars.firstMatch.frame.maxY
                && bounds.maxY <= app.tabBars.firstMatch.frame.minY, app.debugDescription)
        // iOS 27 can report a fully visible SwiftUI navigation row as
        // non-hittable. Exercise its actual visible label, then require navigation.
        let label = row.staticTexts["通知"]
        guard label.exists, usable(label.frame), bounds.contains(label.frame) else {
            XCTFail("Notification navigation row has no visible label")
            return
        }
        print("NOTIFICATION_ROW row=\(bounds);label=\(label.frame);method=native-label-brief-contact;duration=0.1")
        // N48/U75: keep one contact at the observed label center, bound to
        // its native element, as with the existing tab and switch controls.
        label.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
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
            ["時間割変更", "試験・返却"].allSatisfy({ !touchFrame.intersects(app.switches[$0].frame) })
        else {
            XCTFail("Permission monitor trigger overlaps a real notification control")
            return
        }
        let probe = app.staticTexts["fixture-notification-permission-state"]
        let ready = expectation(for: NSPredicate(
            format: "label CONTAINS %@ AND NOT (label CONTAINS %@) AND label ENDSWITH %@",
            ";authorization=", ";authorization=pending", ";application=0"), evaluatedWith: probe)
        guard XCTWaiter.wait(for: [ready], timeout: 45) == .completed else {
            print("NOTIFICATION_READINESS unresolved=\(probe.label)")
            recoveryScreenshot("notification-readiness-unresolved", systemScreen: true)
            XCTFail("Notification check did not complete or explicitly skip its unnecessary OS read")
            return
        }
        let predicate = NSPredicate(
            format: "label BEGINSWITH[c] %@ OR label == %@ OR label == %@ OR label == %@", "Allow", "許可",
            "許可する", "通知を許可")
        print(
            "NOTIFICATION_SWITCH before row=\(toggle.frame) value=\(String(describing: toggle.value)) state=\(probe.label)"
        )
        // Native geometry and the observed 0/1 state determine the single tap.
        // Keep diagnostic image requests on failure paths, away from activation.
        let authorization = probe.label.components(separatedBy: ";authorization=").last?
            .components(separatedBy: ";").first
        guard let authorization,
            ["0", "1", "2", "3", "4", "notRequested"].contains(authorization),
            authorization != "notRequested" || probe.label.contains(
                "changes=false;saved=false;specials=false;savedSpecials=false;")
        else {
            XCTFail("Require an actual OS status or the observed disabled branch without an OS read")
            return
        }
        tapNativeSwitch(toggle)
        print("NOTIFICATION_SWITCH activated state=\(probe.label)")
        let deadline = Date().addingTimeInterval(45)
        var permissionHandled = false
        // Observe the current system surface and tap its actual Allow once.
        // Routing through another app button consumed the common deadline.
        let enabled = expectation(for: NSPredicate { _, _ in
            guard Date() <= deadline else { return false }
            let state = probe.label
            if state.hasPrefix("requesting=false;changes=true;saved=true;") {
                return (toggle.value as? String) == "1" && Date() <= deadline
            }
            if !permissionHandled, state.hasPrefix("requesting=true;"),
                let allow = self.permissionAllowButton(predicate), Date() <= deadline {
                permissionHandled = true
                print("NOTIFICATION_ALLOW frame=\(allow.frame)")
                allow.tap()
            }
            return false
        }, evaluatedWith: app)
        let didEnable = XCTWaiter.wait(for: [enabled], timeout: max(0, deadline.timeIntervalSinceNow)) == .completed
        guard didEnable else {
            print(
                "NOTIFICATION_SWITCH unresolved value=\(String(describing: toggle.value)) enabled=\(toggle.isEnabled) tree=\(app.debugDescription)"
            )
            recoveryScreenshot("notification-switch-unresolved")
            recoveryScreenshot("notification-system-unresolved", systemScreen: true)
            XCTFail("Native notification switch activation did not complete permission and enablement")
            return
        }
        print("NOTIFICATION_SWITCH after value=\(String(describing: toggle.value)) state=\(probe.label)")
        XCTAssertTrue(probe.label.contains("changes=true;saved=true"), probe.label)
        if touch.exists { touch.tap() }  // Close only the QA overlay after real enablement.
        XCTAssertTrue(touch.waitForNonExistence(timeout: 10), app.debugDescription)
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
        guard XCTWaiter.wait(for: [enabled], timeout: 10) == .completed else {
            let probe = app.staticTexts["fixture-notification-permission-state"]
            print("NOTIFICATION_SPECIAL unresolved value=\(String(describing: specialToggle.value)) state=\(probe.label)")
            recoveryScreenshot("notification-special-unresolved")
            recoveryScreenshot("notification-special-system-unresolved", systemScreen: true)
            XCTFail("Special notification switch did not become enabled within 10 seconds: " + app.debugDescription)
            return
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let color = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "メインカラー")).firstMatch
        XCTAssertTrue(color.exists, app.debugDescription)
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "デフォルト")
            ).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "未設定")
        color.tap()
        for name in ["デフォルト", "青", "緑", "黄色", "オレンジ", "赤", "ピンク", "紫"] {
            XCTAssertTrue(app.buttons[name].exists, app.debugDescription)
        }
        tap("緑")
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "緑")
            ).firstMatch.exists)
        tap("リンクの開き方")
        tap("デフォルトのブラウザ")
        app.terminate()
        app.launchArguments = ["--theme-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "緑")
            ).firstMatch.exists)
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "リンクの開き方", "デフォルトのブラウザ")
            ).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "green")
        tap("メインカラー")
        app.buttons["デフォルト"].tap()
        let cleared = expectation(
            for: NSPredicate(format: "label == %@", "未設定"),
            evaluatedWith: app.staticTexts["fixture-stored-color"])
        wait(for: [cleared], timeout: 10)
        app.terminate()
        launchReady()
        tab("設定")
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "デフォルト")
            ).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "未設定")
        tap("メインカラー")
        tap("青")
        let blueSaved = expectation(
            for: NSPredicate(format: "label == %@", "blue"),
            evaluatedWith: app.staticTexts["fixture-stored-color"])
        guard XCTWaiter.wait(for: [blueSaved], timeout: 10) == .completed else {
            recoveryScreenshot("blue-before-relaunch-unresolved")
            XCTFail("Blue selection did not reach the actual saved preference before relaunch: " + app.debugDescription)
            return
        }
        print("APPEARANCE_BLUE saved-before-relaunch=blue")
        app.terminate()
        launchReady()
        tab("設定")
        XCTAssertTrue(
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "青")
            ).firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture-stored-color"].label, "blue")
    }
    func testChangedDataProducesOneLocalNotification() {
        tab("設定")
        openNotificationSettings()
        enableChangeNotifications()
        app.terminate()
        app.launchArguments = [
            "--updated-changes", "--notification-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
        ]
        launchReady()
        let result = app.staticTexts["fixture-notification-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        let received = expectation(
            for: NSPredicate(format: "label == %@", "1件の時間割変更を確認してください。"), evaluatedWith: result)
        wait(for: [received], timeout: 30)
        XCTAssertEqual(
            app.staticTexts["fixture-notification-delivery-proof"].label,
            "delivered=1;fresh=1;revision=true",
            "Require one actual new delivery carrying its source revision")
    }
}

extension ApplicationChecks {
    func testCountdownReminderDayUsesSingleLineAndPersistsInBothEditors() {
        let management = "カウントダウン", automatic = "試験の自動表示", personal = "カウントダウンを設定"
        let digits = app.textFields["countdown-reminder-days-0"]
        let label = app.staticTexts["countdown-reminder-label-0"]

        func showField(in editor: String, expected: String, enlarged: Bool = false) {
            let field = visible(digits, navigation: editor)
            XCTAssertEqual(field.label, "予定の何日前")
            XCTAssertEqual(field.value as? String, expected)
            XCTAssertTrue(field.isHittable)
            let labelFrame = label.frame, fieldFrame = field.frame
            XCTAssertTrue(label.exists && usable(labelFrame) && usable(fieldFrame))
            if enlarged {
                XCTAssertGreaterThan(fieldFrame.midY, labelFrame.maxY)
            } else {
                XCTAssertEqual(fieldFrame.midY, labelFrame.midY, accuracy: 5)
                XCTAssertGreaterThan(fieldFrame.minX, labelFrame.maxX)
            }
            print("UI_COUNTDOWN_DAY enlarged=\(enlarged);labelFrame=\(labelFrame);fieldFrame=\(fieldFrame)")
        }

        func enterDay(_ value: String, replacingDigitCount count: Int) {
            digits.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            digits.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: count) + value)
            XCTAssertEqual(digits.value as? String ?? "", value, "Native editor must contain the complete input before saving")
        }

        func expectInvalidReminder() {
            let save = app.navigationBars.buttons["countdown-save"]
            XCTAssertTrue(save.exists)
            XCTAssertFalse(save.isEnabled, "An unfinished native input must prevent saving a previous numeric value")
        }

        func saveReminderEditor() {
            let save = app.navigationBars.buttons["countdown-save"]
            XCTAssertTrue(save.exists && save.isEnabled && save.isHittable)
            save.tap()
        }

        func changeDay(to value: String, replacingDigitCount count: Int) {
            enterDay(value, replacingDigitCount: count)
            saveReminderEditor()
        }

        func setTextSize(_ size: String) {
            app.buttons["fixture-type-size"].tap()
            app.buttons[size].tap()
        }

        tab("設定")
        tap(management)
        screen(management)
        app.buttons["countdown-automatic"].tap()
        screen(automatic)
        showField(in: automatic, expected: "7")
        recoveryScreenshot("countdown-notification-days-standard")
        enterDay("", replacingDigitCount: 1)
        expectInvalidReminder()
        enterDay("365001", replacingDigitCount: 0)
        expectInvalidReminder()
        changeDay(to: "365000", replacingDigitCount: 6)
        screen(management)
        app.buttons["countdown-automatic"].tap()
        screen(automatic)
        showField(in: automatic, expected: "365,000")
        setTextSize("最大")
        showField(in: automatic, expected: "365,000", enlarged: true)
        recoveryScreenshot("countdown-notification-days-maximum-size")
        setTextSize("標準")
        back(to: management)

        let plan = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@",
                                                     "countdown-list-card", "架空の通知日設定")).firstMatch
        visible(plan, navigation: management).tap()
        screen("予定の詳細")
        tap("編集")
        screen(personal)
        setTextSize("アクセシビリティ・大")
        showField(in: personal, expected: "7", enlarged: true)
        recoveryScreenshot("countdown-notification-days-accessibility")
        enterDay("", replacingDigitCount: 1)
        expectInvalidReminder()
        changeDay(to: "0", replacingDigitCount: 0)
        screen("予定の詳細")
        tap("編集")
        screen(personal)
        showField(in: personal, expected: "0", enlarged: true)

        setTextSize("標準")
        showField(in: personal, expected: "0")
        enterDay("2", replacingDigitCount: 1)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        let remove = visible(app.buttons["countdown-delete-reminder-0"], navigation: personal)
        XCTAssertTrue(remove.isHittable)
        remove.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10))
        showField(in: personal, expected: "1")
        saveReminderEditor()
        screen("予定の詳細")
        tap("編集")
        screen(personal)
        showField(in: personal, expected: "1")
    }

    func testScheduledCountdownReservationsUseNativeCenterAndCancelOnlyTheirOwnAfterRelaunch() {
        func openPlan() {
            tab("設定")
            tap("カウントダウン")
            let row = visible(app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@",
                "countdown-list-card", "架空の通知予定")).firstMatch)
            XCTAssertTrue(row.exists && row.isHittable, app.debugDescription)
            row.tap()
            screen("予定の詳細")
        }
        func editNotification(_ enabled: Bool) {
            let edit = visible(app.buttons["編集"], navigation: "予定の詳細")
            XCTAssertTrue(edit.exists && edit.isEnabled && edit.isHittable, app.debugDescription)
            edit.tap()
            screen("カウントダウンを設定")
            let control = visible(app.switches["通知を予約"], navigation: "カウントダウンを設定")
            XCTAssertEqual(control.value as? String, enabled ? "0" : "1", app.debugDescription)
            tapNativeSwitch(control, navigation: "カウントダウンを設定", dragThumb: true)
            let changed = expectation(for: NSPredicate { _, _ in control.value as? String == (enabled ? "1" : "0") },
                                      evaluatedWith: control)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed)
            let save = app.buttons["countdown-save"]
            XCTAssertTrue(save.exists && save.isHittable, app.debugDescription)
            save.tap()
        }
        func countReservations(_ count: Int, other: Int = 1, second: Int = 2, requiresPermission: Bool = true) {
            tap("予約を照合")
            let probe = app.staticTexts["fixture-countdown-pending"]
            let prefix = "実予約\(count)件／別登録\(second)件／対照\(other)件"
            let condition = requiresPermission ? NSPredicate(format: "label == %@", prefix + "／許可true")
                : NSPredicate(format: "label BEGINSWITH %@", prefix)
            let matched = expectation(for: condition, evaluatedWith: probe)
            XCTAssertEqual(XCTWaiter.wait(for: [matched], timeout: 15), .completed, app.debugDescription)
        }
        openPlan()
        countReservations(0, other: 0, second: 0, requiresPermission: false)
        editNotification(true)
        let allowPredicate = NSPredicate(format: "label BEGINSWITH[c] %@ OR label == %@ OR label == %@ OR label == %@",
                                         "Allow", "許可", "許可する", "通知を許可")
        var handled = false
        let reserved = app.staticTexts["fixture-countdown-reservation-status"]
        let granted = expectation(for: NSPredicate { _, _ in
            if !handled, let allow = self.permissionAllowButton(allowPredicate) {
                handled = true
                allow.tap()
                return false
            }
            return reserved.exists && reserved.label == "2件予約済み"
        }, evaluatedWith: app)
        XCTAssertEqual(XCTWaiter.wait(for: [granted], timeout: 45), .completed, app.debugDescription)
        let detail = app.staticTexts.matching(NSPredicate(format: "label == %@ AND identifier != %@",
            "2件予約済み", "fixture-countdown-reservation-status")).firstMatch
        XCTAssertTrue(visible(detail).exists, app.debugDescription)
        tap("対照通知を予約")
        XCTAssertTrue(app.staticTexts["対照予約を確認できます"].waitForExistence(timeout: 15))
        let control = app.staticTexts["fixture-countdown-control-status"]
        let controlReserved = expectation(for: NSPredicate(format: "label == %@", "2件予約済み"), evaluatedWith: control)
        XCTAssertEqual(XCTWaiter.wait(for: [controlReserved], timeout: 20), .completed, app.debugDescription)
        countReservations(2)

        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        launchReady()
        openPlan()
        let restored = expectation(for: NSPredicate(format: "label == %@", "2件予約済み"), evaluatedWith: reserved)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 20), .completed, app.debugDescription)
        countReservations(2)
        editNotification(false)
        screen("予定の詳細")
        // Wait for the production reconciliation to drain before observing the
        // OS a second time. The probe performs a fresh real pending-requests read.
        let cleared = expectation(for: NSPredicate(format: "label == %@", "予約報告なし"), evaluatedWith: reserved)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 15), .completed, app.debugDescription)
        countReservations(0)
    }
}
