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
        let apply = app.buttons["change-apply-skips"]
        XCTAssertTrue(apply.waitForExistence(timeout: 15), app.debugDescription)
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
        visible(apply, navigation: "内容の確認", searchEarlierRows: true).tap()
        let alert = app.alerts["選んだ行を除外して読み込む"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","200〜300行目")).firstMatch.exists)
        alert.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars["内容の確認"].exists)
        visible(apply, navigation: "内容の確認", searchEarlierRows: true).tap()
        alert.buttons["除外して読み込む"].tap()
        let count = app.staticTexts["change-skipped-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(count.label.contains("103行"), count.label)
        XCTAssertTrue(visible(app.staticTexts["変更後、架空科目C"]).exists)
        XCTAssertFalse(app.staticTexts["変更後、架空除外科目B"].exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        launchReady()
        openChanges()
        XCTAssertTrue(count.waitForExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(count.label.contains("103行"), count.label)
        XCTAssertTrue(visible(app.staticTexts["変更後、架空科目C"]).exists)
        XCTAssertFalse(app.staticTexts["変更後、架空除外科目B"].exists)
    }
}
