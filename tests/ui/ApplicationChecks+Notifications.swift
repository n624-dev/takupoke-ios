import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
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
        let point = label.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.midX, dy: point.midY)).tap()
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
            XCTFail("OS notification settings did not respond while the app was active")
            return
        }
        let predicate = NSPredicate(
            format: "label BEGINSWITH[c] %@ OR label == %@ OR label == %@ OR label == %@", "Allow", "許可",
            "許可する", "通知を許可")
        // Permission UI can move between system processes on iOS 27. Let
        // XCTest resolve the interrupting alert rather than retaining a
        // SpringBoard element whose accessibility server has gone away.
        let monitor = addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            print("NOTIFICATION_ALERT title=\(alert.label);buttons=\(alert.buttons.allElementsBoundByIndex.map(\.label))")
            let allow = alert.buttons.matching(predicate).firstMatch
            guard allow.exists else { return false }
            allow.tap()
            return true
        }
        defer { removeUIInterruptionMonitor(monitor) }
        print(
            "NOTIFICATION_SWITCH before row=\(toggle.frame) value=\(String(describing: toggle.value)) state=\(probe.label)"
        )
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
        wait(for: [enabled], timeout: 10)
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
