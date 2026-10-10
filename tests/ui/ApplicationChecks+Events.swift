import XCTest

extension ApplicationChecks {
    func testEventCacheCorruptionKeepsHealthyYearAndAllowsExplicitRepair() {
        let warningText = "2033年度の保存済み学校行事を読み取れません。正常な年度の結果は表示しています。該当年度を再取得してください。端末内の結果は削除していません。"
        func selectYear(_ digits: String, replacing: Bool) {
            let field = app.textFields["学校年度（空欄なら現在の学校年度）"]
            for _ in 0..<6 {
                if field.exists && field.isHittable
                    && field.frame.minY >= app.navigationBars["学校行事"].frame.maxY
                {
                    break
                }
                app.swipeDown()
            }
            XCTAssertTrue(field.exists && field.isHittable, app.debugDescription)
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), app.debugDescription)
            field.typeText(
                (replacing ? String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) : "") + digits)
            let entered = expectation(
                for: NSPredicate { _, _ in
                    field.exists && field.value as? String == digits
                }, evaluatedWith: field)
            wait(for: [entered], timeout: 10)
            XCTAssertEqual(field.value as? String, digits, app.debugDescription)
            app.swipeUp()  // Dismiss the number pad through the List's standard behavior.
        }
        func openSavedEvent(_ year: Int, title: String) {
            let detail = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "年度の学校行事の詳細を見る"))
                .firstMatch
            XCTAssertTrue(detail.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertEqual(
                detail.label.replacingOccurrences(of: ",", with: ""), "\(year)年度の学校行事の詳細を見る",
                app.debugDescription)
            tap(detail.label)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), app.debugDescription)
            back(to: "学校行事")
        }
        tab("設定")
        tap("学校行事")
        screen("学校行事")
        selectYear("2032", replacing: false)
        let warning = app.staticTexts[warningText].firstMatch
        _ = visible(warning)
        XCTAssertTrue(app.buttons["学校行事を更新"].isEnabled, app.debugDescription)
        recoveryScreenshot("ios-events-cache-warning")
        openSavedEvent(2032, title: "架空正常行事2032")
        tap("学校行事を更新")
        let healthyUpdated = expectation(
            for: NSPredicate { _, _ in
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
        launchReady()
        tab("設定")
        tap("学校行事")
        screen("学校行事")
        XCTAssertFalse(app.staticTexts[warningText].exists, app.debugDescription)
        XCTAssertFalse(app.staticTexts["再取得が必要"].exists, app.debugDescription)
        openSavedEvent(2033, title: "架空行事更新2033")
        print(
            "SYNTHETIC_EVENTS_CACHE_UI healthy visible/fetch enabled; other-year fetch kept warning; actual same-year repair and process restart cleared warning"
        )
    }
    func testEventAvailabilityUsesCurrentDayAndAllSevenWeekDates() {
        let notice = "学校行事は未取得です。"
        let noClasses = "授業はありません。"
        func relaunch(_ arguments: [String]) {
            app.terminate()
            app.launchArguments =
                [
                    "--reset-fixture", "--events-year-coverage", "--normal-only",
                    "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP",
                ] + arguments
            launchReady()
        }
        func home(hasNotice: Bool, hasLesson: Bool, saysNoClasses: Bool) {
            tab("ホーム")
            _ = heading("今日の予定")
            XCTAssertTrue(app.staticTexts["3月31日（木）"].exists, app.debugDescription)
            assertPresence(notice, expected: hasNotice)
            assertPresence(noClasses, expected: saysNoClasses)
            let lesson = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空年度確認科目A"))
                .firstMatch
            if hasLesson {
                XCTAssertTrue(lesson.waitForExistence(timeout: 10), app.debugDescription)
                XCTAssertTrue(lesson.isHittable, app.debugDescription)
            } else {
                let actual = app.buttons.matching(NSPredicate(
                    format: "label CONTAINS %@", "架空年度確認科目A")).allElementsBoundByIndex
                XCTAssertTrue(actual.isEmpty, app.debugDescription)
            }
        }
        func boundaryWeek(hasNotice: Bool) {
            tab("時間割")
            XCTAssertTrue(app.buttons["3月28日から4月3日"].waitForExistence(timeout: 10), app.debugDescription)
            assertPresence(notice, expected: hasNotice)
        }
        func assertPresence(_ label: String, expected: Bool) {
            // Resolve actual matches once. An absent firstMatch.exists query
            // can stall iOS27 AX; an empty observation still means absent.
            let actual = app.staticTexts.matching(NSPredicate(
                format: "label == %@", label)).allElementsBoundByIndex
            XCTAssertEqual(!actual.isEmpty, expected, app.debugDescription)
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
        boundaryWeek(hasNotice: true)  // April 1–3 still need school year 2033.
        relaunch(["--events-year-both"])
        home(hasNotice: false, hasLesson: true, saysNoClasses: false)
        boundaryWeek(hasNotice: false)
        print(
            "SYNTHETIC_EVENTS_YEAR_UI past-only cache kept missing notice and usable lessons; no false no-classes; other-day yearly coverage; March28-April3 week required both school years"
        )
    }
}
