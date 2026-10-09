import XCTest
import UIKit

extension ManualAssistanceChecks {
    func emitDiagnostic() {
        let diagnostic=app.staticTexts["manual-qa-diagnostic"].firstMatch
        print("TAKUPOKE-MANUAL-QA "+(diagnostic.exists ? diagnostic.label:"diagnostic-missing"))
    }
    func emitEvents() {
        let events=app.staticTexts["manual-binding-events"].firstMatch
        print("TAKUPOKE-MANUAL-BINDINGS "+(events.exists ? events.label:"absent"))
    }
    func requireReview(_ expected:[String],comparable:Bool) {
        let state=app.staticTexts["manual-coordinator-state"].firstMatch
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@ AND label CONTAINS %@","review=true","preview=false"),object:state)
        XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed,app.debugDescription)
        print("TAKUPOKE-MANUAL-REVIEW " + state.label)
        XCTAssertFalse(app.buttons["この資料全体の結果を使用"].exists)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        // This is the first review section, above the retained editor scroll
        // position. A virtualized header has no usable frame; start toward the
        // top until actual offscreen geometry can determine a direction.
        let list=app.collectionViews["manual-recovery-list"]
        _=visible(list.staticTexts["manual-review-header"].firstMatch,towardTop:true)
        for value in expected { _=visible(app.staticTexts[value].firstMatch) }
        if comparable {
            XCTAssertEqual(visible(app.staticTexts["manual-comparison-available"].firstMatch).label,"本文の変更: 1箇所")
            XCTAssertTrue(visible(app.staticTexts["manual-change-before"].firstMatch).label.contains("架空科"))
            XCTAssertTrue(visible(app.staticTexts["manual-change-after"].firstMatch).label.contains(expected[0]))
        } else { _=visible(app.staticTexts["manual-comparison-unavailable"].firstMatch) }
    }
    func inspectSource(_ id:String) {
        visible(app.buttons["manual-zoom-"+id]).tap()
        let image=app.descendants(matching:.any)["manual-source-context"].firstMatch
        XCTAssertTrue(image.waitForExistence(timeout:10),app.debugDescription)
        XCTAssertGreaterThan(image.frame.width,0);XCTAssertGreaterThan(image.frame.height,0)
        let highlight=app.descendants(matching:.any)["manual-source-highlight"].firstMatch
        XCTAssertTrue(highlight.exists,app.debugDescription)
        XCTAssertGreaterThan(highlight.frame.width,0);XCTAssertGreaterThan(highlight.frame.height,0)
        XCTAssertTrue(image.frame.contains(highlight.frame),app.debugDescription)
        let highlightBefore=highlight.frame
        let scale=app.staticTexts["manual-source-scale"].firstMatch
        let initial=scale.label
        let slider=app.sliders["manual-source-zoom"]
        XCTAssertTrue(slider.isHittable,app.debugDescription)
        slider.adjust(toNormalizedSliderPosition:0.67)
        XCTAssertNotEqual(scale.label,initial,app.debugDescription)
        XCTAssertGreaterThan(highlight.frame.width,highlightBefore.width)
        app.buttons["等倍"].tap();XCTAssertEqual(scale.label,initial)
        app.buttons["確認を終える"].tap()
    }
    func requirePreview() {
        let state=app.staticTexts["manual-coordinator-state"].firstMatch
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","preview=true"),object:state)
        let outcome=XCTWaiter.wait(for:[ready],timeout:20)
        print("TAKUPOKE-MANUAL-COORDINATOR " + (state.exists ? state.label : "absent"))
        emitDiagnostic()
        emitEvents()
        if outcome != .completed { print("TAKUPOKE-MANUAL-PREVIEW-FAIL " + app.debugDescription) }
        XCTAssertEqual(outcome,.completed,app.debugDescription)
        let header=visible(app.collectionViews["manual-recovery-list"].staticTexts["manual-preview-header"].firstMatch,towardTop:true)
        XCTAssertEqual(header.label,"採用する資料全体",app.debugDescription)
    }
    func fieldsExist()->Bool {
        let ready=app.staticTexts["manual-field-ids"].waitForExistence(timeout:15)
        emitDiagnostic()
        return ready
    }
}
