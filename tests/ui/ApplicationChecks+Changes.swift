import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func testChangeRowsRequireSelectionAndConfirmationAndPersistAfterRelaunch() {
        func openChanges() {
            tab("設定")
            visible(app.buttons["時間割ファイル"]).tap()
            screen("時間割ファイル")
            let detail = app.buttons["時間割変更の詳細を見る"]
            XCTAssertTrue(detail.waitForExistence(timeout: 15), app.debugDescription)
            visible(detail).tap()
            screen("時間割変更")
        }
        openChanges()
        visible(app.buttons["警告を確認して内容を見る"]).tap()
        app.alerts.buttons["確認して表示"].tap()
        screen("内容の確認")
        let navigation = app.navigationBars["内容の確認"]
        let apply = navigation.buttons["change-apply-skips"]
        XCTAssertTrue(apply.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(navigation.buttons["キャンセル"].exists)
        XCTAssertFalse(apply.isEnabled)
        for number in [3, 4] {
            let toggle = app.switches["change-skip-row-\(number)"]
            _ = visible(toggle, navigation: "内容の確認")
            XCTAssertTrue(toggle.waitForExistence(timeout: 15), app.debugDescription)
            tapNativeSwitch(toggle, navigation: "内容の確認")
            let changed = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed)
        }
        let group = app.switches["change-skip-group-200-300"]
        _ = visible(group,navigation:"内容の確認")
        XCTAssertTrue(app.staticTexts["200〜300行目の元の記載"].exists)
        tapNativeSwitch(group,navigation:"内容の確認")
        let groupSelected = expectation(for:NSPredicate(format:"value == %@","1"),evaluatedWith:group)
        XCTAssertEqual(XCTWaiter.wait(for:[groupSelected],timeout:15),.completed)
        XCTAssertTrue(apply.isEnabled)
        tapToolbar("除外して読み込む", bar: "内容の確認")
        let alert = app.alerts["選んだ行を除外して読み込む"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","200〜300行目")).firstMatch.exists)
        alert.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["内容の確認"].exists)
        tapToolbar("除外して読み込む", bar: "内容の確認")
        alert.buttons["除外して読み込む"].tap()
        let count = app.staticTexts["change-skipped-count"]
        let status = app.descendants(matching: .any)["change-analysis-status"]
        XCTAssertTrue(count.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(count.label.contains("103行"), count.label)
        let initiallyParsed = expectation(for: NSPredicate(
            format: "label ENDSWITH %@ OR value == %@", "解析済み", "解析済み"), evaluatedWith: status)
        XCTAssertEqual(XCTWaiter.wait(for: [initiallyParsed], timeout: 15), .completed)
        let ranges = app.staticTexts["change-skipped-rows"]
        XCTAssertTrue(ranges.waitForExistence(timeout:15))
        XCTAssertEqual(ranges.label,"除外した行：3〜4行目、200〜300行目")
        XCTAssertTrue(visible(app.staticTexts["変更後、架空科目C"]).exists)
        XCTAssertFalse(app.staticTexts["変更後、架空除外科目B"].exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        launchReady()
        openChanges()
        XCTAssertTrue(count.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(count.label.contains("103行"), count.label)
        let parsedAfterRelaunch = expectation(for: NSPredicate(
            format: "label ENDSWITH %@ OR value == %@", "解析済み", "解析済み"), evaluatedWith: status)
        XCTAssertEqual(XCTWaiter.wait(for: [parsedAfterRelaunch], timeout: 15), .completed)
        XCTAssertTrue(ranges.waitForExistence(timeout:15))
        XCTAssertEqual(ranges.label,"除外した行：3〜4行目、200〜300行目")
        XCTAssertTrue(visible(app.staticTexts["変更後、架空科目C"]).exists)
        XCTAssertFalse(app.staticTexts["変更後、架空除外科目B"].exists)

        visible(app.buttons["個人修正を編集"]).tap()
        screen("個人修正を編集")
        visible(app.buttons["change-editor-row-3"]).tap()
        screen("3行目")
        XCTAssertEqual(app.textFields["change-editor-field-0"].value as? String, "1")
        func assertSwitch(_ control: XCUIElement, now value: String) {
            let updated = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: control)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 15), .completed, app.debugDescription)
        }
        let excluded = app.switches["この行を除外"]
        XCTAssertEqual(visible(excluded, navigation: "3行目").value as? String, "1")
        tapNativeSwitch(excluded, navigation: "3行目")
        assertSwitch(excluded, now: "0")
        let derive = app.switches["曜日を日付から補完"]
        XCTAssertEqual(visible(derive, navigation: "3行目").value as? String, "0")
        tapNativeSwitch(derive, navigation: "3行目")
        assertSwitch(derive, now: "1")
        back(to: "個人修正を編集")
        tapToolbar("反映する", bar: "個人修正を編集")
        XCTAssertTrue(app.navigationBars["個人修正を編集"].waitForNonExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(visible(app.staticTexts["変更後、架空除外科目B"]).exists)

        app.terminate()
        launchReady()
        openChanges()
        visible(app.buttons["個人修正を編集"]).tap()
        screen("個人修正を編集")
        visible(app.buttons["change-editor-row-3"]).tap()
        screen("3行目")
        XCTAssertEqual(visible(derive, navigation: "3行目").value as? String, "1")
        XCTAssertEqual(visible(excluded, navigation: "3行目").value as? String, "0")
    }
}
