import XCTest
import UIKit

extension ManualAssistanceChecks {
    var submit:XCUIElement { app.buttons["manual-submit"] }
    var fieldIDs:[String] { app.staticTexts["manual-field-ids"].firstMatch.label.split(separator:"|").map(String.init) }
    func input(_ id:String)->XCUIElement { app.descendants(matching:.any)["manual-value-"+id].firstMatch }
    func ack(_ id:String)->XCUIElement { app.switches["manual-ack-"+id].firstMatch }
    func acknowledge(_ id:String) {
        let row=visible(ack(id),knownID:"manual-ack-"+id)
        let controls=row.switches.allElementsBoundByAccessibilityElement
        guard controls.count==1 else {
            XCTFail("Acknowledgement must have one current native control");return
        }
        let actual=controls[0]
        let list=app.collectionViews["manual-recovery-list"]
        let navigation=app.navigationBars["時間割の復旧"]
        let keyboardFrame=observedKeyboardFrame()
        let appFrame=app.frame
        let top=max(list.frame.minY,navigation.frame.maxY)+12
        let bottom=min(list.frame.maxY,keyboardFrame.map { $0.minY-45 } ?? list.frame.maxY)-12
        let viewport=CGRect(x:list.frame.minX,y:top,width:list.frame.width,height:max(0,bottom-top))
        let outerFrame=row.frame,innerFrame=actual.frame
        guard let point=manualAcknowledgementPoint(outer:outerFrame,inner:innerFrame,viewport:viewport) else {
            print("TAKUPOKE-MANUAL-ACK invalid-hit-region;outer=\(outerFrame);inner=\(innerFrame);viewport=\(viewport)")
            XCTFail(app.debugDescription);return
        }
        let enabled=actual.isEnabled,hittable=actual.isHittable
        let priorValue=row.value as? String
        print("TAKUPOKE-MANUAL-ACK before;id=\(id);outer=\(outerFrame);inner=\(innerFrame);enabled=\(enabled);hittable=\(hittable);point=\(point);app=\(appFrame);viewport=\(viewport);keyboard=\(keyboardFrame.map { String(describing:$0) } ?? "absent");value=\(priorValue ?? "unknown")")
        guard enabled,hittable,priorValue == "0" else {
            XCTFail("The unique native acknowledgement must be operable and unchecked");return
        }
        // Bind the native element by accessibility identity. Index-bound child
        // queries re-traversed recycled ancestors during event synthesis (N94).
        // U71: one brief contact at the same verified center, relative to the
        // actual inner widget rather than a saved application-screen position.
        actual.coordinate(withNormalizedOffset:CGVector(
            dx:(point.x-innerFrame.minX)/innerFrame.width,
            dy:(point.y-innerFrame.minY)/innerFrame.height)).press(forDuration:0.1)
        // Post-tap diagnostics must not add AX queries before the native state check.
        print("TAKUPOKE-MANUAL-ACK after;id=\(id)")
        var ambiguous=false
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=self.app.switches.matching(identifier:"manual-ack-"+id).allElementsBoundByIndex
            if current.count>1 { ambiguous=true;return true }
            return current.count==1 && current[0].value as? String == "1"
        },object:app)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        emitEvents()
        XCTAssertFalse(ambiguous,"Acknowledgement identifier must remain unique")
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    func assertSubmitEnabled(_ expected:Bool) {
        let button=visible(submit,knownID:"manual-submit")
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == %@",NSNumber(value:expected)),object:button)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        print("TAKUPOKE-MANUAL-INPUT submit=\(expected);wait-outcome=\(outcome.rawValue)")
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    func edit(_:XCUIElement,_ value:String,id:String) {
        let clear=app.buttons["manual-clear-"+id].firstMatch
        // Reveal the actual 44px clear control before querying it. A visible
        // editor alone does not prove that its sibling button is materialized
        // or fully inside the viewport; absent firstMatch queries can stall AX.
        let target=visible(clear,knownID:"manual-clear-"+id)
        let clearFrame=target.frame,enabled=target.isEnabled,hittable=target.isHittable
        print("TAKUPOKE-MANUAL-CLEAR-TAP id=\(id);frame=\(clearFrame);enabled=\(enabled);hittable=\(hittable)")
        guard ManualScrollNavigation.usable(clearFrame),enabled,hittable else {
            XCTFail("The revealed native clear Button must remain operable");return
        }
        target.tap()
        let empty=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            let current=self.app.descendants(matching:.any)
                .matching(identifier:"manual-value-"+id).allElementsBoundByIndex
            guard current.count==1,let text=current[0].value as? String else { return false }
            return text.isEmpty || text == "PDFに記載された全文"
        },object:app)
        let cleared=XCTWaiter.wait(for:[empty],timeout:nativeStateTimeout)
        if cleared != .completed {
            let state=app.staticTexts["manual-input-state"].firstMatch
            print("TAKUPOKE-MANUAL-CLEAR id=\(id);state=\(state.exists ? state.label:"absent")")
            emitEvents()
        }
        XCTAssertEqual(cleared,.completed,"Native clear must remove the entire previous input")
        guard cleared == .completed else { return }
        // N52: the clear action can recycle a SwiftUI row. Resolve the current
        // native control once instead of re-evaluating an absent/stale firstMatch.
        let clearedAcknowledgements=app.switches.matching(identifier:"manual-ack-"+id).allElementsBoundByIndex
        guard clearedAcknowledgements.count==1 else {
            XCTFail("Cleared input must have one native acknowledgement control; matches=\(clearedAcknowledgements.count)");return
        }
        XCTAssertEqual(clearedAcknowledgements[0].value as? String,"0","Clearing text must revoke prior acknowledgement")
        // The real clear button focuses its associated native editor. Open
        // the keyboard through that action, after locating the complete44px
        // control, instead of covering it by focusing the text field first.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        let editors=app.descendants(matching:.any)
            .matching(identifier:"manual-value-"+id).allElementsBoundByIndex
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
            let current=buttons.allElementsBoundByIndex
            if current.count>1 { ambiguous=true;return true }
            guard current.count==1 else { return false }
            let done=current[0]
            let navigationFrame=navigation.frame,doneFrame=done.frame
            let enabled=done.isEnabled,hittable=done.isHittable
            guard ManualScrollNavigation.usable(navigationFrame) && ManualScrollNavigation.usable(doneFrame)
                  && navigationFrame.contains(doneFrame) && enabled && hittable else { return false }
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
        let completed=self.app.descendants(matching:.any).matching(identifier:"manual-value-"+id).allElementsBoundByIndex
        guard completed.count==1 else { XCTFail("Completed input must remain unique");return }
        XCTAssertEqual(completed[0].value as? String,value,"The physical edit must replace the full previous input before acknowledgement")
    }
}
