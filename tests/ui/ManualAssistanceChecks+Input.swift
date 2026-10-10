import XCTest
import UIKit

extension ManualAssistanceChecks {
    var submit:XCUIElement { app.buttons["manual-submit"] }
    var fieldIDs:[String] { app.staticTexts["manual-field-ids"].firstMatch.label.split(separator:"|").map(String.init) }
    func input(_ id:String)->XCUIElement { app.descendants(matching:.any)["manual-value-"+id].firstMatch }
    func ack(_ id:String)->XCUIElement { app.switches["manual-ack-"+id].firstMatch }
    func acknowledge(_ id:String) {
        let row=visible(ack(id))
        XCTAssertEqual(row.switches.count,1,"Acknowledgement must have one native control")
        let control=row.switches.firstMatch
        XCTAssertTrue(control.exists,app.debugDescription)
        let actual=visible(control)
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
        let diagnostic=app.staticTexts["manual-qa-diagnostic"].firstMatch
        print("TAKUPOKE-MANUAL-ACK before;id=\(id);outer=\(outerFrame);inner=\(innerFrame);hittable=\(actual.isHittable);point=\(point);app=\(appFrame);viewport=\(viewport);keyboard=\(keyboardFrame.map { String(describing:$0) } ?? "absent");diagnostic=\(diagnostic.exists ? String(describing:diagnostic.frame):"absent");value=\(row.value as? String ?? "unknown")")
        XCTAssertTrue(actual.isHittable,app.debugDescription)
        // Exactly one physical tap at the recorded center of the actual inner widget.
        app.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0))
            .withOffset(CGVector(dx:point.x-appFrame.minX,dy:point.y-appFrame.minY)).tap()
        print("TAKUPOKE-MANUAL-ACK after;outer=\(row.frame);inner=\(actual.frame);value=\(row.value as? String ?? "unknown")")
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","1"),object:row)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        emitEvents()
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    func assertSubmitEnabled(_ expected:Bool) {
        let button=visible(submit)
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == %@",NSNumber(value:expected)),object:button)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    func edit(_:XCUIElement,_ value:String,id:String) {
        let clear=app.buttons["manual-clear-"+id].firstMatch
        // Reveal the actual 44px clear control before querying it. A visible
        // editor alone does not prove that its sibling button is materialized
        // or fully inside the viewport; absent firstMatch queries can stall AX.
        let target=visible(clear,knownID:"manual-clear-"+id)
        XCTAssertTrue(target.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        let e=input(id) // Resolve the current editor after its row is visible.
        print("TAKUPOKE-MANUAL-CLEAR-TAP id=\(id);frame=\(target.frame);enabled=\(target.isEnabled);hittable=\(target.isHittable)")
        XCTAssertTrue(target.isEnabled)
        target.tap()
        let empty=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@ OR value == %@","","PDFに記載された全文"),object:e)
        let cleared=XCTWaiter.wait(for:[empty],timeout:nativeStateTimeout)
        if cleared != .completed {
            let state=app.staticTexts["manual-input-state"].firstMatch
            print("TAKUPOKE-MANUAL-CLEAR id=\(id);value=\(String(describing:e.value));state=\(state.exists ? state.label:"absent")")
            emitEvents()
        }
        XCTAssertEqual(cleared,.completed,"Native clear must remove the entire previous input")
        XCTAssertEqual(ack(id).value as? String,"0","Clearing text must revoke prior acknowledgement")
        // The real clear button focuses its associated native editor. Open
        // the keyboard through that action, after locating the complete44px
        // control, instead of covering it by focusing the text field first.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        editStage("after-clear-focus",e)
        e.typeText(value)
        // End the native editor before the independent acknowledgement tap.
        // The product commits text and dismisses the keyboard; it never checks
        // acknowledgement on the user's behalf.
        let done=app.buttons["manual-edit-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        XCTAssertTrue(done.isHittable,app.debugDescription)
        done.tap()
        let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.app.keyboards.allElementsBoundByIndex.isEmpty
        },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:nativeStateTimeout),.completed,app.debugDescription)
        XCTAssertEqual(e.value as? String,value,"The physical edit must replace the full previous input before acknowledgement")
    }
}
