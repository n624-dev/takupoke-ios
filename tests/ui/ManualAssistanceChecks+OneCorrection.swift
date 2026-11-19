import XCTest
import UIKit

extension ManualAssistanceChecks {
    func measuredStep<T>(_ name: String, _ body: () -> T) -> T {
        let start = ProcessInfo.processInfo.systemUptime
        print("TAKUPOKE-MANUAL-STEP start=\(name)")
        defer { print("TAKUPOKE-MANUAL-STEP end=\(name);seconds=\(ProcessInfo.processInfo.systemUptime-start)") }
        return body()
    }

    func prepareOneCorrection(_ key:String,_ input:XCUIElement,_ value:String) {
        inspectSource(key)
        XCTAssertFalse(visibleAcknowledgement(key).isSelected)
        assertSubmitEnabled(false)
        edit(input,value,id:key);acknowledge(key)
        assertSubmitEnabled(true)
        XCTAssertEqual(uniqueLabel("manual-fixture-type-size",in:observation),"standard")
        chooseFixtureMenuAction("表示サイズを変更")
        XCTAssertEqual(uniqueLabel("manual-fixture-type-size",in:observation),"expanded")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value);XCTAssertTrue(visibleAcknowledgement(key).isSelected)
        XCTAssertEqual(uniqueLabel("manual-fixture-revalidations",in:observation),"0")
        chooseFixtureMenuAction("同じ原本の状態を再確認")
        XCTAssertEqual(uniqueLabel("manual-fixture-revalidations",in:observation),"1")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value);XCTAssertTrue(visibleAcknowledgement(key).isSelected)
    }

    func requireEditorSurvivesBackground(_ key:String,_ input:XCUIElement,_ value:String,processBefore:String)->Bool {
        guard enterBackground() else { return false }
        app.activate()
        print("TAKUPOKE-MANUAL-APP-STATE after-activate=\(app.state.rawValue)")
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10),"App must survive background; no relaunch or draft reset")
        print("TAKUPOKE-MANUAL-APP-STATE foreground=\(app.state.rawValue)")
        guard let observedProcess=uniqueLabel("manual-process-launch",in:observation) else { return false }
        print("TAKUPOKE-MANUAL-PROCESS expected=\(processBefore);observed=\(observedProcess)")
        XCTAssertEqual(observedProcess,processBefore,"Background must preserve the original process; relaunch is not survival")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value);XCTAssertTrue(visibleAcknowledgement(key).isSelected)
        edit(input,value+"改",id:key);XCTAssertFalse(visibleAcknowledgement(key).isSelected)
        assertSubmitEnabled(false)
        XCTAssertTrue(recoveryList.images["manual-crop-"+key].exists)
        return true
    }

    func requireReviewSurvivesBackground(_ value:String,processBefore:String)->Bool {
        requireReview([value+"改"],comparable:false)
        guard enterBackground() else { return false }
        app.activate()
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10))
        XCTAssertEqual(uniqueLabel("manual-process-launch",in:observation),processBefore)
        requireReview([value+"改"],comparable:false)
        print("TAKUPOKE-MANUAL-REVIEW-BACKGROUND same-process;review-retained;preview=false")
        return true
    }

    func reeditAndReviewCorrection(_ key:String,_ input:XCUIElement,_ value:String) {
        // Reopening the editor retains literal input; a fresh edit clears ACK
        // and cannot reuse the previously validated correction review.
        tap("入力を見直す")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value+"改")
        edit(input,value+"再確認",id:key);XCTAssertFalse(visibleAcknowledgement(key).isSelected)
        assertSubmitEnabled(false);acknowledge(key);tapSubmit()
        requireReview([value+"再確認"],comparable:false)
        inspectSource(key)
    }

    func selectCorrectionFromPreview(cell:String,lesson:String,role:String) {
        let menuID = "recovery-correction-menu-"+cell+"-"+lesson
        // Hold the center of the verified, visible native text.
        let owner = visible(recoveryList.staticTexts[menuID], knownID: menuID)
        owner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 2)
        let names = ["subject":"科目","teacher":"教員","room":"教室"]
        let name = names[role]
        XCTAssertNotNil(name)
        guard let name else { return }
        // Require a real unique action with the visible label and native frame.
        tapPopupAction(name+"を訂正")
    }

    func selectHighConfidenceFieldsAndRequireThreeFieldLimit(_ subjectKey:String,subject:String) {
        let parts = subjectKey.split(separator:":",omittingEmptySubsequences:false)
        XCTAssertGreaterThanOrEqual(parts.count,3)
        guard parts.count >= 3 else { return }
        XCTAssertEqual(parts.last,"subject")
        let cell = parts.dropLast(2).joined(separator:":"), lesson = String(parts[parts.count-2])
        let teacherKey = cell+":"+lesson+":teacher", roomKey = cell+":"+lesson+":room"
        let teacher = "架空選択教員", room = "架空選択室R7"
        openReviewPreview();requirePreview()
        selectCorrectionFromPreview(cell:cell,lesson:lesson,role:"teacher")
        guard let ids=fieldIDs(expectedCount:2) else { return }
        XCTAssertEqual(Set(ids),Set([subjectKey,teacherKey]))
        XCTAssertEqual(visible(input(subjectKey),knownID:"manual-value-"+subjectKey).value as? String,subject)
        for key in [subjectKey,teacherKey] { XCTAssertFalse(visibleAcknowledgement(key).isSelected) }
        assertSubmitEnabled(false)
        inspectSource(teacherKey);edit(input(teacherKey),teacher,id:teacherKey)
        acknowledge(subjectKey);assertSubmitEnabled(false);acknowledge(teacherKey);assertSubmitEnabled(true)
        tapSubmit();requireReview([subject,teacher],comparable:false)
        openReviewPreview();requirePreview()
        selectCorrectionFromPreview(cell:cell,lesson:lesson,role:"room")
        guard let threeIDs=fieldIDs(expectedCount:3) else { return }
        XCTAssertEqual(Set(threeIDs),Set([subjectKey,teacherKey,roomKey]))
        XCTAssertEqual(visible(input(subjectKey),knownID:"manual-value-"+subjectKey).value as? String,subject)
        XCTAssertEqual(visible(input(teacherKey),knownID:"manual-value-"+teacherKey).value as? String,teacher)
        for key in [subjectKey,teacherKey,roomKey] { XCTAssertFalse(visibleAcknowledgement(key).isSelected) }
        inspectSource(roomKey);edit(input(roomKey),room,id:roomKey)
        acknowledge(subjectKey);assertSubmitEnabled(false)
        acknowledge(teacherKey);assertSubmitEnabled(false)
        acknowledge(roomKey);assertSubmitEnabled(true)
        tapSubmit();requireReview([subject,teacher,room],comparable:false)
        openReviewPreview();requirePreview()
        let current = "recovery-correction-menu-"+cell+"-"+lesson
        // Preview starts at its header; offscreen lesson rows are virtualized.
        // Reveal an actual other lesson before inspecting or operating its menu.
        let otherMenus = recoveryList.staticTexts.matching(NSPredicate(
            format:"identifier BEGINSWITH %@ AND identifier != %@","recovery-correction-menu-",current))
        let next = visible(otherMenus.firstMatch,alternatives:otherMenus)
        let nextID = next.identifier
        XCTAssertTrue(nextID.hasPrefix("recovery-correction-menu-"),app.debugDescription)
        XCTAssertNotEqual(nextID,current,app.debugDescription)
        let suffix = String(nextID.dropFirst("recovery-correction-menu-".count))
        let divide = suffix.lastIndex(of:"-")
        XCTAssertNotNil(divide)
        guard let divide else { return }
        selectCorrectionFromPreview(cell:String(suffix[..<divide]),lesson:String(suffix[suffix.index(after:divide)...]),role:"room")
        // The menu was in a lesson row; the status is at the top of the List.
        // Reveal it with the existing bounded native navigation before checking.
        let status=app.collectionViews["manual-recovery-list"].staticTexts["manual-status"]
        XCTAssertEqual(visible(status,towardTop:true,knownID:"manual-status").label,
            "訂正できる本文は、確認が必要な項目を含め合計3項目までです。")
        XCTAssertTrue(recoveryList.staticTexts["訂正できる本文は、確認が必要な項目を含め合計3項目までです。"].waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        requirePreview()
        XCTAssertTrue(recoveryList.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        XCTAssertFalse(observation.staticTexts["manual-field-ids"].exists)
        persistAndRequireProof([subjectKey:subject,teacherKey:teacher,roomKey:room])
    }

    func persistAndRequireProof(_ expected:[String:String]) {
        requireLastGood(in:observation)
        let values=expected.sorted { $0.key < $1.key }.map { $0.key+"="+$0.value }.joined(separator:"|")
        let proof="adopted=\(expected.count);valid=true;values="+values
        tap("この資料全体の結果を使用")
        XCTAssertTrue(recoveryList.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertEqual(uniqueLabel("manual-persisted-proof",in:observation),proof)
        guard terminateCurrentFixture() else { return };app.launchArguments=["--manual-ui","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]
        guard launchApplicationOnce() else { return }
        let root=rootObservation
        XCTAssertTrue(root.staticTexts["manual-persisted-proof"].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertEqual(uniqueLabel("manual-persisted-proof",in:root),proof)
    }
}
