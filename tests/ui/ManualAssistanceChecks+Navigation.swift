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
    func visible(_ e:XCUIElement,towardTop:Bool=false,knownID:String="",alternatives:XCUIElementQuery?=nil,buttonLabel:String?=nil)->XCUIElement {
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
            let navigation=inRecovery ? app.navigationBars["時間割の復旧"] : app.navigationBars.firstMatch
            let top=max(list.frame.minY,navigation.frame.maxY)+12
            let keyboardFrame=observedKeyboardFrame()
            let bottom=min(list.frame.maxY,keyboardFrame.map { $0.minY-45 } ?? list.frame.maxY)-12
            let viewport=CGRect(x:list.frame.minX,y:top,width:list.frame.width,height:max(0,bottom-top))
            guard ManualScrollNavigation.usable(viewport),viewport.height>36 else {
                print("TAKUPOKE-MANUAL-SCROLL invalid-viewport;\(viewport)");break
            }
            // Observe the viewport before resolving a recyclable row. The outer
            // control follows its logical ID while revealing it (N97); only the
            // final inner native contact is bound to accessibility identity (N94).
            let acknowledgement=inRecovery && targetID.hasPrefix("manual-ack-")
            let query=inRecovery && targetID.hasPrefix("manual-clear-")
                ? list.buttons.matching(identifier:targetID)
                : acknowledgement ? list.switches.matching(identifier:targetID)
                : app.descendants(matching:.any).matching(identifier:targetID)
            let matches=targetID.isEmpty ? []:query.allElementsBoundByIndex
            guard matches.count<=1 else {
                XCTFail("Known manual control must be unique: "+targetID);return e
            }
            let target=matches.first ?? e
            if let alternatives,let actual=manualVisibleCandidate(
                candidates:alternatives.allElementsBoundByIndex,viewport:viewport,
                frame:{ $0.frame },isHittable:{ $0.isHittable }) { return actual }
            let exists=targetID.isEmpty ? target.exists:!matches.isEmpty
            let targetFrame=exists ? target.frame:nil
            if alternatives==nil && exists {
                print("TAKUPOKE-MANUAL-TARGET id=\(targetID);frame=\(targetFrame ?? .null);viewport=\(viewport)")
            }
            // This row is only the container for the actual native switch.
            // acknowledge(_:) validates the inner control before its one contact.
            if acknowledgement,let frame=targetFrame,
               ManualScrollNavigation.usable(frame),viewport.contains(frame) { return target }
            // As for alternative controls, inspect hit testing only after the
            // actual frame is finite and wholly inside the unobscured viewport.
            let targetHittable=alternatives==nil && exists && manualVisibleCandidate(
                candidates:[target],viewport:viewport,frame:{ _ in targetFrame ?? .null },
                isHittable:{ $0.isHittable }) != nil
            if targetHittable {
                let physicalButtons:XCUIElementQuery?
                if inRecovery && targetID.hasPrefix("manual-clear-") {
                    physicalButtons=query
                } else if let buttonLabel {
                    let buttons=targetID.isEmpty ? app.buttons : app.buttons.matching(identifier:targetID)
                    physicalButtons=buttons.matching(NSPredicate(format:"label == %@",buttonLabel))
                } else {
                    physicalButtons=nil
                }
                if let physicalButtons {
                    // Navigation follows logical IDs/labels across recycled rows.
                    // Bind only the final physical Button to its current identity.
                    let controls=physicalButtons.allElementsBoundByAccessibilityElement
                    guard controls.count==1 else {
                        XCTFail("The revealed Button must have one current native identity");return e
                    }
                    let actual=controls[0],frame=actual.frame
                    guard ManualScrollNavigation.usable(frame),viewport.contains(frame),
                          actual.isEnabled,actual.isHittable else {
                        XCTFail("The current native Button must remain inside the observed viewport and operable");return e
                    }
                    return actual
                }
                return target
            }
            if alternatives==nil && exists && targetID.isEmpty { targetID=target.identifier }
            // Resolve the unique actual containing Cell, even when its focused
            // child exposes an infinite/zero or stale in-viewport frame.
            let owners=targetID.isEmpty ? []:list.cells.containing(.any,identifier:targetID).allElementsBoundByIndex
            let ownerFrame=owners.count==1 ? owners[0].frame:nil
            let alignment=navigationState.locate(target:targetFrame,owner:ownerFrame,viewport:viewport,
                needsHitRegion:alternatives==nil && exists && !targetHittable)
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
            typealias PassiveRow = (cell:XCUIElement,frame:CGRect,anchor:String)
            var rowFrames:[ObjectIdentifier:CGRect]=[:],rowAnchors:[ObjectIdentifier:String]=[:]
            func passiveCell(_ upward:Bool)->PassiveRow? {
                let selected=manualPassiveCell(cells:cells,viewport:viewport,upward:upward,frame:{ cell in
                    let id=ObjectIdentifier(cell)
                    if let frame=rowFrames[id] { return frame }
                    let frame=cell.frame;rowFrames[id]=frame;return frame
                },isPassive:{ cell in
                    let id=ObjectIdentifier(cell)
                    if rowAnchors[id] != nil { return true }
                    guard cell.buttons.count==0 && cell.switches.count==0 && cell.textFields.count==0 && cell.textViews.count==0
                        && cell.pickers.count==0 && cell.pickerWheels.count==0 else { return false }
                    // Capture the real descendants while proving this row is
                    // passive. Re-querying the same Cell afterward stalled AX.
                    let texts=cell.staticTexts.allElementsBoundByIndex
                    let images=texts.isEmpty ? cell.images.allElementsBoundByIndex:[]
                    guard !texts.isEmpty || !images.isEmpty,let frame=rowFrames[id] else { return false }
                    let relative=frame.offsetBy(dx:-list.frame.minX,dy:-list.frame.minY)
                    rowAnchors[id]="\(cell.label);\(texts.first?.label ?? "");\(images.first?.identifier ?? "");\(relative)"
                    return true
                })
                guard let selected,let frame=rowFrames[ObjectIdentifier(selected)],let anchor=rowAnchors[ObjectIdentifier(selected)] else { return nil }
                return (selected,frame,anchor)
            }
            let initialDirection=navigationState.upward
            guard let first=passiveCell(initialDirection) else {
                print("TAKUPOKE-MANUAL-SCROLL no-passive-cell;list=\(list.frame);viewport=\(viewport)")
                break
            }
            let anchor=first.anchor
            guard navigationState.observe(anchor:anchor,atTop:observedTop) else {
                print("TAKUPOKE-MANUAL-SCROLL no-progress-after-reverse;\(anchor)");break
            }
            // No UI action occurred since the observation. Reuse it unless
            // the bounded no-progress rule actually reversed the direction.
            let selected:PassiveRow
            if navigationState.upward==initialDirection { selected=first }
            else { guard let reversed=passiveCell(navigationState.upward) else { break };selected=reversed }
            let safe=selected.frame.intersection(viewport),upward=navigationState.upward
            print("TAKUPOKE-MANUAL-SCROLL attempt=\(attempt);up=\(upward);anchor=\(anchor);target=\(targetFrame.map { String(describing:$0) } ?? "virtualized");owner=\(ownerFrame.map { String(describing:$0) } ?? "unknown");reversed=\(navigationState.reversed)")
            let base=list.coordinate(withNormalizedOffset:CGVector(dx:0,dy:0))
            // Touch begins inside the passive Cell; the pan can continue across the List.
            // Upward viewport-sized drags cover the complete40-slot preview.
            // Downward steps stay bounded, with the same16-attempt total cap.
            let startY=upward ? safe.maxY-12:safe.minY+12
            let endY=alignment.flatMap { ($0<0)==upward ? $0:nil }
                .map { min(viewport.maxY-12,max(viewport.minY+12,startY+$0)) }
                ?? (upward ? viewport.minY+12:min(viewport.maxY-12,startY+240))
            guard abs(endY-startY)>1 else {
                XCTFail("The centered target has no safe hit region: "+targetID);return e
            }
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
    func tap(_ title:String,knownID:String="") {
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
        visible(app.buttons[title].firstMatch,knownID:knownID,buttonLabel:title).tap()
    }
}
