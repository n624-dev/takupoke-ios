import XCTest
import UIKit

struct ManualButtonObservation {
    let frame: CGRect
    let viewport: CGRect
    let isSelected: Bool
}

extension ManualAssistanceChecks {
    func observedKeyboardFrame()->CGRect? {
        // An optional, absent firstMatch can stall AX instead of returning
        // false. Enumerate actual elements once; presence is never fabricated.
        let keyboards=app.keyboards.allElementsBoundByAccessibilityElement
        XCTAssertLessThanOrEqual(keyboards.count,1,"Keyboard geometry must be unique")
        guard keyboards.count==1 else { return nil }
        let frame=keyboards[0].frame
        XCTAssertTrue(ManualScrollNavigation.usable(frame),"Present keyboard must have finite positive geometry")
        return frame
    }
    func visible(_ e:XCUIElement,towardTop:Bool=false,knownID:String="",alternatives:((any XCUIElementSnapshot)->Bool)?=nil,buttonLabel:String?=nil,ownerID:String="manual-recovery-list",barTitle:String="時間割の復旧",observeButton:((ManualButtonObservation)->Void)?=nil)->XCUIElement {
        let started = ProcessInfo.processInfo.systemUptime
        var attempts = 0
        defer {
            print("TAKUPOKE-MANUAL-NAVIGATION seconds=\(ProcessInfo.processInfo.systemUptime-started);attempts=\(attempts)")
        }
        let recoveryList=app.collectionViews["manual-recovery-list"]
        let inRecovery=ownerID=="manual-recovery-list"
        if inRecovery { XCTAssertTrue(recoveryList.waitForExistence(timeout:nativeStateTimeout)) }
        var navigationState=ManualScrollNavigation(initiallyUpward:!towardTop)
        let targetID=knownID
        for attempt in 0..<16 {
            attempts = attempt + 1
            if inRecovery {
                guard recoveryList.exists,app.navigationBars["時間割の復旧"].exists else {
                    XCTFail("The recovery sheet disappeared during navigation: "+app.debugDescription);return e
                }
            }
            // Rebind the current List after every gesture; never retain it
            // across recycled rows. Read its frame once per attempt (N213).
            let listQuery=app.collectionViews.matching(identifier:ownerID)
            let currentLists=listQuery.allElementsBoundByAccessibilityElement
            guard currentLists.count<=1 else {
                XCTFail("The current page must have one unambiguous native List");return e
            }
            guard let list=currentLists.first else {
                if inRecovery { XCTFail("The recovery List disappeared");return e }
                // A pushed normal page can precede its List's AX registration.
                // Observe again within the original 16 attempts; send no input.
                print("TAKUPOKE-MANUAL-SCROLL pending-list;attempt=\(attempt)");continue
            }
            let bars=app.navigationBars.matching(identifier:barTitle).allElementsBoundByAccessibilityElement
            guard bars.count<=1 else { XCTFail("Ambiguous navigation bar: "+barTitle);return e }
            guard let navigation=bars.first else { continue }
            let listFrame=list.frame,navigationFrame=navigation.frame
            let top=max(listFrame.minY,navigationFrame.maxY)+12
            let keyboardFrame=observedKeyboardFrame()
            let bottom=min(listFrame.maxY,keyboardFrame.map { $0.minY-45 } ?? listFrame.maxY)-12
            let viewport=CGRect(x:listFrame.minX,y:top,width:listFrame.width,height:max(0,bottom-top))
            guard ManualScrollNavigation.usable(viewport),viewport.height>36 else {
                // Never retain transition-time zero geometry or operate on it.
                // This observation consumes the same original attempt budget.
                print("TAKUPOKE-MANUAL-SCROLL invalid-viewport;\(viewport)");continue
            }
            // Observe the viewport before resolving a recyclable row.
            let correctionMenu=inRecovery && targetID.hasPrefix("recovery-correction-menu-")
            let recoveryTexts:Set<String>=["manual-review-header","manual-preview-header","manual-status",
                "manual-comparison-available","manual-comparison-unavailable","manual-change-before","manual-change-after"]
            let reviewAction=targetID=="manual-review-submit"
            let ordinaryButton=reviewAction ? nil : buttonLabel
            let query:XCUIElementQuery
            if targetID.isEmpty,let ordinaryButton {
                query=list.buttons.matching(NSPredicate(format:"label == %@",ordinaryButton))
            } else if ordinaryButton != nil || targetID.hasPrefix("manual-clear-") || targetID == "manual-submit" {
                query=list.buttons.matching(identifier:targetID)
            } else if recoveryTexts.contains(targetID) || correctionMenu {
                query=list.staticTexts.matching(identifier:targetID)
            } else {
                query=list.descendants(matching:.any).matching(identifier:targetID)
            }
            let matches:[XCUIElement]
            if alternatives != nil { matches=[] }
            else if ordinaryButton != nil || reviewAction {
                // The review action can appear as Button or PopUpButton.
                // Avoid index rebinding when it reappears after a reload.
                matches=query.allElementsBoundByAccessibilityElement
            }
            else { matches=query.allElementsBoundByIndex }
            guard matches.count<=1 else {
                XCTFail("Known manual control must be unique: "+targetID);return e
            }
            let target=matches.first ?? e
            // Read candidate geometry from one List snapshot. A recycled or
            // offscreen row must not trigger an XCTest identity lookup.
            var alternativeFrame:CGRect?
            if let alternatives,let snapshot=try? list.snapshot(),let nodes=snapshotNodes(in:snapshot) {
                let candidates=nodes.filter { $0.elementType == .staticText && alternatives($0) }
                alternativeFrame=candidates.first?.frame
                var current:XCUIElement?
                let visibleCandidate=manualVisibleCandidate(candidates:candidates,viewport:viewport,frame:{ $0.frame }) { candidate in
                    guard !candidate.identifier.isEmpty,candidate.isEnabled else { return false }
                    let matching=list.staticTexts.matching(identifier:candidate.identifier).allElementsBoundByAccessibilityElement
                    guard matching.count==1,let element=matching.first,let bound=try? element.snapshot(),
                          bound.elementType == .staticText,bound.identifier==candidate.identifier,bound.label==candidate.label,
                          bound.frame==candidate.frame,bound.isEnabled,element.isHittable else { return false }
                    current=element
                    return true
                }
                if visibleCandidate != nil,let current { return current }
            }
            let exists = !matches.isEmpty
            let targetFrame:CGRect?
            var buttonSnapshot: (any XCUIElementSnapshot)?
            if alternatives != nil { targetFrame=alternativeFrame }
            else if exists, observeButton != nil {
                guard let snapshot = try? target.snapshot() else {
                    XCTFail("Could not observe the current native Button: " + targetID);return e
                }
                buttonSnapshot = snapshot
                targetFrame = snapshot.frame
            }
            else { targetFrame=exists ? target.frame:nil }
            if alternatives==nil && exists {
                print("TAKUPOKE-MANUAL-TARGET id=\(targetID);frame=\(targetFrame ?? .null);viewport=\(viewport)")
            }
            // Reuse an already bound button for hit testing and contact.
            // Indexed controls bind their current physical identity here.
            if alternatives==nil,exists,let targetFrame,
               ManualScrollNavigation.usable(targetFrame),viewport.contains(targetFrame) {
                if reviewAction {
                    let kind=target.elementType
                    print("TAKUPOKE-MANUAL-NATIVE-REVIEW type=\(kind.rawValue);frame=\(targetFrame);viewport=\(viewport);attempt=\(attempt)")
                    guard target.identifier == targetID,target.label == buttonLabel,
                          kind == .button || kind == .popUpButton,
                          target.isEnabled,target.isHittable else {
                        XCTFail("The review action must be an operable native Button or PopUpButton with its exact label");return e
                    }
                    return target
                }
                if let ordinaryButton {
                    if let snapshot = buttonSnapshot, let observeButton {
                        guard snapshot.elementType == .button, snapshot.identifier == targetID,
                              snapshot.label == ordinaryButton, snapshot.isEnabled, target.isHittable else {
                            XCTFail("The current native Button must match its identity and be operable");return e
                        }
                        observeButton(.init(frame:targetFrame,viewport:viewport,isSelected:snapshot.isSelected))
                        return target
                    }
                    guard target.label == ordinaryButton,target.isEnabled,target.isHittable else {
                        XCTFail("The current list button must match its label and be operable");return e
                    }
                    return target
                }
                if correctionMenu {
                    // Reveal by logical ID, then bind only the actual contact.
                    let controls=query.allElementsBoundByAccessibilityElement
                    guard controls.count==1 else {
                        XCTFail("The revealed correction text must have one current native identity");return e
                    }
                    let actual=controls[0],frame=actual.frame
                    print("TAKUPOKE-MANUAL-NATIVE-MENU id=\(targetID);frame=\(frame);viewport=\(viewport);attempt=\(attempt)")
                    guard ManualScrollNavigation.usable(frame),viewport.contains(frame),
                          actual.isEnabled,actual.isHittable else {
                        XCTFail("The current correction text must remain inside the observed viewport and operable");return e
                    }
                    return actual
                }
                if targetID.hasPrefix("manual-clear-") {
                    // Navigation follows logical IDs/labels across recycled rows.
                    // Bind only the final physical Button to its current identity.
                    let controls=query.allElementsBoundByAccessibilityElement
                    guard controls.count==1 else {
                        XCTFail("The revealed Button must have one current native identity");return e
                    }
                    let actual=controls[0]
                    let frame=actual.frame
                    print("TAKUPOKE-MANUAL-NATIVE-BUTTON frame=\(frame);viewport=\(viewport);attempt=\(attempt)")
                    guard ManualScrollNavigation.usable(frame),viewport.contains(frame),
                          actual.isEnabled,actual.isHittable else {
                        XCTFail("The current native Button must remain inside the observed viewport and operable");return e
                    }
                    return actual
                }
            }
            // Non-Button targets retain their existing hit-testing path.
            let targetHittable=alternatives==nil && exists && manualVisibleCandidate(
                candidates:[target],viewport:viewport,frame:{ _ in targetFrame ?? .null },
                isHittable:{ $0.isHittable }) != nil
            if targetHittable { return target }
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
                    let relative=frame.offsetBy(dx:-listFrame.minX,dy:-listFrame.minY)
                    rowAnchors[id]="\(cell.label);\(texts.first?.label ?? "");\(images.first?.identifier ?? "");\(relative)"
                    return true
                })
                guard let selected,let frame=rowFrames[ObjectIdentifier(selected)],let anchor=rowAnchors[ObjectIdentifier(selected)] else { return nil }
                return (selected,frame,anchor)
            }
            let initialDirection=navigationState.upward
            guard let first=passiveCell(initialDirection) else {
                print("TAKUPOKE-MANUAL-SCROLL no-passive-cell;list=\(listFrame);viewport=\(viewport)")
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
            let observedX=safe.midX-listFrame.minX
            let start=base.withOffset(CGVector(dx:observedX,dy:startY-listFrame.minY))
            let end=base.withOffset(CGVector(dx:observedX,dy:endY-listFrame.minY))
            start.press(forDuration:0.1,thenDragTo:end)
        }
        XCTFail("No safe visible hit region in \(ownerID) after \(attempts) attempts for \(buttonLabel ?? targetID)");return e
    }
    func tap(_ title:String,knownID:String="",ownerID:String="manual-recovery-list",barTitle:String="時間割の復旧") {
        let button=app.collectionViews[ownerID].buttons[title]
        visible(button,knownID:knownID,buttonLabel:title,ownerID:ownerID,barTitle:barTitle).tap()
    }

    func chooseFixtureMenuAction(_ action: String) {
        let requiredTitles: Set<String> = ["表示サイズを変更", "同じ原本の状態を再確認", "架空原本のハッシュを変更"]
        guard requiredTitles.contains(action) else { XCTFail("Unknown fixture menu action: " + action); return }
        let title = "架空検証"
        let bar=app.navigationBars["時間割の復旧"]
        guard bar.waitForExistence(timeout:nativeStateTimeout),
              bar.buttons[title].waitForExistence(timeout:nativeStateTimeout) else {
            XCTFail("Fixture menu must exist on its recovery toolbar");return
        }
        let barFrame=bar.frame
        let current=bar.buttons.matching(NSPredicate(format:"label == %@",title))
            .allElementsBoundByAccessibilityElement
        guard current.count==1 else { XCTFail("Fixture menu must have one native Button");return }
        let button=current[0],frame=button.frame,screenFrame=app.frame
        guard ManualScrollNavigation.usable(screenFrame),ManualScrollNavigation.usable(barFrame),
              ManualScrollNavigation.usable(frame),screenFrame.contains(barFrame),
              barFrame.contains(frame),button.isEnabled,button.isHittable,app.state == .runningForeground else {
            XCTFail("Fixture menu must be visible on its own recovery toolbar: "+app.debugDescription);return
        }
        print("TAKUPOKE-MANUAL-MENU frame=\(frame);method=native-center-brief-contact;duration=0.1")
        let center = CGPoint(x: frame.midX, y: frame.midY)
        do {
            try NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)],
                                        named: "Manual fixture toolbar")
        } catch {
            XCTFail("Native fixture menu contact failed: \(error)");return
        }
        tapFixtureDialogAction(action, requiredTitles: requiredTitles, screenFrame: screenFrame)
    }

    private func tapFixtureDialogAction(_ title: String, requiredTitles: Set<String>, screenFrame: CGRect) {
        let actions = app.buttons.matching(NSPredicate(format: "label IN %@", argumentArray: [requiredTitles.sorted()]))
        let deadline = ProcessInfo.processInfo.systemUptime + nativeStateTimeout
        var selected: XCUIElement?, observation = "no action observation"
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline else { return false }
            let buttons = actions.allElementsBoundByAccessibilityElement
            observation = "native action count=\(buttons.count)"
            guard buttons.count == requiredTitles.count else { return false }
            var observedTitles: Set<String> = []
            var target: XCUIElement?
            for button in buttons {
                guard ProcessInfo.processInfo.systemUptime < deadline,
                      let snapshot = try? button.snapshot(), snapshot.elementType == .button,
                      requiredTitles.contains(snapshot.label), observedTitles.insert(snapshot.label).inserted,
                      ManualScrollNavigation.usable(snapshot.frame), screenFrame.contains(snapshot.frame),
                      snapshot.isEnabled else { return false }
                if snapshot.label == title { target = button }
            }
            observation = "native actions=\(observedTitles.sorted())"
            guard observedTitles == requiredTitles, let target, target.isHittable,
                  ProcessInfo.processInfo.systemUptime <= deadline else { return false }
            selected = target
            return true
        }, object: nil)
        guard XCTWaiter.wait(for: [ready], timeout: nativeStateTimeout) == .completed, let selected else {
            XCTFail("The fixture dialog must show three unique native actions: \(title);\(observation)");return
        }
        selected.tap()
    }

    func tapPopupAction(_ title: String) {
        var readyButton:XCUIElement?,ambiguous=false
        var observation = "snapshot unavailable"
        let deadline = ProcessInfo.processInfo.systemUptime + nativeStateTimeout
        let ready=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            guard ProcessInfo.processInfo.systemUptime < deadline,
                  let root = try? self.app.snapshot(), let nodes = self.snapshotNodes(in: root) else { return false }
            let buttons = nodes.filter { $0.elementType == .button }
            let current = buttons.filter { $0.label == title }
            observation = "matches=\(current.count)"
            if current.count>1 { ambiguous=true;return true }
            guard current.count==1 else { return false }
            let observed = current[0], frame = observed.frame
            let contained = ManualScrollNavigation.usable(frame) && root.frame.contains(frame)
            observation += ";frame=\(frame);contained=\(contained);enabled=\(observed.isEnabled)"
            guard contained, observed.isEnabled, ProcessInfo.processInfo.systemUptime < deadline else { return false }
            let bound = self.app.buttons.matching(NSPredicate(format: "label == %@", title))
                .allElementsBoundByAccessibilityElement
            observation += ";bound=\(bound.count)"
            if bound.count > 1 { ambiguous = true; return true }
            guard let button = bound.first, let boundSnapshot = try? button.snapshot() else { return false }
            observation += ";boundFrame=\(boundSnapshot.frame);boundEnabled=\(boundSnapshot.isEnabled)"
            guard boundSnapshot.elementType == observed.elementType, boundSnapshot.label == title,
                  boundSnapshot.identifier == observed.identifier, boundSnapshot.frame == frame, boundSnapshot.isEnabled,
                  ProcessInfo.processInfo.systemUptime < deadline else { return false }
            let hittable = button.isHittable
            observation += ";hittable=\(hittable)"
            guard hittable, ProcessInfo.processInfo.systemUptime <= deadline else { return false }
            readyButton=button
            return true
        },object:nil)
        let result=XCTWaiter.wait(for:[ready],timeout:nativeStateTimeout)
        guard !ambiguous,result == .completed,let button=readyButton else {
            XCTFail("The opened popup must have one visible and operable action: \(title);\(observation)");return
        }
        button.tap()
    }
}
