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
        var appFrame = CGRect.null
        var observed = observeVisibleManualSubmit(appFrame: &appFrame)
        if observed == nil {
            appFrame = app.frame
            _ = visible(submit, knownID: "manual-submit", buttonLabel: "訂正箇所と前回からの変更を確認") {
                observed = $0
            }
        }
        guard let observed, ManualScrollNavigation.usable(appFrame), appFrame.contains(observed.frame),
              app.state == .runningForeground else {
            XCTFail("The manual submit button must be visible on the active recovery screen"); return
        }
        let center = CGPoint(x: observed.frame.midX, y: observed.frame.midY)
        print("TAKUPOKE-MANUAL-SUBMIT frame=\(observed.frame);viewport=\(observed.viewport);duration=0.1")
        do {
            try NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)],
                                        named: "Manual correction submission")
        } catch {
            XCTFail("Native correction submission contact failed: \(error)")
        }
    }

    private func observeVisibleManualSubmit(appFrame: inout CGRect) -> ManualButtonObservation? {
        guard let root = try? app.snapshot(), let nodes = snapshotNodes(in: root) else { return nil }
        let lists = nodes.filter { $0.elementType == .collectionView && $0.identifier == "manual-recovery-list" }
        let bars = nodes.filter { $0.elementType == .navigationBar && $0.identifier == "時間割の復旧" }
        let keyboards = nodes.filter { $0.elementType == .keyboard }
        guard lists.count <= 1, bars.count <= 1, keyboards.count <= 1 else {
            XCTFail("The recovery screen must have a unique List, navigation bar and keyboard")
            return nil
        }
        guard let list = lists.first, let bar = bars.first,
              ManualScrollNavigation.usable(list.frame), ManualScrollNavigation.usable(bar.frame),
              let children = snapshotNodes(in: list) else { return nil }
        if let keyboard = keyboards.first, !ManualScrollNavigation.usable(keyboard.frame) {
            XCTFail("A present keyboard must have finite positive geometry")
            return nil
        }
        let candidates = children.filter { $0.identifier == "manual-submit" }
        guard candidates.count <= 1 else {
            XCTFail("The visible recovery List must have a unique submit control")
            return nil
        }
        guard let target = candidates.first, target.elementType == .button,
              target.label == "訂正箇所と前回からの変更を確認", target.isEnabled else { return nil }
        let top = max(list.frame.minY, bar.frame.maxY) + 12
        let bottom = min(list.frame.maxY, keyboards.first.map { $0.frame.minY - 45 } ?? list.frame.maxY) - 12
        let viewport = CGRect(x: list.frame.minX, y: top, width: list.frame.width, height: max(0, bottom - top))
        guard ManualScrollNavigation.usable(viewport), viewport.height > 36,
              ManualScrollNavigation.usable(root.frame), ManualScrollNavigation.usable(target.frame),
              viewport.contains(target.frame), root.frame.contains(target.frame) else { return nil }
        let controls = recoveryList.buttons.matching(identifier: target.identifier).allElementsBoundByAccessibilityElement
        guard controls.count <= 1 else {
            XCTFail("The recovery submit Button must have one current native identity")
            return nil
        }
        guard let control = controls.first, let bound = try? control.snapshot(),
              bound.elementType == target.elementType, bound.identifier == target.identifier, bound.label == target.label,
              bound.frame == target.frame, bound.isEnabled, control.isHittable else { return nil }
        appFrame = root.frame
        return .init(frame: target.frame, viewport: viewport, isSelected: target.isSelected)
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
        guard finishManualEditing() else { return }
        let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate { _,_ in
            self.app.keyboards.allElementsBoundByIndex.isEmpty
        },object:app)
        XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:nativeStateTimeout),.completed,app.debugDescription)
        let completed=self.recoveryList.descendants(matching:.any).matching(identifier:"manual-value-"+id).allElementsBoundByIndex
        guard completed.count==1 else { XCTFail("Completed input must remain unique");return }
        XCTAssertEqual(completed[0].value as? String,value,"The physical edit must replace the full previous input before acknowledgement")
    }

    private func finishManualEditing() -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + nativeStateTimeout
        var targetFrame: CGRect?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard ProcessInfo.processInfo.systemUptime < deadline else { return false }
            targetFrame = self.observeManualEditCompletion()
            return targetFrame != nil
        }, object: nil)
        let remaining = deadline - ProcessInfo.processInfo.systemUptime
        guard remaining > 0, XCTWaiter.wait(for: [ready], timeout: remaining) == .completed,
              let targetFrame, app.state == .runningForeground,
              ProcessInfo.processInfo.systemUptime < deadline else {
            XCTFail("The native completion button must be unique, visible and operable within the original deadline")
            return false
        }
        let center = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        print("TAKUPOKE-MANUAL-EDIT-DONE frame=\(targetFrame);duration=0.1")
        do {
            try NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)],
                                        named: "Manual edit completion button")
            return true
        } catch {
            XCTFail("Native edit completion contact failed: \(error)")
            return false
        }
    }

    private func observeManualEditCompletion() -> CGRect? {
        let title = "時間割の復旧"
        let identifier = "manual-edit-done"
        let label = "完了"
        guard let root = try? app.snapshot(), let nodes = snapshotNodes(in: root),
              ManualScrollNavigation.usable(root.frame) else { return nil }
        let bars = nodes.filter { $0.elementType == .navigationBar && $0.identifier == title }
        guard bars.count <= 1 else { XCTFail("The recovery navigation bar must be unique"); return nil }
        guard let bar = bars.first, ManualScrollNavigation.usable(bar.frame),
              let controls = snapshotNodes(in: bar) else { return nil }
        let candidates = controls.filter { $0.identifier == identifier }
        guard candidates.count <= 1 else { XCTFail("The recovery completion control must be unique"); return nil }
        guard let target = candidates.first, target.elementType == .button, target.label == label, target.isEnabled,
              ManualScrollNavigation.usable(target.frame), bar.frame.contains(target.frame),
              root.frame.contains(target.frame) else { return nil }
        let live = app.navigationBars[title].buttons.matching(identifier: identifier)
            .matching(NSPredicate(format: "label == %@", label)).allElementsBoundByAccessibilityElement
        guard live.count <= 1 else { XCTFail("The native completion Button must be unique"); return nil }
        guard let button = live.first, let bound = try? button.snapshot(),
              bound.elementType == target.elementType, bound.identifier == identifier, bound.label == label,
              bound.frame == target.frame, bound.isEnabled, button.isHittable else { return nil }
        return target.frame
    }
}
