import XCTest
import UIKit

extension ManualAssistanceChecks {
    func measuredStep<T>(_ name: String, _ body: () -> T) -> T {
        let start = ProcessInfo.processInfo.systemUptime
        print("TAKUPOKE-MANUAL-STEP start=\(name)")
        defer { print("TAKUPOKE-MANUAL-STEP end=\(name);seconds=\(ProcessInfo.processInfo.systemUptime-start)") }
        return body()
    }

    func prepareOneCorrection(_ key:String,_ input:XCUIElement,_ value:String) {
        inspectSource(key)
        XCTAssertEqual(visible(ack(key)).value as? String,"0")
        assertSubmitEnabled(false)
        edit(input,value,id:key);acknowledge(key)
        assertSubmitEnabled(true)
        tap("架空検証");tap("表示サイズを変更")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(ack(key)).value as? String,"1")
        tap("架空検証");tap("同じ原本の状態を再確認")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(ack(key)).value as? String,"1")
    }

    func requireEditorSurvivesBackground(_ key:String,_ input:XCUIElement,_ value:String,processBefore:String)->Bool {
        guard enterBackground() else { return false }
        app.activate()
        print("TAKUPOKE-MANUAL-APP-STATE after-activate=\(app.state.rawValue)")
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10),"App must survive background; no relaunch or draft reset")
        print("TAKUPOKE-MANUAL-APP-STATE foreground=\(app.state.rawValue)")
        print("TAKUPOKE-MANUAL-PROCESS expected=\(processBefore);observed=\(app.staticTexts["manual-process-launch"].firstMatch.label)")
        XCTAssertEqual(app.staticTexts["manual-process-launch"].firstMatch.label,processBefore,"Background must preserve the original process; relaunch is not survival")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(ack(key)).value as? String,"1")
        edit(input,value+"改",id:key);XCTAssertEqual(visible(ack(key)).value as? String,"0")
        assertSubmitEnabled(false)
        XCTAssertTrue(app.images.matching(NSPredicate(format:"identifier BEGINSWITH 'manual-crop-'")).firstMatch.exists)
        return true
    }

    func requireReviewSurvivesBackground(_ value:String,processBefore:String)->Bool {
        requireReview([value+"改"],comparable:false)
        guard enterBackground() else { return false }
        app.activate()
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10))
        XCTAssertEqual(app.staticTexts["manual-process-launch"].firstMatch.label,processBefore)
        requireReview([value+"改"],comparable:false)
        print("TAKUPOKE-MANUAL-REVIEW-BACKGROUND same-process;review-retained;preview=false")
        return true
    }

    func reeditAndReviewCorrection(_ key:String,_ input:XCUIElement,_ value:String) {
        // Reopening the editor retains literal input; a fresh edit clears ACK
        // and cannot reuse the previously validated correction review.
        tap("入力を見直す")
        XCTAssertEqual(visible(input).value as? String,value+"改")
        edit(input,value+"再確認",id:key);XCTAssertEqual(visible(ack(key)).value as? String,"0")
        assertSubmitEnabled(false);acknowledge(key);visible(submit).tap()
        requireReview([value+"再確認"],comparable:false)
        inspectSource(key)
    }

    func adoptAndRequirePersistedCorrection() {
        tap("訂正と変更を確認して資料全体へ");requirePreview()
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
}
