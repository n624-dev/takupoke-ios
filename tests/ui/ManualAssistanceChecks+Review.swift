import XCTest
import UIKit

extension ManualAssistanceChecks {
    var recoveryList:XCUIElement { app.collectionViews["manual-recovery-list"] }
    var observation:XCUIElement { app.otherElements["manual-observation"] }
    var rootObservation:XCUIElement { app.otherElements["manual-root-observation"] }

    func uniqueLabel(_ id:String,in owner:XCUIElement)->String? {
        let matches=owner.staticTexts.matching(identifier:id).allElementsBoundByAccessibilityElement
        guard matches.count==1 else {
            XCTFail("Expected one observation for \(id), got \(matches.count)");return nil
        }
        return matches[0].label
    }
    private func diagnosticLabel(_ id:String)->String {
        let matches=observation.staticTexts.matching(identifier:id).allElementsBoundByAccessibilityElement
        return matches.count==1 ? matches[0].label : "matches=\(matches.count)"
    }
    func emitDiagnostic() {
        print("TAKUPOKE-MANUAL-QA "+diagnosticLabel("manual-qa-diagnostic"))
    }
    func emitEvents() {
        print("TAKUPOKE-MANUAL-BINDINGS "+diagnosticLabel("manual-binding-events"))
    }
    func requireLastGood(in owner:XCUIElement) {
        XCTAssertEqual(uniqueLabel("manual-persisted-proof",in:owner),"lastgood-preserved")
    }
    func openReviewPreview() {
        tap("訂正と変更を確認して資料全体へ",knownID:"manual-review-submit")
    }
    func requireReview(_ expected:[String],comparable:Bool) {
        var observedState="",ambiguousState=false
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=self.app.otherElements["manual-observation"].staticTexts.matching(identifier:"manual-coordinator-state")
                .allElementsBoundByAccessibilityElement
            if current.count>1 { ambiguousState=true;return true }
            guard current.count==1 else { return false }
            let label=current[0].label
            observedState=label
            return label.contains("review=true") && label.contains("preview=false")
        },object:app)
        let outcome=XCTWaiter.wait(for:[ready],timeout:20)
        XCTAssertFalse(ambiguousState,"The review state must remain unique")
        XCTAssertEqual(outcome,.completed,app.debugDescription)
        print("TAKUPOKE-MANUAL-REVIEW " + observedState)
        XCTAssertFalse(recoveryList.buttons["この資料全体の結果を使用"].exists)
        requireLastGood(in:observation)
        // This is the first review section, above the retained editor scroll
        // position. A virtualized header has no usable frame; start toward the
        // top until actual offscreen geometry can determine a direction.
        let list=app.collectionViews["manual-recovery-list"]
        _=visible(list.staticTexts["manual-review-header"].firstMatch,towardTop:true,knownID:"manual-review-header")
        for value in expected {
            let reviewed=list.staticTexts.matching(NSPredicate(
                format:"identifier BEGINSWITH %@ AND label == %@","manual-reviewed-",value))
            _=visible(reviewed.firstMatch,alternatives:{
                $0.identifier.hasPrefix("manual-reviewed-") && $0.label==value
            })
        }
        if comparable {
            XCTAssertEqual(visible(recoveryList.staticTexts["manual-comparison-available"].firstMatch,knownID:"manual-comparison-available").label,"本文の変更: 1箇所")
            XCTAssertTrue(visible(recoveryList.staticTexts["manual-change-before"].firstMatch,knownID:"manual-change-before").label.contains("架空科"))
            XCTAssertTrue(visible(recoveryList.staticTexts["manual-change-after"].firstMatch,knownID:"manual-change-after").label.contains(expected[0]))
        } else { _=visible(recoveryList.staticTexts["manual-comparison-unavailable"].firstMatch,knownID:"manual-comparison-unavailable") }
    }
    func inspectSource(_ id:String) {
        let zoomID="manual-zoom-"+id
        visible(recoveryList.buttons[zoomID],knownID:zoomID,buttonLabel:"対象セルを拡大して確認").tap()
        // Resolve the open sheet's scroll view in the same snapshot as its image
        // and highlight, including after the slider changes scale.
        var ambiguous = false
        var observation = "snapshot unavailable"
        func observedHighlight() -> CGRect? {
            guard !ambiguous else { return nil }
            observation = "snapshot unavailable"
            guard let root = try? app.snapshot(), let nodes = snapshotNodes(in: root) else { return nil }
            let scrolls = nodes.filter { $0.elementType == .scrollView && $0.identifier == "manual-source-scroll" }
            observation = "scrolls=\(scrolls.count)"
            if scrolls.count > 1 { ambiguous = true; return nil }
            guard let scroll = scrolls.first, let source = snapshotNodes(in: scroll) else { return nil }
            let images = source.filter { $0.identifier == "manual-source-context" }
            observation += ";images=\(images.count)"
            if images.count > 1 { ambiguous = true; return nil }
            guard let image = images.first, let descendants = snapshotNodes(in: image) else { return nil }
            let matches = descendants.filter { $0.identifier == "manual-source-highlight" }
            observation += ";highlights=\(matches.count)"
            if matches.count > 1 { ambiguous = true; return nil }
            guard let box = matches.first?.frame else { return nil }
            let bounds = image.frame
            observation += ";image=\(bounds);highlight=\(box)"
            guard ManualScrollNavigation.usable(bounds), ManualScrollNavigation.usable(box), bounds.contains(box) else { return nil }
            return box
        }
        var initial: CGRect?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            initial = observedHighlight()
            return ambiguous || initial != nil
        }, object: app)
        let result=XCTWaiter.wait(for:[ready],timeout:10)
        guard !ambiguous,result == .completed,let highlightBefore=initial else {
            XCTFail("The source must have one real image containing its unique highlight: " + observation);return
        }
        let controls=app.otherElements["manual-source-controls"]
        guard let scale=uniqueLabel("manual-source-scale",in:controls) else { return }
        let sliders=controls.sliders.matching(identifier:"manual-source-zoom").allElementsBoundByAccessibilityElement
        guard sliders.count==1 else { XCTFail("Expected one source zoom slider");return }
        let slider=sliders[0],sliderFrame=slider.frame
        guard ManualScrollNavigation.usable(sliderFrame),app.frame.contains(sliderFrame),
              slider.isEnabled,slider.isHittable else { XCTFail("The source zoom slider must be operable");return }
        slider.adjust(toNormalizedSliderPosition:0.67)
        guard let zoomedScale=uniqueLabel("manual-source-scale",in:controls) else { return }
        XCTAssertNotEqual(zoomedScale,scale)
        guard let box = observedHighlight(), !ambiguous else {
            XCTFail("The zoomed source must have one real image containing its unique highlight: " + observation); return
        }
        XCTAssertGreaterThan(box.width,highlightBefore.width)
        controls.buttons["等倍"].tap();XCTAssertEqual(uniqueLabel("manual-source-scale",in:controls),scale)
        app.navigationBars["原画像の確認"].buttons["確認を終える"].tap()
    }
    func requirePreview() {
        var ambiguous=false
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=self.observation.staticTexts.matching(identifier:"manual-coordinator-state")
                .allElementsBoundByAccessibilityElement
            if current.count>1 { ambiguous=true;return true }
            return current.count==1 && current[0].label.contains("preview=true")
        },object:app)
        let outcome=XCTWaiter.wait(for:[ready],timeout:20)
        print("TAKUPOKE-MANUAL-COORDINATOR wait-outcome=\(outcome.rawValue)")
        if ambiguous || outcome != .completed { emitDiagnostic();emitEvents() }
        XCTAssertFalse(ambiguous,"Preview must have a unique coordinator state")
        XCTAssertEqual(outcome,.completed,app.debugDescription)
        let header=visible(app.collectionViews["manual-recovery-list"].staticTexts["manual-preview-header"].firstMatch,towardTop:true,knownID:"manual-preview-header")
        XCTAssertEqual(header.label,"採用する資料全体",app.debugDescription)
    }
    func fieldIDs(expectedCount:Int)->[String]? {
        var observed:[String]?,ambiguous=false
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let matches=self.observation.staticTexts.matching(identifier:"manual-field-ids").allElementsBoundByAccessibilityElement
            if matches.count>1 { ambiguous=true;return true }
            guard let current=matches.first else { return false }
            let ids=current.label.split(separator:"|",omittingEmptySubsequences:false).map(String.init)
            observed=ids
            return true
        },object:app)
        let result=XCTWaiter.wait(for:[ready],timeout:15)
        guard !ambiguous,result == .completed,let ids=observed,ids.count==expectedCount,
              !ids.contains(""),Set(ids).count==ids.count else {
            XCTFail("Expected \(expectedCount) distinct field IDs; observed \(String(describing:observed)), ambiguous=\(ambiguous)")
            emitDiagnostic();return nil
        }
        return ids
    }
}
