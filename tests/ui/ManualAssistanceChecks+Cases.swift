import XCTest
import UIKit

extension ManualAssistanceChecks {
    func testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground() {
        launch()
        guard let key=fieldIDs(expectedCount:1)?.first else { return }
        let input=input(key), value="架空手確認科目"
        measuredStep("input-and-display") { prepareOneCorrection(key,input,value) }
        guard let processBefore=uniqueLabel("manual-process-launch",in:observation) else { return }
        XCTAssertFalse(processBefore.isEmpty)
        guard measuredStep("editor-background", {
            requireEditorSurvivesBackground(key,input,value,processBefore:processBefore)
        }) else { return }
        acknowledge(key);tapSubmit()
        guard measuredStep("review-background", {
            requireReviewSurvivesBackground(value,processBefore:processBefore)
        }) else { return }
        measuredStep("reedit-and-review") { reeditAndReviewCorrection(key,input,value) }
        measuredStep("save-and-relaunch") {
            openReviewPreview();requirePreview()
            persistAndRequireProof([key:value+"再確認"])
        }
    }
    func testChangedOriginalCannotSubmitOrReplaceLastGood() {
        launch()
        guard let key=fieldIDs(expectedCount:1)?.first else { return }
        edit(input(key),"架空変更前確認",id:key);acknowledge(key)
        chooseFixtureMenuAction("架空原本のハッシュを変更")
        XCTAssertTrue(observation.staticTexts["manual-mutation-complete"].waitForExistence(timeout:10),app.debugDescription)
        tapSubmit()
        XCTAssertTrue(recoveryList.staticTexts["原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        requireLastGood(in:observation)
        XCTAssertFalse(recoveryList.buttons["この資料全体の結果を使用"].exists)
        guard terminateCurrentFixture() else { return };launch()
        guard let second=fieldIDs(expectedCount:1)?.first else { return }
        edit(input(second),"架空再照合",id:second);acknowledge(second);tapSubmit()
        requireReview(["架空再照合"],comparable:false)
        chooseFixtureMenuAction("架空原本のハッシュを変更")
        XCTAssertTrue(observation.staticTexts["manual-mutation-complete"].waitForExistence(timeout:10),app.debugDescription)
        openReviewPreview()
        XCTAssertTrue(recoveryList.staticTexts["原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        requireLastGood(in:observation)
        XCTAssertFalse(recoveryList.buttons["この資料全体の結果を使用"].exists)
    }
    func testThreeFieldsRequireEachAcknowledgementAndFourRefuses() {
        launch(["--manual-three","--manual-comparable-prior"])
        guard let ids=fieldIDs(expectedCount:3) else { return }
        for i in 0..<3 {
            let input=input(ids[i]);edit(input,"架空手確認\(i)",id:ids[i])
            let ack=ack(ids[i]);XCTAssertEqual(visible(ack,knownID:"manual-ack-"+ids[i]).value as? String,"0");acknowledge(ids[i])
            assertSubmitEnabled(i==2)
        }
        tapSubmit();requireReview((0..<3).map { "架空手確認\($0)" },comparable:true)
        openReviewPreview();requirePreview()
        XCTAssertTrue(recoveryList.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        let navigation=app.navigationBars["時間割の復旧"],close=app.navigationBars["時間割の復旧"].buttons["閉じる"]
        XCTAssertTrue(close.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        let barFrame=navigation.frame,closeFrame=close.frame
        XCTAssertTrue(ManualScrollNavigation.usable(barFrame) && ManualScrollNavigation.usable(closeFrame) &&
                      barFrame.contains(closeFrame) && close.isEnabled && close.isHittable,app.debugDescription)
        close.tap();XCTAssertTrue(navigation.waitForNonExistence(timeout:nativeStateTimeout),app.debugDescription)
        requireLastGood(in:rootObservation)
        guard terminateCurrentFixture() else { return };launch(["--manual-four"])
        XCTAssertTrue(recoveryList.staticTexts["架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertFalse(submit.exists);XCTAssertFalse(observation.staticTexts["manual-field-ids"].exists)
        requireLastGood(in:observation)
    }

    func testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch() {
        // Independent source and XCTest completion; the original three cases
        // remain mandatory on both OS versions with their original controls.
        measuredStep("select-high-confidence-fields") {
            launch(["--fixture-link-press-trace"])
            guard let selectedKey=fieldIDs(expectedCount:1)?.first else { return }
            let selectedSubject = "架空選択科目"
            inspectSource(selectedKey)
            edit(self.input(selectedKey),selectedSubject,id:selectedKey)
            acknowledge(selectedKey);assertSubmitEnabled(true);tapSubmit()
            requireReview([selectedSubject],comparable:false)
            selectHighConfidenceFieldsAndRequireThreeFieldLimit(selectedKey,subject:selectedSubject)
        }
    }
}
