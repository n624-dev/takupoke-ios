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
        let e = app.buttons[title].firstMatch
        if !e.isHittable { app.swipeUp() }
        XCTAssertTrue(e.waitForExistence(timeout: 5), app.debugDescription)
        e.tap()
    }
    func testHomeTimetableAndWeekCalendar() {
        XCTAssertTrue(app.staticTexts["今日の予定"].waitForExistence(timeout: 10))
        tab("時間割")
        XCTAssertTrue(app.staticTexts["架空科目A"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
        // Actual merged cards must stay within the app frame.
        let cards = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空科目A"))
        XCTAssertGreaterThan(cards.count, 0)
        let first = cards.element(boundBy: 0)
        XCTAssertGreaterThan(first.frame.height, 0)
        XCTAssertLessThanOrEqual(first.frame.maxX, app.frame.maxX + 1)
        first.tap()
        XCTAssertTrue(app.staticTexts["架空教員A"].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        if app.buttons["閉じる"].exists { tap("閉じる") }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
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
        XCTAssertTrue(app.buttons["ファイルを選び直す"].firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        tap("詳細を見る")
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
        XCTAssertFalse(app.staticTexts["文書を読み取れません。"].exists)
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
            XCTAssertTrue(app.staticTexts[name].exists, app.debugDescription)
        }
        tap("次へ")
        XCTAssertTrue(app.staticTexts["クラス"].exists || app.buttons["1-1"].exists, app.debugDescription)
        tap("あとで設定")
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 5))
    }
    func testNotificationControlsAndAppearance() {
        tab("設定")
        tap("通知設定")
        XCTAssertTrue(app.switches["時間割変更"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["試験・返却"].exists)
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
    func testVoiceOverReadsTimetableCard() throws {
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

}
