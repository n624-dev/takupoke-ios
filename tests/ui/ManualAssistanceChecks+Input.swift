import XCTest
import UIKit

extension ManualAssistanceChecks {
    var submit:XCUIElement { recoveryList.buttons["manual-submit"] }
    func input(_ id:String)->XCUIElement { recoveryList.descendants(matching:.any)["manual-value-"+id].firstMatch }
    func visibleAcknowledgement(_ id: String) -> ManualButtonObservation? {
        let identifier = "manual-ack-" + id
        var observation: ManualButtonObservation?
        _ = visible(recoveryList.buttons[identifier], knownID: identifier, buttonLabel: "原本と一致することを確認") {
            observation = $0
        }
        return observation
    }
    func acknowledge(_ id:String) {
        let identifier = "manual-ack-" + id
        let appFrame=app.frame
        guard let observed = visibleAcknowledgement(id), ManualScrollNavigation.usable(appFrame),
              appFrame.contains(observed.frame), !observed.isSelected, app.state == .runningForeground else {
            XCTFail("The unique native acknowledgement must be contained, operable and unchecked: " + id);return
        }
        let frame = observed.frame
        print("TAKUPOKE-MANUAL-ACK before;id=\(id);frame=\(frame);enabled=true;hittable=true;selected=false;app=\(appFrame);viewport=\(observed.viewport)")
        let center = CGPoint(x: frame.midX, y: frame.midY)
        do {
            try NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)],
                                        named: "Manual confirmation button")
        } catch {
            XCTFail("Native confirmation button contact failed: \(error)");return
        }
        // Post-gesture diagnostics must not add AX queries before the native state check.
        print("TAKUPOKE-MANUAL-ACK after;id=\(id)")
        var ambiguous=false
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=self.recoveryList.buttons.matching(identifier:identifier).allElementsBoundByAccessibilityElement
            if current.count>1 { ambiguous=true;return true }
            return current.count==1 && current[0].isSelected
        },object:nil)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        print("TAKUPOKE-MANUAL-INPUT id=\(id);wait-outcome=\(outcome.rawValue);ambiguous=\(ambiguous)")
        if ambiguous || outcome != .completed {
            logInputState(id)
            emitEvents()
        }
        XCTAssertFalse(ambiguous,"Acknowledgement identifier must remain unique")
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    private func logInputState(_ id:String) {
        let states=app.otherElements["manual-observation"].staticTexts.matching(identifier:"manual-input-state")
            .allElementsBoundByAccessibilityElement
        let detail=states.count == 1 ? states[0].label : "matches=\(states.count)"
        print("TAKUPOKE-MANUAL-INPUT id=\(id);state=\(detail)")
    }
    func tapSubmit() {
        visible(submit,knownID:"manual-submit",buttonLabel:"訂正箇所と前回からの変更を確認").tap()
    }
    func assertSubmitEnabled(_ expected:Bool) {
        let button=visible(submit,knownID:"manual-submit")
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == %@",NSNumber(value:expected)),object:button)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        print("TAKUPOKE-MANUAL-INPUT submit=\(expected);wait-outcome=\(outcome.rawValue)")
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    func edit(_:XCUIElement,_ value:String,id:String) {
        let clear=recoveryList.buttons["manual-clear-"+id].firstMatch
        // Reveal the actual 44px clear control before querying it. A visible
        // editor alone does not prove that its sibling button is materialized
        // or fully inside the viewport; absent firstMatch queries can stall AX.
        let target=visible(clear,knownID:"manual-clear-"+id)
        let clearFrame=target.frame
        guard ManualScrollNavigation.usable(clearFrame),target.isEnabled,target.isHittable else {
            XCTFail("The revealed native clear Button must remain operable");return
        }
        print("TAKUPOKE-MANUAL-CLEAR-TAP id=\(id);frame=\(clearFrame)")
        target.tap()
        let empty=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=self.recoveryList.descendants(matching:.any)
                .matching(identifier:"manual-value-"+id).allElementsBoundByIndex
            guard current.count==1,let text=current[0].value as? String else { return false }
            return text.isEmpty || text == "PDFに記載された全文"
        },object:app)
        let cleared=XCTWaiter.wait(for:[empty],timeout:nativeStateTimeout)
        if cleared != .completed {
            logInputState(id)
            emitEvents()
        }
        XCTAssertEqual(cleared,.completed,"Native clear must remove the entire previous input")
        guard cleared == .completed else { return }
        // N52: the clear action can recycle a SwiftUI row. Resolve the current
        // native control once instead of re-evaluating an absent/stale firstMatch.
        let clearedAcknowledgements=recoveryList.buttons.matching(identifier:"manual-ack-"+id).allElementsBoundByAccessibilityElement
        guard clearedAcknowledgements.count==1 else {
            XCTFail("Cleared input must have one native acknowledgement control; matches=\(clearedAcknowledgements.count)");return
        }
        XCTAssertFalse(clearedAcknowledgements[0].isSelected,"Clearing text must revoke prior acknowledgement")
        // The real clear button focuses its associated native editor. Open
        // the keyboard through that action, after locating the complete44px
        // control, instead of covering it by focusing the text field first.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        let editors=recoveryList.descendants(matching:.any)
            .matching(identifier:"manual-value-"+id).allElementsBoundByAccessibilityElement
        guard editors.count==1 else {
            XCTFail("Focused editor must be unique; matches=\(editors.count)");return
        }
        let e=editors[0]
        editStage("after-clear-focus",id:id)
        e.typeText(value)
        // End the native editor before the independent acknowledgement tap.
        // The product commits text and dismisses the keyboard; it never checks
        // acknowledgement on the user's behalf.
        let navigation=app.navigationBars["時間割の復旧"]
        let buttons=navigation.buttons.matching(identifier:"manual-edit-done")
        var readyButton:XCUIElement?,ambiguous=false
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=buttons.allElementsBoundByAccessibilityElement
            if current.count>1 { ambiguous=true;return true }
            guard current.count==1 else { return false }
            let done=current[0]
            let navigationFrame=navigation.frame,doneFrame=done.frame
            guard ManualScrollNavigation.usable(navigationFrame) && ManualScrollNavigation.usable(doneFrame)
                  && navigationFrame.contains(doneFrame) && done.isEnabled && done.isHittable else { return false }
            readyButton=done;return true
        },object:app)
        let result=XCTWaiter.wait(for:[ready],timeout:nativeStateTimeout)
        guard !ambiguous,result == .completed,let done=readyButton else {
            XCTFail("The native completion button must be unique, visible and operable within the original deadline: "+app.debugDescription);return
        }
        done.tap()
        let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.app.keyboards.allElementsBoundByIndex.isEmpty
        },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:nativeStateTimeout),.completed,app.debugDescription)
        let completed=self.recoveryList.descendants(matching:.any).matching(identifier:"manual-value-"+id).allElementsBoundByIndex
        guard completed.count==1 else { XCTFail("Completed input must remain unique");return }
        XCTAssertEqual(completed[0].value as? String,value,"The physical edit must replace the full previous input before acknowledgement")
    }
}
