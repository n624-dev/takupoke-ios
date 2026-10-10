import XCTest
import UIKit

extension ManualAssistanceChecks {
    func observedKeyboardFrame()->CGRect? {
        // An optional, absent firstMatch can stall AX instead of returning
        // false. Enumerate actual elements once; presence is never fabricated.
        let keyboards=app.keyboards.allElementsBoundByIndex
        XCTAssertLessThanOrEqual(keyboards.count,1,"Keyboard geometry must be unique")
        guard keyboards.count==1 else { return nil }
        let frame=keyboards[0].frame
        XCTAssertTrue(ManualScrollNavigation.usable(frame),"Present keyboard must have finite positive geometry")
        return frame
    }
    func visible(_ e:XCUIElement,towardTop:Bool=false,knownID:String="")->XCUIElement {
        let started = ProcessInfo.processInfo.systemUptime
        var attempts = 0
        defer {
            print("TAKUPOKE-MANUAL-NAVIGATION seconds=\(ProcessInfo.processInfo.systemUptime-started);attempts=\(attempts)")
        }
        let recoveryList=app.collectionViews["manual-recovery-list"]
        let inRecovery=recoveryList.exists || app.navigationBars["時間割の復旧"].exists
        if inRecovery { XCTAssertTrue(recoveryList.waitForExistence(timeout:nativeStateTimeout)) }
        let list=inRecovery ? recoveryList : app.collectionViews.firstMatch
        var navigationState=ManualScrollNavigation(initiallyUpward:!towardTop),targetID=knownID
        for attempt in 0..<16 {
            attempts = attempt + 1
            if inRecovery {
                guard recoveryList.exists,app.navigationBars["時間割の復旧"].exists else {
                    XCTFail("The recovery sheet disappeared during navigation: "+app.debugDescription);return e
                }
            }
            // SwiftUI can recycle the native editor when its row is offscreen.
            // Resolve its known identifier again, without a cached native type.
            let matches=targetID.isEmpty ? []:app.descendants(matching:.any).matching(identifier:targetID).allElementsBoundByIndex
            let target=matches.first ?? e
            let navigation=inRecovery ? app.navigationBars["時間割の復旧"] : app.navigationBars.firstMatch
            let top=max(list.frame.minY,navigation.frame.maxY)+12
            let keyboardFrame=observedKeyboardFrame()
            let bottom=min(list.frame.maxY,keyboardFrame.map { $0.minY-45 } ?? list.frame.maxY)-12
            let viewport=CGRect(x:list.frame.minX,y:top,width:list.frame.width,height:max(0,bottom-top))
            guard ManualScrollNavigation.usable(viewport),viewport.height>36 else {
                print("TAKUPOKE-MANUAL-SCROLL invalid-viewport;\(viewport)");break
            }
            let exists=targetID.isEmpty ? target.exists:!matches.isEmpty
            let targetFrame=exists ? target.frame:nil
            if exists && target.isHittable {
                // Every interactive/readable target must be wholly below the
                // navigation bar and above the keyboard accessory before use.
                if let frame=targetFrame,ManualScrollNavigation.usable(frame),frame.minY>=top,frame.maxY<=bottom { return target }
            }
            if exists && targetID.isEmpty { targetID=target.identifier }
            // Resolve the unique actual containing Cell, even when its focused
            // child exposes an infinite/zero or stale in-viewport frame.
            let owners=targetID.isEmpty ? []:list.cells.containing(.any,identifier:targetID).allElementsBoundByIndex
            let ownerFrame=owners.count==1 ? owners[0].frame:nil
            navigationState.locate(target:targetFrame,owner:ownerFrame,viewport:viewport)
            var observedTop=false
            if inRecovery {
                let firstRows=list.staticTexts.matching(NSPredicate(format:"label == %@","学校の資料・OCR文字・授業情報は端末内で処理され、外部のAIへ送信されません。")).allElementsBoundByIndex
                if firstRows.count==1 {
                    let frame=firstRows[0].frame
                    if ManualScrollNavigation.usable(frame),frame.minY>=top,frame.maxY<=bottom {
                        observedTop=true
                        navigationState.observeTopBoundary()
                    }
                }
            }
            // Pick a real passive Cell on each attempt, including preview lesson/header rows.
            // Never start a drag on an editor, button, switch, keyboard or outer List gutter.
            let cells=list.cells.allElementsBoundByIndex
            func passiveCell(_ upward:Bool)->XCUIElement? {
                manualPassiveCell(cells:cells,viewport:viewport,upward:upward,frame:{ $0.frame },isPassive:{
                    $0.buttons.count==0 && $0.switches.count==0 && $0.textFields.count==0 && $0.textViews.count==0
                        && $0.pickers.count==0 && $0.pickerWheels.count==0
                        && ($0.images.count>0 || $0.staticTexts.count>0)
                })
            }
            guard let firstCell=passiveCell(navigationState.upward) else {
                print("TAKUPOKE-MANUAL-SCROLL no-passive-cell;list=\(list.frame);viewport=\(viewport)")
                break
            }
            let anchorFrame=firstCell.frame.offsetBy(dx:-list.frame.minX,dy:-list.frame.minY)
            // Use actual descendants from this passive row. Asking whether an
            // absent firstMatch image exists can time out in iOS 27 AX even
            // after the same row's real text was found successfully.
            let anchorTexts=firstCell.staticTexts.allElementsBoundByIndex
            let anchorImages=anchorTexts.isEmpty ? firstCell.images.allElementsBoundByIndex:[]
            let anchor="\(firstCell.label);\(anchorTexts.first?.label ?? "");\(anchorImages.first?.identifier ?? "");\(anchorFrame)"
            guard navigationState.observe(anchor:anchor,atTop:observedTop) else {
                print("TAKUPOKE-MANUAL-SCROLL no-progress-after-reverse;\(anchor)");break
            }
            // A reversal must also select the passive start Cell for its new direction.
            guard let cell=passiveCell(navigationState.upward) else { break }
            let safe=cell.frame.intersection(viewport),upward=navigationState.upward
            print("TAKUPOKE-MANUAL-SCROLL attempt=\(attempt);up=\(upward);anchor=\(anchor);target=\(targetFrame.map { String(describing:$0) } ?? "virtualized");owner=\(ownerFrame.map { String(describing:$0) } ?? "unknown");reversed=\(navigationState.reversed)")
            let base=list.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0))
            // Touch begins inside the passive Cell; the pan can continue across the List.
            // Upward viewport-sized drags cover the complete40-slot preview.
            // Downward steps stay bounded, with the same16-attempt total cap.
            let startY=upward ? safe.maxY-12:safe.minY+12
            let endY=upward ? viewport.minY+12:min(viewport.maxY-12,startY+240)
            if inRecovery {
                guard recoveryList.exists,app.navigationBars["時間割の復旧"].exists else {
                    XCTFail("The recovery sheet disappeared before its gesture: "+app.debugDescription);return e
                }
            }
            let observedX=safe.midX-list.frame.minX
            let start=base.withOffset(CGVector(dx:observedX,dy:startY-list.frame.minY))
            let end=base.withOffset(CGVector(dx:observedX,dy:endY-list.frame.minY))
            start.press(forDuration:0.1,thenDragTo:end)
        }
        XCTAssertTrue(e.exists && e.isHittable,app.debugDescription)
        XCTFail("No safe visible hit region after bounded navigation: "+app.debugDescription);return e
    }
    func tap(_ title:String) {
        if title == "架空検証" {
            let bar=app.navigationBars["時間割の復旧"],button=app.navigationBars["時間割の復旧"].buttons[title]
            guard bar.waitForExistence(timeout:nativeStateTimeout),button.waitForExistence(timeout:nativeStateTimeout),
                  ManualScrollNavigation.usable(bar.frame),ManualScrollNavigation.usable(button.frame),
                  bar.frame.contains(button.frame),button.isEnabled,button.isHittable else {
                XCTFail("Fixture menu must be visible on its own recovery toolbar: "+app.debugDescription);return
            }
            button.tap()
            for action in fixtureMenuActions {
                XCTAssertTrue(app.buttons[action].waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
            }
            fixtureMenuOpen=true
            return
        }
        if fixtureMenuActions.contains(title) {
            guard fixtureMenuOpen else { XCTFail("Fixture action requires the explicitly opened menu");return }
            var readyButton:XCUIElement?
            var observation="not-observed"
            let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
                let current=self.app.buttons.matching(NSPredicate(format:"label == %@",title))
                    .allElementsBoundByIndex
                guard current.count==1 else {
                    observation="matches=\(current.count)";return false
                }
                let button=current[0],frame=button.frame
                let contained=self.app.frame.contains(frame)
                let enabled=button.isEnabled,hittable=button.isHittable
                observation="frame=\(frame);contained=\(contained);enabled=\(enabled);hittable=\(hittable)"
                guard ManualScrollNavigation.usable(frame),contained,enabled,hittable else { return false }
                readyButton=button
                return true
            },object:app)
            let result=XCTWaiter.wait(for:[ready],timeout:nativeStateTimeout)
            guard result == .completed,let button=readyButton else {
                XCTFail("Opened menu action must have its own visible hit region: "+observation);return
            }
            // The popup has its own hit regions; scrolling the underlying List
            // cannot reveal it and may dismiss the menu or the recovery sheet.
            button.tap();fixtureMenuOpen=false
            return
        }
        visible(app.buttons[title].firstMatch).tap()
    }
}
