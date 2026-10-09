import XCTest
import UIKit

extension ManualAssistanceChecks {
    func testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground() {
        launch();XCTAssertTrue(fieldsExist(),app.debugDescription);XCTAssertEqual(fieldIDs.count,1)
        let key=fieldIDs[0], input=input(key), value="架空手確認科目"
        measuredStep("input-and-display") { prepareOneCorrection(key,input,value) }
        let processBefore=app.staticTexts["manual-process-launch"].firstMatch.label
        XCTAssertFalse(processBefore.isEmpty)
        guard measuredStep("editor-background", {
            requireEditorSurvivesBackground(key,input,value,processBefore:processBefore)
        }) else { return }
        acknowledge(key);visible(submit).tap()
        guard measuredStep("review-background", {
            requireReviewSurvivesBackground(value,processBefore:processBefore)
        }) else { return }
        measuredStep("reedit-and-review") { reeditAndReviewCorrection(key,input,value) }
        measuredStep("save-and-relaunch") { adoptAndRequirePersistedCorrection() }
    }
    func testChangedOriginalCannotSubmitOrReplaceLastGood() {
        launch();XCTAssertTrue(fieldsExist())
        let key=fieldIDs[0];edit(input(key),"架空変更前確認",id:key);acknowledge(key)
        tap("架空検証");tap("架空原本のハッシュを変更")
        XCTAssertTrue(app.staticTexts["manual-mutation-complete"].waitForExistence(timeout:10),app.debugDescription)
        visible(submit).tap()
        XCTAssertTrue(app.staticTexts["原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        XCTAssertFalse(app.buttons["この資料全体の結果を使用"].exists)
        app.terminate();launch()
        XCTAssertTrue(fieldsExist())
        let second=fieldIDs[0];edit(input(second),"架空再照合",id:second);acknowledge(second);visible(submit).tap()
        requireReview(["架空再照合"],comparable:false)
        tap("架空検証");tap("架空原本のハッシュを変更")
        XCTAssertTrue(app.staticTexts["manual-mutation-complete"].waitForExistence(timeout:10),app.debugDescription)
        tap("訂正と変更を確認して資料全体へ")
        XCTAssertTrue(app.staticTexts["原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        XCTAssertFalse(app.buttons["この資料全体の結果を使用"].exists)
    }
    func testThreeFieldsRequireEachAcknowledgementAndFourRefuses() {
        launch(["--manual-three","--manual-comparable-prior"])
        XCTAssertTrue(fieldsExist());let ids=fieldIDs;XCTAssertEqual(ids.count,3)
        for i in 0..<3 {
            let input=input(ids[i]);edit(input,"架空手確認\(i)",id:ids[i])
            let ack=ack(ids[i]);XCTAssertEqual(visible(ack).value as? String,"0");acknowledge(ids[i])
            assertSubmitEnabled(i==2)
        }
        visible(submit).tap();requireReview((0..<3).map { "架空手確認\($0)" },comparable:true)
        tap("訂正と変更を確認して資料全体へ");requirePreview()
        XCTAssertTrue(app.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        let navigation=app.navigationBars["時間割の復旧"],close=app.navigationBars["時間割の復旧"].buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        XCTAssertTrue(ManualScrollNavigation.usable(navigation.frame) && ManualScrollNavigation.usable(close.frame) &&
                      navigation.frame.contains(close.frame) && close.isEnabled && close.isHittable,app.debugDescription)
        close.tap();XCTAssertTrue(navigation.waitForNonExistence(timeout:nativeStateTimeout),app.debugDescription)
        XCTAssertFalse(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("adopted="))
        app.terminate();launch(["--manual-four"])
        XCTAssertTrue(app.staticTexts["架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        emitDiagnostic()
        XCTAssertFalse(submit.exists);XCTAssertFalse(app.staticTexts["manual-field-ids"].exists)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
    }
}
