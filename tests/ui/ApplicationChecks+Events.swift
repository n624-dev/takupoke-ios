import XCTest
import UIKit

extension ApplicationChecks {
    func testAuxiliaryReadFailuresKeepLessonsAndWarnUntilFilesRecover() {
        let warnings = [
            "試験・返却資料の保存情報を読み込めませんでした。通常時間割は参考表示です。",
            "学校行事の保存情報を読み込めませんでした。通常時間割は参考表示です。",
        ]
        func lesson() -> XCUIElement {
            visible(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目A")).firstMatch)
        }
        func checkFailureWarnings() {
            for warning in warnings {
                let row = visible(app.staticTexts[warning])
                XCTAssertTrue(row.waitForExistence(timeout: 10), app.debugDescription)
            }
            XCTAssertFalse(app.staticTexts["学校行事は未取得です。"].exists, app.debugDescription)
        }
        func retry(_ title: String, warning: String) {
            let button = visible(app.buttons[title])
            guard button.waitForExistence(timeout: 5), contained(button, in: bodyViewport()),
                button.isEnabled, button.isHittable else {
                XCTFail("The real reload action must be operable: " + app.debugDescription)
                return
            }
            button.tap()
            XCTAssertTrue(app.staticTexts[warning].waitForExistence(timeout: 10), app.debugDescription)
        }
        checkFailureWarnings()
        retry("試験・返却資料を再読み込み", warning: warnings[0])
        retry("学校行事を再読み込み", warning: warnings[1])
        let card = lesson()
        guard contained(card, in: bodyViewport()), card.isEnabled, card.isHittable else {
            XCTFail("Loaded Home lesson must remain usable: " + app.debugDescription)
            return
        }
        card.tap()
        screen("授業詳細")
        XCTAssertTrue(app.staticTexts["架空科目A"].exists, app.debugDescription)
        dismissLesson()
        XCTAssertTrue(app.navigationBars["授業詳細"].waitForNonExistence(timeout: 10), app.debugDescription)
        screen("たくポケ")
        tab("時間割")
        checkFailureWarnings()
        XCTAssertTrue(lesson().exists, app.debugDescription)
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" || $0 == "--auxiliary-store-failures" }
        launchReady()
        // Only the owned obstructions were restored; use the original stores.
        for warning in warnings { XCTAssertFalse(app.staticTexts[warning].exists, app.debugDescription) }
        XCTAssertTrue(lesson().exists, app.debugDescription)
        tab("時間割")
        for warning in warnings { XCTAssertFalse(app.staticTexts[warning].exists, app.debugDescription) }
        XCTAssertTrue(lesson().exists, app.debugDescription)
    }

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
            let enteredResult = XCTWaiter.wait(for: [entered], timeout: 10)
            if enteredResult != .completed {
                let current = app.textFields["学校年度（空欄なら現在の学校年度）"]
                let present = current.exists
                let value = present ? current.value as? String : nil
                let digits = value.flatMap { value in
                    value.utf8.count <= 16 && value.utf8.allSatisfy { (48...57).contains($0) }
                        ? value : nil
                }
                let keyboardCount = app.keyboards.allElementsBoundByIndex.count
                print("SYNTHETIC_YEAR_INPUT failed;present=\(present);digits=\(digits ?? "unavailable");"
                    + "keyboards=\(keyboardCount)")
            }
            XCTAssertEqual(enteredResult, .completed, "Actual school-year input must match all four digits")
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
            let viewport = bodyViewport(navigation: "たくポケ")
            let headingQuery = app.collectionViews.staticTexts.matching(identifier: "今日の予定")
            let headings = headingQuery.allElementsBoundByAccessibilityElement
            XCTAssertLessThanOrEqual(headings.count, 1, "Require one current Home section heading")
            let headingFrame = headings.first?.frame ?? .null
            if !ObservedScreenGeometry.contains(headingFrame, in: viewport, scale: UIScreen.main.scale) {
                _ = visible(headingQuery.element(boundBy: 0), navigation: "たくポケ")
            }
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

extension ApplicationChecks {
    func testCountdownShowsProgressFromAnnouncementAndRestoresEditedLabel() {
        let label = "Fictional progress"
        let settings = "試験の自動表示"
        let cards = app.buttons.matching(identifier: "countdown-home-card")
        let card = cards.matching(NSPredicate(format: "label CONTAINS %@", "架空の進捗試験")).firstMatch
        tab("ホーム")
        XCTAssertTrue(visible(card, navigation: "たくポケ").exists, app.debugDescription)
        let progress = card.descendants(matching: .any)["countdown-progress"]
        XCTAssertFalse(progress.exists)
        XCTAssertFalse(card.label.contains("設定期間の経過率"), app.debugDescription)

        tab("設定")
        tap("カウントダウン")
        screen("カウントダウン")
        let automatic = visible(app.buttons["countdown-automatic"], navigation: "カウントダウン")
        XCTAssertTrue(automatic.isHittable, app.debugDescription)
        automatic.tap()
        screen(settings)
        let origin = app.descendants(matching: .any)["countdown-origin"]
        XCTAssertTrue(visible(origin, navigation: settings).exists, app.debugDescription)
        XCTAssertTrue((origin.label + (origin.value as? String ?? "")).contains("・自動"), app.debugDescription)
        let field = visible(app.textFields["countdown-progress-label"], navigation: settings)
        XCTAssertTrue(field.isHittable, app.debugDescription)
        let previous = field.value as? String ?? ""
        XCTAssertEqual(previous, "設定期間の経過率")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previous.count) + label)
        XCTAssertEqual(field.value as? String, label)
        tapToolbar("countdown-save", bar: settings)
        screen("カウントダウン")

        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        app.launchArguments.append("--countdown-progress-announced")
        launchReady()
        tab("ホーム")
        XCTAssertTrue(visible(card, navigation: "たくポケ").exists, app.debugDescription)
        XCTAssertTrue(card.label.contains(label) || (progress.exists && progress.label.contains(label)), app.debugDescription)
    }

    func testCountdownRegistersFollowsCalendarAndKeepsSourceWarningsConsistent() throws {
        let warning = "学校の元PDFと採用原本に差異があるため、配信データは更新待ちです。配信元による内容の確認・必要な更新が必要です。端末の再取得では解消しません。保存済みの行事を表示しています。"
        func identifying(_ identifier: String, title: String) -> XCUIElement {
            app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@", identifier, title)).firstMatch
        }
        func openCountdown() {
            tab("設定")
            tap("カウントダウン")
            screen("カウントダウン")
        }
        func fetchCurrentEvents(initial: Bool) {
            tab("設定")
            tap("学校行事")
            screen("学校行事")
            tap(initial ? "学校行事を取得" : "学校行事を更新")
            let confirmed = visible(app.staticTexts["行事データの更新確認"])
            XCTAssertTrue(confirmed.waitForExistence(timeout: 25), app.debugDescription)
        }
        func add(_ mode: String, opens destination: String) {
            let menu = app.buttons["countdown-add"]
            XCTAssertTrue(menu.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertTrue(menu.isEnabled && menu.isHittable, app.debugDescription)
            menu.tap()
            var selected: CGRect?
            var ambiguous = false
            let available = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard let root = try? self.app.snapshot(), let nodes = self.snapshotNodes(in: root),
                      self.usable(root.frame) else { return false }
                let choices = nodes.filter { $0.elementType == .button && $0.label == mode }
                if choices.count > 1 { ambiguous = true; return true }
                guard let choice = choices.first, choice.isEnabled, self.usable(choice.frame),
                      root.frame.contains(choice.frame) else { return false }
                selected = choice.frame
                return true
            }, object: nil)
            guard XCTWaiter.wait(for: [available], timeout: 5) == .completed, !ambiguous, let selected,
                  app.state == .runningForeground else {
                XCTFail("The countdown menu must expose one enabled action for \(mode)")
                return
            }
            print("UI_COUNTDOWN_MENU label=\(mode) frame=\(selected)")
            // The popup's synthesized accessibility activation point can be invalid.
            // Deliver one physical contact to its observed frame and require its actual destination.
            let point = CGPoint(x: selected.midX, y: selected.midY)
            do {
                try NativeTestContacts.send([.init(start: point, end: point, duration: 0.1, pauseAfterLift: 0)],
                                            named: "Countdown menu action")
            } catch {
                XCTFail("Countdown menu contact failed: \(error)")
                return
            }
            screen(destination)
        }
        func saveNamed(_ name: String) {
            let input = visible(app.textFields["countdown-name"])
            XCTAssertTrue(input.exists && input.isHittable, app.debugDescription)
            input.tap()
            input.typeText(name)
            let save = app.buttons["countdown-save"]
            XCTAssertTrue(save.isEnabled && save.isHittable, app.debugDescription)
            save.tap()
        }
        func matchingWarning() -> XCUIElement {
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", warning)).firstMatch
        }
        func verifyExam(named title: String) {
            let secondRange = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "実施区間 2、")).firstMatch
            XCTAssertTrue(visible(secondRange, navigation: "予定の詳細").exists, app.debugDescription)
            let officialName = app.staticTexts.matching(NSPredicate(format: "label == %@", "学校公表の名称、\(title)")).firstMatch
            XCTAssertTrue(visible(officialName, navigation: "予定の詳細").exists, app.debugDescription)
        }

        fetchCurrentEvents(initial: true)
        back(to: "設定")
        openCountdown()
        add("自分で入力", opens: "カウントダウンを設定")
        saveNamed("Fictional personal plan")
        screen("カウントダウン")
        XCTAssertTrue(identifying("countdown-list-card", title: "Fictional personal plan").waitForExistence(timeout: 10), app.debugDescription)
        add("学校行事を選ぶ", opens: "学校行事を選ぶ")
        let exam = visible(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空の分割試験A")).firstMatch)
        XCTAssertTrue(exam.exists && exam.isHittable, app.debugDescription)
        exam.tap()
        screen("カウントダウンを設定")
        saveNamed("Fictional exam alias")
        screen("学校行事を選ぶ")
        back(to: "カウントダウン")
        let fixed = visible(identifying("countdown-list-card", title: "Fictional exam alias"))
        XCTAssertTrue(fixed.exists && fixed.isHittable, app.debugDescription)
        fixed.tap()
        screen("予定の詳細")
        verifyExam(named: "架空の分割試験A")
        tab("ホーム")
        XCTAssertFalse(matchingWarning().exists, app.debugDescription)

        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" || $0 == "--countdown-source-checking" }
        app.launchArguments += ["--countdown-calendar-update", "--countdown-different-source"]
        launchReady()
        fetchCurrentEvents(initial: false)
        let current = visible(matchingWarning())
        XCTAssertTrue(current.waitForExistence(timeout: 25), app.debugDescription)
        let sourceStatus = app.staticTexts["元PDFの確認、更新待ち"]
        XCTAssertTrue(visible(sourceStatus, navigation: "学校行事", searchEarlierRows: true).exists, app.debugDescription)
        back(to: "設定")
        openCountdown()
        let restored = visible(identifying("countdown-list-card", title: "Fictional exam alias"))
        XCTAssertTrue(restored.exists && restored.isHittable, app.debugDescription)
        restored.tap()
        screen("予定の詳細")
        verifyExam(named: "架空訂正試験B")
        tab("ホーム")
        XCTAssertTrue(visible(matchingWarning()).exists, app.debugDescription)
        tab("時間割")
        XCTAssertTrue(visible(matchingWarning()).exists, app.debugDescription)
    }
}
