import XCTest
import UIKit
import CryptoKit

extension ApplicationChecks {
    func testSettingsAccountDataAndFileDetails() {
        tab("設定")
        let ai = app.switches["use-ai-features"]
        _ = visible(ai)
        XCTAssertTrue(ai.waitForExistence(timeout: 10))
        XCTAssertEqual(ai.value as? String, "0")
        XCTAssertTrue(ai.label.contains("OCR"))
        XCTAssertEqual(app.staticTexts["fixture-recovery-off-blocked"].label, "1")
        let stored = app.staticTexts["fixture-stored-ai-permission"]
        XCTAssertEqual(stored.label, "0")
        var changeOrdinal = 0
        func changeAI(to value: String) {
            changeOrdinal += 1
            XCTAssertTrue(ai.isHittable, app.debugDescription)
            XCTAssertGreaterThan(ai.frame.width, 40)
            print(
                "AI_SWITCH before frame=\(ai.frame) UI=\(String(describing: ai.value)) stored=\(stored.label)"
            )
            recoveryScreenshot("ai-switch-before-\(changeOrdinal)")
            // The labelled row and the inner native switch have different
            // accessibility bounds. Activate the unique real control directly.
            tapNativeSwitch(ai)
            let reflected = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: ai)
            let saved = expectation(for: NSPredicate(format: "label == %@", value), evaluatedWith: stored)
            let completion = XCTWaiter.wait(for: [reflected, saved], timeout: 45)
            guard completion == .completed else {
                print(
                    "AI_SWITCH unresolved UI=\(String(describing: ai.value)) stored=\(stored.label) tree=\(app.debugDescription)"
                )
                recoveryScreenshot("ai-switch-unresolved-\(changeOrdinal)")
                XCTFail("Physical AI/OCR switch tap did not update both UI and stored permission")
                return
            }
            XCTAssertEqual(ai.value as? String, value)
            XCTAssertEqual(stored.label, value)
            print("AI_SWITCH after UI=\(String(describing: ai.value)) stored=\(stored.label)")
        }
        for value in ["1", "0", "1"] { changeAI(to: value) }
        app.terminate()
        app.launchArguments.removeAll { $0 == "--reset-fixture" }
        launchReady()
        tab("設定")
        _ = visible(ai)
        XCTAssertEqual(ai.value as? String, "1")
        XCTAssertEqual(stored.label, "1")
        changeAI(to: "0")
        app.terminate()
        launchReady()
        tab("設定")
        _ = visible(ai)
        XCTAssertEqual(ai.value as? String, "0")
        XCTAssertEqual(stored.label, "0")
        XCTAssertEqual(app.staticTexts["fixture-recovery-off-blocked"].label, "1")
        for _ in 0..<4 { app.swipeDown() }
        tap("リンク・名称・授業時刻")
        screen("リンク・名称・授業時刻")
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            tap(title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), app.debugDescription)
            XCTAssertTrue(app.staticTexts["最終取得"].exists, app.debugDescription)
            XCTAssertTrue(app.staticTexts["件数"].exists, app.debugDescription)
            back(to: "リンク・名称・授業時刻")
        }
        back(to: "設定")
        tap("学校行事")
        XCTAssertTrue(app.buttons["学校行事を更新"].waitForExistence(timeout: 5), app.debugDescription)
        let eventDetails = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "年度の学校行事の詳細を見る"))
            .firstMatch
        XCTAssertTrue(eventDetails.waitForExistence(timeout: 5), app.debugDescription)
        eventDetails.tap()
        XCTAssertTrue(app.staticTexts["件数"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        screen("学校行事")
        back(to: "設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        XCTAssertFalse(app.buttons["学校行事を更新"].exists)
        for title in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            tap("\(title)の詳細を見る")
            screen(title)
            let stateY = materialSection("状態", on: title).frame.minY
            let operationY = materialSection("操作", on: title).frame.minY
            XCTAssertLessThan(stateY, operationY)
            _ = materialSection("ファイル情報", on: title)
            _ = materialSection("解析結果", on: title)
            _ = heading("件数")
            XCTAssertFalse(app.staticTexts["解析件数"].exists)
            XCTAssertFalse(app.staticTexts["授業枠"].exists)
            XCTAssertTrue(
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "解析する")).firstMatch.exists)
            back(to: "時間割ファイル")
        }
        // Actual picker interactions are exercised by the dedicated picker suite.
    }
    func testUsageHelpIsOrganizedByTask() {
        tab("設定")
        tap("使い方")
        screen("使い方")
        for (title, headings) in [
            ("はじめに", ["1. OneDriveを準備する", "2. データを取得する", "3. 時間割ファイルを選ぶ", "4. 学校行事を取得する", "5. クラスを選ぶ"]),
            ("時間割を見る", ["今日の予定", "週の時間割", "時間割変更"]),
            ("リンクを使う", ["リンクを開く", "お気に入り・色・非表示"]),
            ("更新と通知", ["ファイルと学校行事", "リンク・名称・授業時刻", "通知", "バックグラウンドの確認", "4月・10月の切り替え"]),
            ("困ったとき", ["ファイルが更新されない", "解析に失敗する", "時間割変更の日付がおかしい", "ファイル選択が消えた"]),
        ] {
            tap(title)
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            for title in headings { _ = heading(title) }
            back(to: "使い方")
        }
    }
    func testSettingsGroupsAndCompactDataOverviews() {
        tab("設定")
        _ = heading("データ")
        _ = heading("アプリ設定")
        _ = heading("サポート")
        XCTAssertTrue(app.buttons["初期設定"].exists)
        app.swipeDown()
        tap("リンク・名称・授業時刻")
        screen("リンク・名称・授業時刻")
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            XCTAssertTrue(
                app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch.exists,
                app.debugDescription)
        }
        XCTAssertFalse(app.staticTexts["最終取得"].exists)
        XCTAssertFalse(app.staticTexts["件数"].exists)
        XCTAssertFalse(app.staticTexts["名称対応表"].exists)
        back(to: "設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        XCTAssertFalse(app.staticTexts["学校行事"].exists)
        XCTAssertFalse(app.staticTexts["最終取得"].exists)
        XCTAssertFalse(app.staticTexts["件数"].exists)
        XCTAssertTrue(app.buttons["自動確認を中止"].exists)
    }
    func testEmptyDataCanBeConfigured() {
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        tap("リンク・名称・授業時刻")
        screen("リンク・名称・授業時刻")
        XCTAssertTrue(app.buttons["学校アカウントで取得"].waitForExistence(timeout: 5), app.debugDescription)
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            let row = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "未取得")
            ).firstMatch
            XCTAssertTrue(row.exists, app.debugDescription)
        }
        back(to: "設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        for title in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            _ = heading(title)
            XCTAssertTrue(app.buttons["\(title)のファイルを選ぶ"].exists, app.debugDescription)
            XCTAssertFalse(app.buttons["\(title)の詳細を見る"].exists)
        }
    }
    func testChangedAccountDataNoticeOpensSharedAcquisition() {
        XCTAssertTrue(app.tabBars.buttons["ホーム"].waitForExistence(timeout: 30))
        let notice = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "名称データ", "更新があります")
        ).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 10), app.debugDescription)
        notice.tap()
        XCTAssertTrue(app.navigationBars["リンク・名称・授業時刻"].waitForExistence(timeout: 5))
        for title in ["リンク一覧", "名称データ", "授業時刻"] {
            XCTAssertTrue(
                app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", title, "更新あり")
                ).firstMatch.exists, app.debugDescription)
        }
    }
    func testFileFailuresKeepResultsAndStayInTheirOwnDetails() {
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        tap("時間割ファイル")
        screen("時間割ファイル")
        tap("通常時間割の詳細を見る")
        screen("通常時間割")
        XCTAssertFalse(app.staticTexts["架空の変更ファイル取得エラー"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "解析済み")).firstMatch.exists,
            app.debugDescription)
        back(to: "時間割ファイル")
        tap("時間割変更の詳細を見る")
        screen("時間割変更")
        XCTAssertTrue(app.staticTexts["架空の変更ファイル取得エラー"].exists, app.debugDescription)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "取得失敗（前回結果あり）")).firstMatch
                .exists, app.debugDescription)
        _ = heading("件数")
        back(to: "時間割ファイル")
        tap("試験時間割の詳細を見る")
        screen("試験時間割")
        XCTAssertFalse(app.staticTexts["架空の変更ファイル取得エラー"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "解析失敗（前回結果あり）")).firstMatch
                .exists, app.debugDescription)
        _ = heading("件数")
    }
    func testSettingsClassSelectionSharesTimetablePreference() {
        tab("設定")
        tap("クラス")
        tap("クラス")
        tap("4-IT")
        XCTAssertTrue(app.switches["留学生向けの授業も表示"].exists, app.debugDescription)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tab("時間割")
        let predicate = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "クラス", "4-IT")
        XCTAssertTrue(
            app.buttons.matching(predicate).firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 30))
        tab("設定")
        XCTAssertTrue(app.buttons.matching(predicate).firstMatch.exists, app.debugDescription)
    }
    func testLinkPreferencesSurviveRelaunch() {
        tab("一覧")
        let link = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 10), app.debugDescription)
        linkContextAction(link, title: "お気に入りを解除")
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        launchReady()
        XCTAssertTrue(app.tabBars.buttons["一覧"].waitForExistence(timeout: 30))
        tab("一覧")
        let restored = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        linkContextAction(restored, title: "お気に入りに追加")
    }
    private func linkContextAction(_ link: XCUIElement, title: String) {
        let bar = app.navigationBars["一覧"]
        let tabs = app.tabBars.firstMatch
        recoveryScreenshot("link-context-before-" + title)
        // Bound existence separately. A predicate with seven AX queries can
        // expire while a query is still resolving, despite valid final frames.
        guard bar.waitForExistence(timeout: 45), tabs.waitForExistence(timeout: 45),
            link.waitForExistence(timeout: 45)
        else {
            XCTFail("Link list controls are absent: " + app.debugDescription)
            return
        }
        let rowFrame = link.frame
        let barFrame = bar.frame
        let tabsFrame = tabs.frame
        let enabled = link.isEnabled
        guard enabled,
            [rowFrame, barFrame, tabsFrame].allSatisfy({
                !$0.isNull && !$0.isInfinite && $0.width > 0 && $0.height > 0
                    && [$0.minX, $0.minY, $0.maxX, $0.maxY].allSatisfy(\.isFinite)
            }), rowFrame.minY >= barFrame.maxY, rowFrame.maxY <= tabsFrame.minY
        else {
            print(
                "LINK_CONTEXT boundaries row=\(rowFrame);bar=\(barFrame);tabs=\(tabsFrame);enabled=\(enabled)"
            )
            print("LINK_CONTEXT unresolved tree=\(app.debugDescription)")
            recoveryScreenshot("link-context-unresolved-" + title)
            XCTFail("Link row is not wholly visible on its actual list screen")
            return
        }
        let text = link.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "架空リンクA")).firstMatch
        guard text.waitForExistence(timeout: 10), contained(text, in: rowFrame) else {
            XCTFail("Link text has no visible region inside its own row: " + app.debugDescription)
            return
        }
        // Press the observed text region inside this row. No OS-specific
        // guessed fraction of the row or second gesture rescues the result.
        print("LINK_CONTEXT physical row=\(link.frame);AX-hittable=\(link.isHittable);action=\(title)")
        print("LINK_CONTEXT text=\(text.frame)")
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 2)
        recoveryScreenshot("link-context-after-press-" + title)
        print("LINK_CONTEXT after-press tree=" + app.debugDescription)
        let action = app.buttons[title]
        XCTAssertTrue(action.waitForExistence(timeout: 45), app.debugDescription)
        XCTAssertTrue(action.isHittable, app.debugDescription)
        action.tap()
    }
    func testLegalDocumentsAndIndividualLicenses() {
        tab("設定")
        tap("このアプリについて")
        screen("このアプリについて")
        _ = heading("アプリ情報")
        _ = heading("規約・プライバシー")
        XCTAssertTrue(app.buttons["たくにんの利用規約"].exists)
        XCTAssertTrue(app.buttons["たくにんのプライバシーポリシー"].exists)
        tap("利用規約")
        XCTAssertFalse(app.staticTexts["文書を読み込めませんでした。"].exists)
        XCTAssertTrue(app.navigationBars["利用規約"].exists)
        back(to: "このアプリについて")
        tap("プライバシーポリシー")
        XCTAssertTrue(app.navigationBars["プライバシーポリシー"].exists)
        back(to: "このアプリについて")
        tap("オープンソースライセンス")
        screen("オープンソースライセンス")
        for (index, name) in ["ZIPFoundation", "denpa-schedule-csv", "GRDB.swift"].enumerated() {
            tap(name, searchEarlierRows: index > 0)
            XCTAssertFalse(app.staticTexts["ライセンス情報を読み取れません。"].exists)
            XCTAssertTrue(
                app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Copyright")).firstMatch
                    .exists, app.debugDescription)
            back(to: "オープンソースライセンス")
        }
        back(to: "このアプリについて")
        _ = heading("問い合わせ・配布")
        for title in ["ソースコード", "問い合わせ", "AltStore SourceのURLを共有"] {
            // SwiftUI Link has its own accessibility role; it need not have a
            // static-text child. ShareLink is exposed as a button.
            _ = visible(
                app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", title)).firstMatch
            )
        }
    }
    func testSetupCanBeSkippedAndOffersAllFiles() {
        tab("設定")
        tap("初期設定")
        screen("データを取得")
        XCTAssertTrue(app.buttons["あとで設定"].waitForExistence(timeout: 5))
        tapSetupNext(from: "データを取得")
        screen("時間割ファイル")
        for name in ["通常時間割", "時間割変更", "試験時間割", "試験返却時間割"] {
            _ = heading(name)
        }
        tap("学校行事を取得")
        screen("学校行事")
        back(to: "時間割ファイル")
        tapSetupNext(from: "時間割ファイル")
        screen("クラス")
        XCTAssertTrue(app.staticTexts["3 / 3"].exists, app.debugDescription)
        tapToolbar("あとで設定", bar: "クラス")
        XCTAssertTrue(app.tabBars.buttons["設定"].waitForExistence(timeout: 5))
    }
}
