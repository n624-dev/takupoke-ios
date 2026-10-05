import XCTest
import UIKit

// QA geometry only: no value assignment or acknowledgement synthesis.
private func manualAcknowledgementPoint(outer:CGRect,inner:CGRect,viewport:CGRect)->CGPoint? {
    guard [outer,inner,viewport].allSatisfy({
        !$0.isNull && !$0.isInfinite && $0.width>0 && $0.height>0
            && [$0.minX,$0.minY,$0.maxX,$0.maxY].allSatisfy(\.isFinite)
    }), [outer,viewport].allSatisfy({
        inner.minX >= $0.minX && inner.maxX <= $0.maxX
            && inner.minY >= $0.minY && inner.maxY <= $0.maxY
    }) else { return nil }
    return CGPoint(x:inner.midX,y:inner.midY)
}

final class ManualAssistanceChecks:XCTestCase {
    private var app:XCUIApplication!
    override func setUp() { continueAfterFailure=false;app=XCUIApplication() }
    private func launch(_ flags:[String]=[]) {
        app.launchArguments=["--reset-fixture","--manual-ui","--manual-integral-rails","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]+flags
        app.launch();XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout:45),app.debugDescription)
        app.tabBars.buttons["設定"].tap();tap("時間割ファイル");tap("通常時間割の詳細を見る");tap("端末内で復旧する");tap("端末内で復旧を開始")
    }
    private func visible(_ e:XCUIElement)->XCUIElement {
        let recoveryList=app.collectionViews["manual-recovery-list"]
        let list=recoveryList.exists ? recoveryList : app.collectionViews.firstMatch
        var upward=true,reversed=false,unchanged=0,previousAnchor=""
        for attempt in 0..<16 {
            if e.exists && e.isHittable { return e }
            let navigation=recoveryList.exists ? app.navigationBars["時間割の復旧"] : app.navigationBars.firstMatch
            let top=max(list.frame.minY,navigation.frame.maxY)+12
            let bottom=min(list.frame.maxY,app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY-45 : list.frame.maxY)-12
            let viewport=CGRect(x:list.frame.minX+100,y:top,width:1,height:max(0,bottom-top))
            if e.exists { upward=e.frame.minY>=top }
            // Pick a real passive Cell on each attempt, including preview lesson/header rows.
            // Never start a drag on an editor, button, switch, keyboard or outer List gutter.
            let cells=list.cells.allElementsBoundByIndex.filter {
                let area=$0.frame.intersection(viewport)
                return !area.isNull && area.height>36
            }
            let passive=cells.filter {
                $0.buttons.count==0 && $0.switches.count==0 && $0.textFields.count==0 && $0.textViews.count==0
                    && $0.pickers.count==0 && $0.pickerWheels.count==0
                    && ($0.images.count>0 || $0.staticTexts.count>0)
            }
            guard let cell=passive.max(by:{
                let a=$0.frame.intersection(viewport),b=$1.frame.intersection(viewport)
                return upward ? a.maxY<b.maxY:a.minY>b.minY
            }) else {
                print("TAKUPOKE-MANUAL-SCROLL no-passive-cell;list=\(list.frame);viewport=\(viewport)")
                break
            }
            let safe=cell.frame.intersection(viewport)
            let anchor="\(cell.label);\(cell.staticTexts.firstMatch.exists ? cell.staticTexts.firstMatch.label:"");\(cell.images.firstMatch.exists ? cell.images.firstMatch.identifier:"");\(cell.frame)"
            unchanged=anchor==previousAnchor ? unchanged+1:0
            previousAnchor=anchor
            if unchanged>=2 {
                guard !reversed else { print("TAKUPOKE-MANUAL-SCROLL no-progress-after-reverse;\(anchor)");break }
                upward.toggle();reversed=true;unchanged=0
            }
            print("TAKUPOKE-MANUAL-SCROLL attempt=\(attempt);up=\(upward);anchor=\(anchor);target=\(e.exists ? String(describing:e.frame):"virtualized")")
            let base=list.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0))
            // Touch begins inside the passive Cell; the pan can continue across the List.
            // Viewport-sized drags retain the16-attempt cap for the complete40-slot preview.
            let start=base.withOffset(CGVector(dx:100,dy:(upward ? safe.maxY-12:safe.minY+12)-list.frame.minY))
            let end=base.withOffset(CGVector(dx:100,dy:(upward ? viewport.minY+12:viewport.maxY-12)-list.frame.minY))
            start.press(forDuration:0.1,thenDragTo:end)
        }
        XCTAssertTrue(e.exists && e.isHittable,app.debugDescription);return e
    }
    private func tap(_ title:String) { visible(app.buttons[title].firstMatch).tap() }
    private func emitDiagnostic() {
        let diagnostic=app.staticTexts["manual-qa-diagnostic"].firstMatch
        print("TAKUPOKE-MANUAL-QA "+(diagnostic.exists ? diagnostic.label:"diagnostic-missing"))
    }
    private func emitEvents() {
        let events=app.staticTexts["manual-binding-events"].firstMatch
        print("TAKUPOKE-MANUAL-BINDINGS "+(events.exists ? events.label:"absent"))
    }
    private func requirePreview() {
        let state=app.staticTexts["manual-coordinator-state"].firstMatch
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label CONTAINS %@","preview=true"),object:state)
        let outcome=XCTWaiter.wait(for:[ready],timeout:20)
        print("TAKUPOKE-MANUAL-COORDINATOR " + (state.exists ? state.label : "absent"))
        emitDiagnostic()
        emitEvents()
        if outcome != .completed { print("TAKUPOKE-MANUAL-PREVIEW-FAIL " + app.debugDescription) }
        XCTAssertEqual(outcome,.completed,app.debugDescription)
        let header=visible(app.staticTexts["manual-preview-header"].firstMatch)
        XCTAssertEqual(header.label,"採用する資料全体",app.debugDescription)
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
    private func acknowledge(_ id:String) {
        let row=visible(ack(id))
        let control=row.switches.firstMatch
        XCTAssertTrue(control.exists,app.debugDescription)
        let actual=visible(control)
        let list=app.collectionViews["manual-recovery-list"]
        let navigation=app.navigationBars["時間割の復旧"]
        let keyboard=app.keyboards.firstMatch
        let appFrame=app.frame
        let top=max(list.frame.minY,navigation.frame.maxY)+12
        let bottom=min(list.frame.maxY,keyboard.exists ? keyboard.frame.minY-45:list.frame.maxY)-12
        let viewport=CGRect(x:list.frame.minX,y:top,width:list.frame.width,height:max(0,bottom-top))
        let outerFrame=row.frame,innerFrame=actual.frame
        guard let point=manualAcknowledgementPoint(outer:outerFrame,inner:innerFrame,viewport:viewport) else {
            print("TAKUPOKE-MANUAL-ACK invalid-hit-region;outer=\(outerFrame);inner=\(innerFrame);viewport=\(viewport)")
            XCTFail(app.debugDescription);return
        }
        let diagnostic=app.staticTexts["manual-qa-diagnostic"].firstMatch
        print("TAKUPOKE-MANUAL-ACK before;id=\(id);outer=\(outerFrame);inner=\(innerFrame);hittable=\(actual.isHittable);point=\(point);app=\(appFrame);viewport=\(viewport);keyboard=\(keyboard.exists ? String(describing:keyboard.frame):"absent");diagnostic=\(diagnostic.exists ? String(describing:diagnostic.frame):"absent");value=\(row.value as? String ?? "unknown")")
        XCTAssertTrue(actual.isHittable,app.debugDescription)
        // Exactly one physical tap at the recorded center of the actual inner widget.
        app.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0))
            .withOffset(CGVector(dx:point.x-appFrame.minX,dy:point.y-appFrame.minY)).tap()
        print("TAKUPOKE-MANUAL-ACK after;outer=\(row.frame);inner=\(actual.frame);value=\(row.value as? String ?? "unknown")")
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","1"),object:row)
        let outcome=XCTWaiter.wait(for:[changed],timeout:5)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        emitEvents()
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    private func assertSubmitEnabled(_ expected:Bool) {
        let button=visible(submit)
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == %@",NSNumber(value:expected)),object:button)
        let outcome=XCTWaiter.wait(for:[changed],timeout:5)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    private func edit(_ e:XCUIElement,_ value:String) {
        visible(e).tap()
        editStage("after-focus",e)
        // Focusing can move a recycled List row when the keyboard changes.
        // Reacquire its real hit region before the existing selection gesture.
        let focused=visible(e)
        editStage("before-selection",focused)
        focused.press(forDuration:1.1)
        editStage("after-selection",e)
        if app.menuItems["すべてを選択"].waitForExistence(timeout:2) { app.menuItems["すべてを選択"].tap() }
        else if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        else { e.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:(e.value as? String)?.count ?? 0)) }
        e.typeText(value)
    }
    private func editStage(_ stage:String,_ e:XCUIElement) {
        let keyboard=app.keyboards.firstMatch
        let exists=e.exists
        print("TAKUPOKE-MANUAL-EDIT stage=\(stage);id=\(exists ? e.identifier:"absent");exists=\(exists);hittable=\(exists && e.isHittable);frame=\(exists ? String(describing:e.frame):"absent");focused=\(exists && e.debugDescription.contains("Keyboard Focused"));keyboard=\(keyboard.exists ? String(describing:keyboard.frame):"absent")")
    }
    func testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground() {
        launch();XCTAssertTrue(fieldsExist(),app.debugDescription);XCTAssertEqual(fieldIDs.count,1)
        let key=fieldIDs[0];let input=input(key)
        XCTAssertEqual(visible(ack(key)).value as? String,"0")
        assertSubmitEnabled(false)
        let value="架空手確認科目";edit(input,value);acknowledge(key)
        assertSubmitEnabled(true)
        tap("架空検証");tap("表示サイズを変更")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(ack(key)).value as? String,"1")
        tap("架空検証");tap("同じ原本の状態を再確認")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(ack(key)).value as? String,"1")
        let processBefore=app.staticTexts["manual-process-launch"].firstMatch.label
        XCTAssertFalse(processBefore.isEmpty)
        print("TAKUPOKE-MANUAL-APP-STATE before-home=\(app.state.rawValue)")
        XCUIDevice.shared.press(.home)
        print("TAKUPOKE-MANUAL-APP-STATE after-home=\(app.state.rawValue)")
        XCTAssertNotEqual(app.state,.notRunning,"Background must not terminate the app; no relaunch")
        guard app.state != .notRunning else { return }
        app.activate()
        print("TAKUPOKE-MANUAL-APP-STATE after-activate=\(app.state.rawValue)")
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10),"App must survive background; no relaunch or draft reset")
        print("TAKUPOKE-MANUAL-APP-STATE foreground=\(app.state.rawValue)")
        print("TAKUPOKE-MANUAL-PROCESS expected=\(processBefore);observed=\(app.staticTexts["manual-process-launch"].firstMatch.label)")
        XCTAssertEqual(app.staticTexts["manual-process-launch"].firstMatch.label,processBefore,"Background must preserve the original process; relaunch is not survival")
        XCTAssertEqual(visible(input).value as? String,value);XCTAssertEqual(visible(ack(key)).value as? String,"1")
        edit(input,value+"改");XCTAssertEqual(visible(ack(key)).value as? String,"0")
        assertSubmitEnabled(false)
        XCTAssertTrue(app.images.matching(NSPredicate(format:"identifier BEGINSWITH 'manual-crop-'")).firstMatch.exists)
        acknowledge(key);visible(submit).tap()
        requirePreview()
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
        let key=fieldIDs[0];edit(input(key),"架空変更前確認");acknowledge(key)
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
            let ack=ack(ids[i]);XCTAssertEqual(visible(ack).value as? String,"0");acknowledge(ids[i])
            assertSubmitEnabled(i==2)
        }
        visible(submit).tap();requirePreview()
        XCTAssertTrue(app.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        tap("閉じる");XCTAssertFalse(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("adopted="))
        app.terminate();launch(["--manual-four"])
        XCTAssertTrue(app.staticTexts["架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        emitDiagnostic()
        XCTAssertFalse(submit.exists);XCTAssertFalse(app.staticTexts["manual-field-ids"].exists)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
    }
}
