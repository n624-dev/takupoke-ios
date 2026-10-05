import XCTest
import UIKit

final class ManualAssistanceChecks:XCTestCase {
    private var app:XCUIApplication!
    override func setUp() { continueAfterFailure=false;app=XCUIApplication() }
    private func launch(_ flags:[String]=[]) {
        app.launchArguments=["--reset-fixture","--manual-ui","--manual-integral-rails","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]+flags
        app.launch();XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout:45),app.debugDescription)
        app.tabBars.buttons["設定"].tap();tap("時間割ファイル");tap("通常時間割の詳細を見る");tap("端末内で復旧する");tap("端末内で復旧を開始")
    }
    private func visible(_ e:XCUIElement)->XCUIElement {
        let list=app.collectionViews.element(boundBy:max(0,app.collectionViews.count-1))
        for _ in 0..<16 {
            if e.exists && e.isHittable { return e }
            if e.exists && e.frame.minY<app.navigationBars.firstMatch.frame.maxY { list.swipeDown() } else { list.swipeUp() }
        }
        XCTAssertTrue(e.exists && e.isHittable,app.debugDescription);return e
    }
    private func tap(_ title:String) { visible(app.buttons[title].firstMatch).tap() }
    private func emitDiagnostic() {
        let diagnostic=app.staticTexts["manual-qa-diagnostic"].firstMatch
        print("TAKUPOKE-MANUAL-QA "+(diagnostic.exists ? diagnostic.label:"diagnostic-missing"))
    }
    private func fieldsExist()->Bool {
        let ready=app.staticTexts["manual-field-ids"].waitForExistence(timeout:15)
        emitDiagnostic()
        return ready
    }
    private var submit:XCUIElement { app.buttons["manual-submit"] }
    private var fieldIDs:[String] { app.staticTexts["manual-field-ids"].firstMatch.label.split(separator:"|").map(String.init) }
    private func input(_ id:String)->XCUIElement { app.descendants(matching:.any)["manual-value-"+id].firstMatch }
    private func ack(_ id:String)->XCUIElement { app.switches["manual-ack-"+id].firstMatch }
    private var acks:XCUIElementQuery { app.switches.matching(NSPredicate(format:"identifier BEGINSWITH 'manual-ack-'")) }
    private func edit(_ e:XCUIElement,_ value:String) {
        visible(e).tap(); e.press(forDuration:1.1)
        if app.menuItems["すべてを選択"].waitForExistence(timeout:2) { app.menuItems["すべてを選択"].tap() }
        else if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        else { e.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:(e.value as? String)?.count ?? 0)) }
        e.typeText(value)
    }
    func testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground() {
        launch();XCTAssertTrue(fieldsExist(),app.debugDescription);let input=input(fieldIDs[0])
        XCTAssertEqual(acks.count,1);XCTAssertEqual(acks.firstMatch.value as? String,"0")
        XCTAssertFalse(visible(submit).isEnabled)
        let value="架空手確認科目";edit(input,value);visible(acks.firstMatch).tap()
        XCTAssertTrue(visible(submit).isEnabled)
        tap("架空検証");tap("表示サイズを変更")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(acks.firstMatch).value as? String,"1")
        tap("架空検証");tap("同じ原本の状態を再確認")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(acks.firstMatch).value as? String,"1")
        XCUIDevice.shared.press(.home);app.activate()
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(acks.firstMatch).value as? String,"1")
        edit(input,value+"改");XCTAssertEqual(visible(acks.firstMatch).value as? String,"0")
        XCTAssertFalse(visible(submit).isEnabled)
        XCTAssertTrue(app.images.matching(NSPredicate(format:"identifier BEGINSWITH 'manual-crop-'")).firstMatch.exists)
        visible(acks.firstMatch).tap();visible(submit).tap()
        XCTAssertTrue(app.staticTexts["採用する資料全体"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        tap("この資料全体の結果を使用")
        XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("adopted=1;valid=true"))
        app.terminate();app.launchArguments=["--manual-ui","-AppleLanguages","(ja)","-AppleLocale","ja_JP"];app.launch()
        XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout:45))
        // The fixture probe also needs an app-root copy to inspect persisted results without reopening a recovery draft.
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("adopted=1;valid=true"))
    }
    func testChangedOriginalCannotSubmitOrReplaceLastGood() {
        launch();XCTAssertTrue(fieldsExist())
        let key=fieldIDs[0];edit(input(key),"架空変更前確認");visible(ack(key)).tap()
        tap("架空検証");tap("架空原本のハッシュを変更")
        XCTAssertTrue(app.staticTexts["manual-mutation-complete"].waitForExistence(timeout:10),app.debugDescription)
        visible(submit).tap()
        XCTAssertTrue(app.staticTexts["原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        XCTAssertFalse(app.buttons["この資料全体の結果を使用"].exists)
    }
    func testThreeFieldsRequireEachAcknowledgementAndFourRefuses() {
        launch(["--manual-three"])
        XCTAssertTrue(fieldsExist());let ids=fieldIDs;XCTAssertEqual(ids.count,3)
        for i in 0..<3 {
            let input=input(ids[i]);edit(input,"架空手確認\(i)")
            let ack=ack(ids[i]);XCTAssertEqual(visible(ack).value as? String,"0");visible(ack).tap()
            XCTAssertEqual(visible(submit).isEnabled,i==2)
        }
        visible(submit).tap();XCTAssertTrue(app.staticTexts["採用する資料全体"].waitForExistence(timeout:20))
        XCTAssertTrue(app.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        tap("閉じる");XCTAssertFalse(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("adopted="))
        app.terminate();launch(["--manual-four"])
        XCTAssertTrue(app.staticTexts["架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        emitDiagnostic()
        XCTAssertFalse(submit.exists);XCTAssertFalse(app.staticTexts["manual-field-ids"].exists)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
    }
}
