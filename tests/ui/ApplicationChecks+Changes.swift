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
        let review = "内容を確認・修正"
        func openReview() {
            visible(app.buttons[review], navigation: "時間割変更", searchEarlierRows: true).tap()
            screen(review)
            XCTAssertFalse(app.alerts["曜日を確認できないファイルです"].exists)
        }
        func selectSwitch(_ identifier: String, on page: String) {
            let control = visible(app.switches[identifier], navigation: page)
            XCTAssertEqual(control.value as? String, "0")
            tapNativeSwitch(control, navigation: page, dragThumb: true)
            let changed = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: control)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed)
        }
        openChanges()
        openReview()
        let apply = app.navigationBars[review].buttons["反映する"]
        XCTAssertTrue(apply.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.navigationBars[review].buttons["閉じる"].exists)
        XCTAssertFalse(apply.isEnabled)
        func exclude(_ id: String, page: String, selection: String) {
            visible(app.buttons[id], navigation: review).tap()
            screen(page)
            selectSwitch(selection, on: page)
            visible(app.buttons["選んだ行を除外"], navigation: page).tap()
            screen(review)
        }
        exclude("change-group-weekdayMismatch-3-3", page: "曜日を日付から補完", selection: "change-select-row-3")
        exclude("change-group-weekdayOnly-3-4", page: "「火」だけの行", selection: "change-select-row-4")
        let group = app.buttons["change-group-weekdayOnly-3-200"]
        XCTAssertTrue(visible(group, navigation: review).label.contains("200〜300行目"))
        exclude("change-group-weekdayOnly-3-200", page: "「土」だけの行", selection: "change-select-all")
        XCTAssertFalse(apply.isEnabled)
        // The first correction must leave the other grade unresolved.
        for (row, value) in [(6, "1"), (7, "2")] {
            let gradeGroup = app.buttons["change-group-year-0-\(row)"]
            XCTAssertTrue(visible(gradeGroup, navigation: review).label.contains(row == 6 ? "2行" : "1行"))
            gradeGroup.tap()
            screen("学年を確認")
            selectSwitch("change-select-row-\(row)", on: "学年を確認")
            let input = visible(app.textFields["change-group-value"], navigation: "学年を確認")
            input.tap()
            input.typeText(value + "\n")
            visible(app.buttons["選んだ行に入力"], navigation: "学年を確認", searchEarlierRows: true).tap()
            screen(review)
        }
        XCTAssertTrue(apply.isEnabled)
        tapToolbar("反映する", bar: review)
        let alert = app.alerts["個人修正を反映しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","200〜300行目")).firstMatch.exists)
        alert.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars[review].exists)
        tapToolbar("反映する", bar: review)
        alert.buttons["反映する"].tap()
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

        func openEditedRows() {
            openReview()
            visible(app.buttons["change-edited-rows"], navigation: review).tap()
            screen("修正済み")
        }
        openEditedRows()
        visible(app.buttons["change-saved-excluded"], navigation: "修正済み").tap()
        screen("除外した行")
        visible(app.buttons["change-editor-row-3"], navigation: "除外した行").tap()
        screen("3行目")
        XCTAssertEqual(app.textFields["change-editor-field-0"].value as? String, "1")
        func assertSwitch(_ control: XCUIElement, now value: String) {
            let updated = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: control)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 15), .completed, app.debugDescription)
        }
        let excluded = app.switches["この行を除外"]
        XCTAssertEqual(visible(excluded, navigation: "3行目").value as? String, "1")
        tapNativeSwitch(excluded, navigation: "3行目", dragThumb: true)
        assertSwitch(excluded, now: "0")
        let derive = app.switches["曜日を日付から補完"]
        XCTAssertEqual(visible(derive, navigation: "3行目").value as? String, "0")
        tapNativeSwitch(derive, navigation: "3行目", dragThumb: true)
        assertSwitch(derive, now: "1")
        back(to: "除外した行")

        // Row 4 was a weekday-only row, so its original grade really is blank.
        // Supply all required cells through the native form before restoring it.
        visible(app.buttons["change-editor-row-4"], navigation: "除外した行").tap()
        screen("4行目")
        func field(_ column: Int) -> XCUIElement {
            app.collectionViews.textFields["change-editor-field-\(column)"]
        }
        func enter(_ value: String, in column: Int) {
            let input = visible(field(column), navigation: "4行目")
            XCTAssertTrue(input.isEnabled && input.isHittable)
            input.tap()
            input.typeText(value + "\n")
            let typed = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: input)
            XCTAssertEqual(XCTWaiter.wait(for: [typed], timeout: 10), .completed)
        }
        let grade = visible(field(0), navigation: "4行目")
        XCTAssertEqual(grade.placeholderValue, "修正値")
        let originalGrade = grade.value as? String ?? ""
        XCTAssertTrue(originalGrade.isEmpty || originalGrade == "修正値", originalGrade)
        enter("2", in: 0)
        enter("ZZ", in: 1)
        enter("2032/7/13", in: 2)
        enter("BLANK-GRADE", in: 6)
        let blankRowExcluded = app.switches["この行を除外"]
        XCTAssertEqual(visible(blankRowExcluded, navigation: "4行目").value as? String, "1")
        tapNativeSwitch(blankRowExcluded, navigation: "4行目", dragThumb: true)
        assertSwitch(blankRowExcluded, now: "0")
        back(to: "除外した行")
        back(to: "修正済み")
        back(to: review)
        tapToolbar("反映する", bar: review)
        alert.buttons["反映する"].tap()
        XCTAssertTrue(app.navigationBars["内容を確認・修正"].waitForNonExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(visible(app.staticTexts["変更後、架空除外科目B"]).exists)
        XCTAssertTrue(visible(app.staticTexts["変更後、BLANK-GRADE"], navigation: "時間割変更").exists)

        app.terminate()
        launchReady()
        openChanges()
        openEditedRows()
        visible(app.buttons["change-saved-derived"], navigation: "修正済み").tap()
        screen("曜日を補完した行")
        visible(app.buttons["change-editor-row-3"], navigation: "曜日を補完した行").tap()
        screen("3行目")
        XCTAssertEqual(visible(derive, navigation: "3行目").value as? String, "1")
        XCTAssertEqual(visible(excluded, navigation: "3行目").value as? String, "0")
        back(to: "曜日を補完した行")
        visible(app.buttons["change-editor-row-4"], navigation: "曜日を補完した行").tap()
        screen("4行目")
        XCTAssertEqual(visible(field(0), navigation: "4行目").value as? String, "2")
    }
}
