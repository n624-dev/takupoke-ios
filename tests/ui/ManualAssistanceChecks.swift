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

// BEGIN PURE MANUAL SCROLL NAVIGATION
// Geometry controls only. A recycled editor's existence does not locate its row.
private struct ManualScrollNavigation {
    private(set) var upward=true
    private(set) var reversed=false
    private var unchanged=0
    private var previousAnchor=""

    init(initiallyUpward:Bool=true) { upward=initiallyUpward }

    static func usable(_ frame:CGRect)->Bool {
        !frame.isNull && !frame.isInfinite && frame.width>0 && frame.height>0
            && [frame.minX,frame.minY,frame.maxX,frame.maxY].allSatisfy(\.isFinite)
    }
    private static func direction(_ frame:CGRect?,viewport:CGRect)->Bool? {
        guard let frame,usable(frame),usable(viewport),
              frame.maxX>viewport.minX,frame.minX<viewport.maxX else { return nil }
        if frame.maxY<=viewport.minY { return false } // Drag down to reveal above.
        if frame.minY>=viewport.maxY { return true }  // Drag up to reveal below.
        // A small control may straddle navigation/keyboard occlusion. A large
        // owner spanning both edges cannot establish a direction on its own.
        if frame.height<=viewport.height {
            if frame.minY<viewport.minY { return false }
            if frame.maxY>viewport.maxY { return true }
        }
        return nil
    }
    mutating func locate(target:CGRect?,owner:CGRect?,viewport:CGRect) {
        if let direction=Self.direction(owner,viewport:viewport)
            ?? Self.direction(target,viewport:viewport) { upward=direction }
        // Unknown/zero/infinite/in-viewport geometry keeps the last direction,
        // including the one bounded no-progress reversal.
    }
    mutating func observe(anchor:String)->Bool {
        unchanged=anchor==previousAnchor ? unchanged+1:0
        previousAnchor=anchor
        if unchanged>=2 {
            guard !reversed else { return false }
            upward.toggle();reversed=true;unchanged=0
        }
        return true
    }
}
// END PURE MANUAL SCROLL NAVIGATION

final class ManualAssistanceChecks:XCTestCase {
    private var app:XCUIApplication!
    // AX snapshots on a loaded simulator can take longer than five seconds.
    // Keep every native state assertion, allowing bounded time to observe it.
    private let nativeStateTimeout:TimeInterval=45
    override func setUp() { continueAfterFailure=false;app=XCUIApplication() }
    private func launch(_ flags:[String]=[]) {
        app.launchArguments=["--reset-fixture","--manual-ui","--manual-integral-rails","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]+flags
        app.launch();XCTAssertTrue(app.staticTexts["fixture-ready"].waitForExistence(timeout:45),app.debugDescription)
        app.tabBars.buttons["設定"].tap();tap("時間割ファイル");tap("通常時間割の詳細を見る");tap("端末内で復旧する");tap("端末内で復旧を開始")
    }
    private func visible(_ e:XCUIElement,towardTop:Bool=false)->XCUIElement {
        let recoveryList=app.collectionViews["manual-recovery-list"]
        let list=recoveryList.exists ? recoveryList : app.collectionViews.firstMatch
        var navigationState=ManualScrollNavigation(initiallyUpward:!towardTop),targetID=""
        for attempt in 0..<16 {
            let navigation=recoveryList.exists ? app.navigationBars["時間割の復旧"] : app.navigationBars.firstMatch
            let top=max(list.frame.minY,navigation.frame.maxY)+12
            let bottom=min(list.frame.maxY,app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY-45 : list.frame.maxY)-12
            let viewport=CGRect(x:list.frame.minX+100,y:top,width:1,height:max(0,bottom-top))
            guard ManualScrollNavigation.usable(viewport),viewport.height>36 else {
                print("TAKUPOKE-MANUAL-SCROLL invalid-viewport;\(viewport)");break
            }
            let exists=e.exists,targetFrame=exists ? e.frame:nil
            if exists && e.isHittable {
                let editor=e.elementType == .textField || e.elementType == .textView
                // The44px clear control is taller than a single-line editor.
                // Hittable alone can include a control straddling the keyboard
                // accessory. Reveal the whole control before a native tap.
                let boundedControl=editor || e.identifier.hasPrefix("manual-clear-")
                if !boundedControl { return e }
                if let frame=targetFrame,ManualScrollNavigation.usable(frame),frame.minY>=top,frame.maxY<=bottom { return e }
            }
            if exists && targetID.isEmpty { targetID=e.identifier }
            // Resolve the unique actual containing Cell, even when its focused
            // child exposes an infinite/zero or stale in-viewport frame.
            let owners=targetID.isEmpty ? []:list.cells.containing(.any,identifier:targetID).allElementsBoundByIndex
            let ownerFrame=owners.count==1 ? owners[0].frame:nil
            navigationState.locate(target:targetFrame,owner:ownerFrame,viewport:viewport)
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
            func passiveCell(_ upward:Bool)->XCUIElement? {
                passive.max(by:{
                    let a=$0.frame.intersection(viewport),b=$1.frame.intersection(viewport)
                    return upward ? a.maxY<b.maxY:a.minY>b.minY
                })
            }
            guard let firstCell=passiveCell(navigationState.upward) else {
                print("TAKUPOKE-MANUAL-SCROLL no-passive-cell;list=\(list.frame);viewport=\(viewport)")
                break
            }
            let anchor="\(firstCell.label);\(firstCell.staticTexts.firstMatch.exists ? firstCell.staticTexts.firstMatch.label:"");\(firstCell.images.firstMatch.exists ? firstCell.images.firstMatch.identifier:"");\(firstCell.frame)"
            guard navigationState.observe(anchor:anchor) else {
                print("TAKUPOKE-MANUAL-SCROLL no-progress-after-reverse;\(anchor)");break
            }
            // A reversal must also select the passive start Cell for its new direction.
            guard let cell=passiveCell(navigationState.upward) else { break }
            let safe=cell.frame.intersection(viewport),upward=navigationState.upward
            print("TAKUPOKE-MANUAL-SCROLL attempt=\(attempt);up=\(upward);anchor=\(anchor);target=\(targetFrame.map { String(describing:$0) } ?? "virtualized");owner=\(ownerFrame.map { String(describing:$0) } ?? "unknown");reversed=\(navigationState.reversed)")
            let base=list.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0))
            // Touch begins inside the passive Cell; the pan can continue across the List.
            // Viewport-sized drags retain the16-attempt cap for the complete40-slot preview.
            let start=base.withOffset(CGVector(dx:100,dy:(upward ? safe.maxY-12:safe.minY+12)-list.frame.minY))
            let end=base.withOffset(CGVector(dx:100,dy:(upward ? viewport.minY+12:viewport.maxY-12)-list.frame.minY))
            start.press(forDuration:0.1,thenDragTo:end)
        }
        XCTAssertTrue(e.exists && e.isHittable,app.debugDescription)
        XCTFail("No safe visible hit region after bounded navigation: "+app.debugDescription);return e
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
    private func requireReview(_ expected:[String],comparable:Bool) {
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
    private func inspectSource(_ id:String) {
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
    private func requirePreview() {
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
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        emitEvents()
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    private func assertSubmitEnabled(_ expected:Bool) {
        let button=visible(submit)
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"enabled == %@",NSNumber(value:expected)),object:button)
        let outcome=XCTWaiter.wait(for:[changed],timeout:nativeStateTimeout)
        let state=app.staticTexts["manual-input-state"].firstMatch
        print("TAKUPOKE-MANUAL-INPUT " + (state.exists ? state.label : "absent"))
        XCTAssertEqual(outcome,.completed,app.debugDescription)
    }
    private func edit(_ e:XCUIElement,_ value:String) {
        visible(e).tap()
        editStage("after-focus",e)
        let id=e.identifier.replacingOccurrences(of:"manual-value-",with:"")
        let clear=app.buttons["manual-clear-"+id].firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        let target=visible(clear)
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
        visible(e).tap()
        e.typeText(value)
        // End the native editor before the independent acknowledgement tap.
        // The product commits text and dismisses the keyboard; it never checks
        // acknowledgement on the user's behalf.
        let done=app.buttons["manual-edit-done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        XCTAssertTrue(done.isHittable,app.debugDescription)
        done.tap()
        let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:nativeStateTimeout),.completed,app.debugDescription)
        XCTAssertEqual(e.value as? String,value,"The physical edit must replace the full previous input before acknowledgement")
    }
    private func editStage(_ stage:String,_ e:XCUIElement) {
        let keyboard=app.keyboards.firstMatch
        let exists=e.exists
        print("TAKUPOKE-MANUAL-EDIT stage=\(stage);id=\(exists ? e.identifier:"absent");exists=\(exists);hittable=\(exists && e.isHittable);frame=\(exists ? String(describing:e.frame):"absent");focused=\(exists && e.debugDescription.contains("Keyboard Focused"));keyboard=\(keyboard.exists ? String(describing:keyboard.frame):"absent")")
    }
    func testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground() {
        launch();XCTAssertTrue(fieldsExist(),app.debugDescription);XCTAssertEqual(fieldIDs.count,1)
        let key=fieldIDs[0];let input=input(key)
        inspectSource(key)
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
        requireReview([value+"改"],comparable:false)
        XCUIDevice.shared.press(.home)
        XCTAssertNotEqual(app.state,.notRunning,"Background must preserve the correction review; no relaunch")
        guard app.state != .notRunning else { return }
        app.activate()
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10))
        XCTAssertEqual(app.staticTexts["manual-process-launch"].firstMatch.label,processBefore)
        requireReview([value+"改"],comparable:false)
        print("TAKUPOKE-MANUAL-REVIEW-BACKGROUND same-process;review-retained;preview=false")
        // Reopening the editor retains literal input; a fresh edit clears ACK
        // and cannot reuse the previously validated correction review.
        tap("入力を見直す")
        XCTAssertEqual(visible(input).value as? String,value+"改")
        edit(input,value+"再確認");XCTAssertEqual(visible(ack(key)).value as? String,"0")
        assertSubmitEnabled(false);acknowledge(key);visible(submit).tap()
        requireReview([value+"再確認"],comparable:false)
        inspectSource(key)
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
    func testChangedOriginalCannotSubmitOrReplaceLastGood() {
        launch();XCTAssertTrue(fieldsExist())
        let key=fieldIDs[0];edit(input(key),"架空変更前確認");acknowledge(key)
        tap("架空検証");tap("架空原本のハッシュを変更")
        XCTAssertTrue(app.staticTexts["manual-mutation-complete"].waitForExistence(timeout:10),app.debugDescription)
        visible(submit).tap()
        XCTAssertTrue(app.staticTexts["原本または入力内容を確認できませんでした。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        XCTAssertFalse(app.buttons["この資料全体の結果を使用"].exists)
        app.terminate();launch()
        XCTAssertTrue(fieldsExist())
        let second=fieldIDs[0];edit(input(second),"架空再照合");acknowledge(second);visible(submit).tap()
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
            let input=input(ids[i]);edit(input,"架空手確認\(i)")
            let ack=ack(ids[i]);XCTAssertEqual(visible(ack).value as? String,"0");acknowledge(ids[i])
            assertSubmitEnabled(i==2)
        }
        visible(submit).tap();requireReview((0..<3).map { "架空手確認\($0)" },comparable:true)
        tap("訂正と変更を確認して資料全体へ");requirePreview()
        XCTAssertTrue(app.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        tap("閉じる");XCTAssertFalse(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("adopted="))
        app.terminate();launch(["--manual-four"])
        XCTAssertTrue(app.staticTexts["架空資料の補助入力を拒否しました。前回の正常結果を保持しています。"].waitForExistence(timeout:20),app.debugDescription)
        emitDiagnostic()
        XCTAssertFalse(submit.exists);XCTAssertFalse(app.staticTexts["manual-field-ids"].exists)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
    }
}
