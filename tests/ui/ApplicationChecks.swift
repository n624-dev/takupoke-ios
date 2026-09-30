import XCTest

final class ApplicationChecks: XCTestCase {
    private var app: XCUIApplication!
    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--reset-fixture", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 30), app.debugDescription)
    }
    private func tab(_ title: String) { app.tabBars.buttons[title].tap() }
    private func tap(_ title: String) {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
        if !e.isHittable { app.swipeUp() }
        XCTAssertTrue(e.waitForExistence(timeout: 5), app.debugDescription)
        e.tap()
    }
    private func enableChangeNotifications() {
        let toggle = app.switches["時間割変更"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        let predicate = NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS %@", "Allow", "許可")
        for host in [app, XCUIApplication(bundleIdentifier: "com.apple.springboard")] {
            let allow = host.buttons.matching(predicate).firstMatch
            if allow.waitForExistence(timeout: 5) { allow.tap(); break }
        }
        let enabled = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: toggle)
        wait(for: [enabled], timeout: 15)
    }
    private func dismissLesson() {
        let bar = app.navigationBars["授業詳細"]
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.95)))
    }
    func testMergedCardsFromAllSources() {
        tab("時間割")
        for subject in ["架空科目A", "架空試験A", "架空返却A", "架空変更A"] {
            let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", subject)).firstMatch
            if !card.isHittable { app.swipeUp() }
            XCTAssertTrue(card.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertGreaterThan(card.frame.height, 72)
            card.tap()
            XCTAssertTrue(app.navigationBars["授業詳細"].waitForExistence(timeout: 5))
            dismissLesson()
        }
        XCTAssertTrue(app.staticTexts["架空行事A"].firstMatch.exists || app.buttons["架空行事A"].exists)
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
        tap("キャンセル")
        XCTAssertFalse(app.buttons["この週へ移動"].exists)
        if app.buttons["翌週"].exists { tap("翌週"); XCTAssertTrue(app.buttons["前週"].exists); tap("前週") }
    }
    func testSettingsAccountDataAndFileDetails() {
        tab("設定")
        tap("学校アカウントのデータ")
        XCTAssertTrue(app.staticTexts["授業時刻"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["名称対応表"].exists)
        XCTAssertTrue(app.staticTexts["リンク一覧"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("ファイル選択")
        XCTAssertTrue(app.buttons["通常時間割のファイルを選び直す"].waitForExistence(timeout: 5), app.debugDescription)
        tap("通常時間割の詳細を見る")
        XCTAssertTrue(app.staticTexts["fictional.pdf"].waitForExistence(timeout: 5), app.debugDescription)
        // Picker interactions are tested separately using the same production picker.
    }
    func testLinkPreferencesSurviveRelaunch() {
        tab("一覧")
        let link = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 10), app.debugDescription)
        link.press(forDuration: 1.2)
        tap("お気に入りを解除")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["一覧"].waitForExistence(timeout: 30))
        tab("一覧")
        let restored = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        restored.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["お気に入りに追加"].waitForExistence(timeout: 5), app.debugDescription)
        tap("お気に入りに追加")
    }
    func testLegalDocumentsAndIndividualLicenses() {
        tab("設定")
        tap("このアプリについて")
        tap("利用規約")
        XCTAssertFalse(app.staticTexts["文書を読み込めませんでした。"].exists)
        XCTAssertTrue(app.navigationBars["利用規約"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("プライバシーポリシー")
        XCTAssertTrue(app.navigationBars["プライバシーポリシー"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("オープンソースライセンス")
        for name in ["ZIPFoundation", "denpa-schedule-csv", "GRDB.swift"] {
            tap(name)
            XCTAssertFalse(app.staticTexts["ライセンス情報を読み取れません。"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Copyright")).firstMatch.exists, app.debugDescription)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }
    func testSetupCanBeSkippedAndOffersAllFiles() {
        tab("設定")
        tap("セットアップ")
        XCTAssertTrue(app.buttons["あとで設定"].waitForExistence(timeout: 5))
        tap("次へ")
        for name in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            let heading = app.staticTexts[name].firstMatch
            for _ in 0..<6 {
                if heading.exists && heading.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(heading.exists, app.debugDescription)
        }
        tap("次へ")
        XCTAssertTrue(app.staticTexts["3 / 3"].exists, app.debugDescription)
        tap("あとで設定")
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 5))
    }
    func testNotificationControlsAndAppearance() {
        tab("設定")
        tap("通知設定")
        XCTAssertTrue(app.switches["時間割変更"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["試験・返却"].exists)
        enableChangeNotifications()
        let specialToggle = app.switches["試験・返却"]
        specialToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        let enabled = expectation(for: NSPredicate(format: "value == '1'"), evaluatedWith: specialToggle)
        wait(for: [enabled], timeout: 10)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let color = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "メインカラー")).firstMatch
        XCTAssertTrue(color.exists, app.debugDescription)
        color.tap()
        for name in ["青", "緑", "黄色", "オレンジ", "赤", "ピンク", "紫"] {
            XCTAssertTrue(app.buttons[name].exists, app.debugDescription)
        }
        tap("緑")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "メインカラー", "緑")).firstMatch.exists)
    }
    func testChangedDataProducesOneLocalNotification() {
        tab("設定")
        tap("通知設定")
        enableChangeNotifications()
        app.terminate()
        app.launchArguments = ["--updated-changes", "--notification-probe", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        let result = app.staticTexts["fixture-notification-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 30))
        let received = expectation(for: NSPredicate(format: "label == %@", "1件の時間割変更を確認してください。"), evaluatedWith: result)
        wait(for: [received], timeout: 30)
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
            if output.utterance.contains("架空科目A") { break }
        }
        XCTAssertTrue(utterances.contains { $0.contains("架空科目A") }, utterances.joined(separator: " | "))
    }

    #else
    func testVoiceOverReadsTimetableCard() throws {
        throw XCTSkip("VoiceOver automation requires Xcode 27 and iOS 27")
    }
    #endif

}
