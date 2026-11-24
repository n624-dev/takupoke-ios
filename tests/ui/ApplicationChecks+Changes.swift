import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func testUpdatedWeekdayExclusionsCarryOverAndResolveInGroups() {
        let detail = "時間割変更", review = "内容を確認・修正", groupPage = "「日」だけの行"
        let pending = app.staticTexts["change-pending-row-count"]
        let count = app.staticTexts["change-skipped-count"]
        let addedLesson = app.staticTexts["変更後、架空追加科目B"]
        func openDetail() {
            tab("設定")
            visible(app.buttons["時間割ファイル"], navigation: "設定").tap()
            screen("時間割ファイル")
            visible(app.buttons["時間割変更の詳細を見る"], navigation: "時間割ファイル").tap()
            screen(detail)
        }
        func refresh() {
            let button = visible(app.buttons["同じファイルを再取得"], navigation: detail, searchEarlierRows: true)
            XCTAssertTrue(button.isEnabled && button.isHittable)
            button.tap()
            let ready = expectation(for: NSPredicate { _, _ in button.exists && button.isEnabled }, evaluatedWith: button)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        }
        func openReview() {
            visible(app.buttons[review], navigation: detail, searchEarlierRows: true).tap()
            screen(review)
        }
        func choose(_ selection: String) {
            let group = visible(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "change-group-weekdayOnly-3-")).element,
                                navigation: review)
            XCTAssertTrue(group.label.contains(groupPage), group.label)
            group.tap()
            screen(groupPage)
            let row = visible(app.buttons[selection], navigation: groupPage)
            XCTAssertTrue(row.isEnabled && row.isHittable)
            row.tap()
            let selected = expectation(for: NSPredicate { _, _ in row.isSelected }, evaluatedWith: row)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 15), .completed)
            let confirm = visible(app.buttons["change-confirm-carryover-exclusion"], navigation: groupPage, searchEarlierRows: true)
            XCTAssertTrue(confirm.isEnabled && confirm.isHittable)
            confirm.tap()
            screen(review)
        }
        func requirePending(_ rows: Int) {
            XCTAssertEqual(visible(pending, navigation: review, searchEarlierRows: true).label,
                           "あと\(rows)行の確認が必要です。")
            XCTAssertFalse(app.navigationBars[review].buttons["反映する"].isEnabled)
        }

        openDetail()
        XCTAssertTrue(visible(count, navigation: detail).label.contains("90行"))
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        app.launchArguments.append("--change-weekday-carryover-update")
        launchReady()
        app.launchArguments.removeAll { $0 == "--change-weekday-carryover-update" }
        openDetail()
        refresh()
        XCTAssertFalse(addedLesson.exists)
        openReview()
        requirePending(45)
        XCTAssertTrue(visible(app.buttons["change-edited-rows"], navigation: review).label.contains("45行"))
        XCTAssertFalse(app.buttons["change-editor-row-49"].exists)
        choose("change-select-row-49")
        requirePending(44)
        tapToolbar("閉じる", bar: review)
        screen(detail)
        XCTAssertFalse(addedLesson.exists)
        openReview()
        requirePending(45)
        choose("change-select-all")
        XCTAssertFalse(pending.exists)
        tapToolbar("反映する", bar: review)
        let confirm = app.alerts["個人修正を反映しますか？"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 15))
        confirm.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars[review].exists)
        tapToolbar("反映する", bar: review)
        confirm.buttons["反映する"].tap()
        XCTAssertTrue(app.navigationBars[review].waitForNonExistence(timeout: 30), app.debugDescription)
        XCTAssertTrue(visible(count, navigation: detail, searchEarlierRows: true).label.contains("90行"))
        XCTAssertTrue(visible(addedLesson, navigation: detail).exists)

        app.terminate()
        launchReady()
        openDetail()
        refresh()
        XCTAssertTrue(visible(count, navigation: detail, searchEarlierRows: true).label.contains("90行"))
        XCTAssertTrue(visible(addedLesson, navigation: detail).exists)
        openReview()
        XCTAssertFalse(pending.exists)
        XCTAssertTrue(visible(app.buttons["change-edited-rows"], navigation: review).label.contains("90行"))
    }

    private func assertRetainedChangeRows(stage: String) {
        let retainedIsVisible = visible(app.staticTexts["変更後、架空科目C"]).exists
        XCTAssertTrue(retainedIsVisible)
        let excludedExists = app.staticTexts["変更後、架空除外科目B"].exists
        XCTAssertFalse(excludedExists)
        print("RETAINED_CHANGE stage=\(stage) visible=\(retainedIsVisible) excluded=\(!excludedExists)")
    }

    private func tapRowReviewApply(in page: String) {
        let navigation = app.navigationBars[page]
        guard navigation.waitForExistence(timeout: 10) else {
            XCTFail("Row review navigation did not appear: " + page)
            return
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 10
        let scale = UIScreen.main.scale
        var observed: CGRect?
        var observation = "no navigation snapshot"
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline,
                  let bar = try? navigation.snapshot(), bar.elementType == .navigationBar,
                  bar.identifier == page || bar.label == page,
                  let nodes = self.snapshotNodes(in: bar) else { return false }
            let candidates = nodes.filter { $0.elementType == .button &&
                ($0.identifier == "反映する" || $0.label == "反映する") }
            observation = "matching=\(candidates.count);bar=\(bar.frame)"
            if candidates.count > 1 { return true }
            guard let button = candidates.first else { return false }
            observation += ";button=\(button.frame);enabled=\(button.isEnabled)"
            guard button.isEnabled, ObservedScreenGeometry.contains(button.frame, in: bar.frame, scale: scale),
                  ProcessInfo.processInfo.systemUptime <= deadline else { return false }
            observed = button.frame
            return true
        }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: 10) == .completed, let frame = observed else {
            XCTFail("Row review must expose one visible and enabled apply button: " + observation)
            return
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        print("NATIVE_ROW_APPLY \(observation);contact=\(center)")
        do {
            try NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)],
                                        named: "Apply reviewed timetable rows")
        } catch {
            XCTFail("Row apply contact failed: \(error)")
        }
    }

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
        func openReview(searchEarlierRows: Bool = false) {
            let action = visible(app.buttons[review], navigation: "時間割変更", searchEarlierRows: searchEarlierRows)
            XCTAssertTrue(action.isEnabled && action.isHittable, app.debugDescription)
            action.tap()
            screen(review)
            XCTAssertFalse(app.alerts["曜日を確認できないファイルです"].exists)
        }
        func selectRows(_ identifier: String, on page: String) {
            let matches = app.collectionViews.buttons.matching(identifier: identifier)
            let control = visible(matches.element, navigation: page)
            guard let button = try? control.snapshot(), button.elementType == .button,
                  button.identifier == identifier, button.isEnabled, !button.isSelected,
                  ObservedScreenGeometry.usable(button.frame) else {
                XCTFail("Row selection must expose one visible, enabled and unselected button: " + identifier)
                return
            }
            let center = CGPoint(x: button.frame.midX, y: button.frame.midY)
            print("NATIVE_ROW_SELECTION id=\(identifier);button=\(button.frame);contact=\(center)")
            do {
                try NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)],
                                            named: "Select one timetable change row control")
            } catch {
                XCTFail("Row selection contact failed: \(error)")
                return
            }
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let current = try? control.snapshot(), current.identifier == identifier else { return false }
                return current.isSelected
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 15), .completed)
        }
        openChanges()
        openReview()
        XCTAssertTrue(visible(app.staticTexts["修正は「反映する」を押すまで時間割に反映されません。"], navigation: review).exists)
        let apply = app.navigationBars[review].buttons["反映する"]
        XCTAssertTrue(apply.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(app.navigationBars[review].buttons["閉じる"].exists)
        XCTAssertFalse(apply.isEnabled)
        func exclude(_ id: String, page: String, selection: String) {
            visible(app.buttons[id], navigation: review).tap()
            screen(page)
            if selection == "change-select-row-3" {
                let detail = visible(app.buttons["change-editor-row-3"], navigation: page)
                XCTAssertTrue(detail.label.contains("原本の曜日 月 → 補完後 火"), detail.label)
                XCTAssertTrue(detail.label.contains("要確認1項目"), detail.label)
            }
            selectRows(selection, on: page)
            visible(app.buttons["選んだ行を除外"], navigation: page, searchEarlierRows: true).tap()
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
            screen("学年が空欄の変更")
            selectRows("change-select-row-\(row)", on: "学年が空欄の変更")
            let input = visible(app.textFields["change-group-value"], navigation: "学年が空欄の変更")
            input.tap()
            input.typeText(value + "\n")
            let entered = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: input)
            wait(for: [entered], timeout: 10)
            let applyGrade = visible(app.buttons["選んだ行に入力"], navigation: "学年が空欄の変更", searchEarlierRows: true)
            XCTAssertTrue(applyGrade.exists && applyGrade.isEnabled && applyGrade.isHittable, app.debugDescription)
            applyGrade.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1)
            screen(review)
        }
        tapRowReviewApply(in: review)
        let alert = app.alerts["個人修正を反映しますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 15))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","200〜300行目")).firstMatch.exists)
        alert.buttons["キャンセル"].tap()
        XCTAssertTrue(app.navigationBars[review].exists)
        tapRowReviewApply(in: review)
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
        assertRetainedChangeRows(stage: "after-apply")
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
        assertRetainedChangeRows(stage: "after-relaunch")

        func openEditedRows(searchEarlierRows: Bool = false) {
            openReview(searchEarlierRows: searchEarlierRows)
            visible(app.buttons["change-edited-rows"], navigation: review).tap()
            screen("修正済み")
        }
        // The retention checks have scrolled past the actions into the saved rows.
        openEditedRows(searchEarlierRows: true)
        visible(app.buttons["change-saved-excluded"], navigation: "修正済み").tap()
        screen("除外した行")
        visible(app.buttons["change-editor-row-3"], navigation: "除外した行").tap()
        screen("3行目")
        XCTAssertEqual(app.textFields["change-editor-field-0"].value as? String, "1")
        func assertSwitch(_ control: XCUIElement, now value: String) {
            let updated = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: control)
            XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 15), .completed, app.debugDescription)
        }
        func rowControl(_ element: XCUIElement, row: Int) -> XCUIElement {
            let form = app.collectionViews["change-editor-form-\(row)"]
            let labels = form.staticTexts.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", "原本は空欄", "原本　"))
            return visible(element, navigation: "\(row)行目", scrollLabels: labels)
        }
        let originalDate = app.collectionViews.staticTexts["原本　2026年11月17日"]
        XCTAssertTrue(rowControl(originalDate, row: 3).exists)
        let dateField = rowControl(app.textFields["change-editor-field-2"], row: 3)
        XCTAssertEqual(dateField.value as? String, "2026年11月17日")
        let excluded = app.switches["この行を除外"]
        XCTAssertEqual(rowControl(excluded, row: 3).value as? String, "1")
        tapNativeSwitch(excluded, navigation: "3行目", thumbDragDuration: 0.33)
        assertSwitch(excluded, now: "0")
        let derive = app.switches["曜日を日付から補完"]
        XCTAssertEqual(rowControl(derive, row: 3).value as? String, "0")
        tapNativeSwitch(derive, navigation: "3行目", thumbDragDuration: 0.33)
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
            let input = rowControl(field(column), row: 4)
            XCTAssertTrue(input.isEnabled && input.isHittable)
            input.tap()
            input.typeText(value + "\n")
            let typed = expectation(for: NSPredicate(format: "value == %@", column == 2 ? "2032年7月13日" : value), evaluatedWith: input)
            XCTAssertEqual(XCTWaiter.wait(for: [typed], timeout: 10), .completed)
        }
        let grade = rowControl(field(0), row: 4)
        XCTAssertEqual(grade.placeholderValue, "修正値")
        let originalGrade = grade.value as? String ?? ""
        XCTAssertTrue(originalGrade.isEmpty || originalGrade == "修正値", originalGrade)
        enter("2", in: 0)
        enter("ZZ", in: 1)
        enter("2032/7/13", in: 2)
        enter("BLANK-GRADE", in: 6)
        let blankRowExcluded = app.switches["この行を除外"]
        XCTAssertEqual(rowControl(blankRowExcluded, row: 4).value as? String, "1")
        tapNativeSwitch(blankRowExcluded, navigation: "4行目", thumbDragDuration: 0.33)
        assertSwitch(blankRowExcluded, now: "0")
        back(to: "除外した行")
        back(to: "修正済み")
        back(to: review)
        tapRowReviewApply(in: review)
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
        XCTAssertEqual(rowControl(derive, row: 3).value as? String, "1")
        XCTAssertEqual(rowControl(excluded, row: 3).value as? String, "0")
        back(to: "曜日を補完した行")
        visible(app.buttons["change-editor-row-4"], navigation: "曜日を補完した行").tap()
        screen("4行目")
        XCTAssertEqual(rowControl(field(0), row: 4).value as? String, "2")
    }
}
