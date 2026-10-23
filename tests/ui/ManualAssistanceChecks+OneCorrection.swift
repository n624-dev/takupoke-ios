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
        XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"0")
        assertSubmitEnabled(false)
        edit(input,value,id:key);acknowledge(key)
        assertSubmitEnabled(true)
        tap("架空検証");tap("表示サイズを変更")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value);XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"1")
        tap("架空検証");tap("同じ原本の状態を再確認")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value);XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"1")
    }

    func requireEditorSurvivesBackground(_ key:String,_ input:XCUIElement,_ value:String,processBefore:String)->Bool {
        guard enterBackground() else { return false }
        app.activate()
        print("TAKUPOKE-MANUAL-APP-STATE after-activate=\(app.state.rawValue)")
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10),"App must survive background; no relaunch or draft reset")
        print("TAKUPOKE-MANUAL-APP-STATE foreground=\(app.state.rawValue)")
        let observedProcess=app.staticTexts["manual-process-launch"].firstMatch.label
        print("TAKUPOKE-MANUAL-PROCESS expected=\(processBefore);observed=\(observedProcess)")
        XCTAssertEqual(observedProcess,processBefore,"Background must preserve the original process; relaunch is not survival")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value);XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"1")
        edit(input,value+"改",id:key);XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"0")
        assertSubmitEnabled(false)
        XCTAssertTrue(app.images.matching(NSPredicate(format:"identifier BEGINSWITH 'manual-crop-'")).firstMatch.exists)
        return true
    }

    func requireReviewSurvivesBackground(_ value:String,processBefore:String)->Bool {
        requireReview([value+"改"],comparable:false)
        guard enterBackground() else { return false }
        app.activate()
        XCTAssertTrue(app.wait(for:.runningForeground,timeout:10))
        XCTAssertEqual(app.staticTexts["manual-process-launch"].firstMatch.label,processBefore)
        requireReview([value+"改"],comparable:false)
        print("TAKUPOKE-MANUAL-REVIEW-BACKGROUND same-process;review-retained;preview=false")
        return true
    }

    func reeditAndReviewCorrection(_ key:String,_ input:XCUIElement,_ value:String) {
        // Reopening the editor retains literal input; a fresh edit clears ACK
        // and cannot reuse the previously validated correction review.
        tap("入力を見直す")
        XCTAssertEqual(visible(input,knownID:"manual-value-"+key).value as? String,value+"改")
        edit(input,value+"再確認",id:key);XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"0")
        assertSubmitEnabled(false);acknowledge(key);visible(submit,knownID:"manual-submit").tap()
        requireReview([value+"再確認"],comparable:false)
        inspectSource(key)
    }

    func selectCorrectionFromPreview(cell:String,lesson:String,role:String) {
        let menu = app.descendants(matching:.any)["recovery-correction-menu-"+cell+"-"+lesson]
        visible(menu).press(forDuration:0.6)
        let names = ["subject":"科目","teacher":"教員","room":"教室"]
        let name = names[role]
        XCTAssertNotNil(name)
        guard let name else { return }
        // Require a real unique action with the visible label and native frame.
        let label = name+"を訂正", choice = app.buttons[label]
        XCTAssertTrue(choice.waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        let buttons = app.buttons.matching(NSPredicate(format:"label == %@",label)).allElementsBoundByIndex
        XCTAssertEqual(buttons.count,1,app.debugDescription)
        guard buttons.count == 1 else { return }
        XCTAssertTrue(ManualScrollNavigation.usable(buttons[0].frame) && buttons[0].isEnabled && buttons[0].isHittable,app.debugDescription)
        buttons[0].tap()
    }

    func selectHighConfidenceFieldsAndRequireThreeFieldLimit(_ subjectKey:String,subject:String) {
        let parts = subjectKey.split(separator:":",omittingEmptySubsequences:false)
        XCTAssertGreaterThanOrEqual(parts.count,3)
        guard parts.count >= 3 else { return }
        XCTAssertEqual(parts.last,"subject")
        let cell = parts.dropLast(2).joined(separator:":"), lesson = String(parts[parts.count-2])
        let teacherKey = cell+":"+lesson+":teacher", roomKey = cell+":"+lesson+":room"
        let teacher = "架空選択教員", room = "架空選択室R7"
        tap("訂正と変更を確認して資料全体へ");requirePreview()
        selectCorrectionFromPreview(cell:cell,lesson:lesson,role:"teacher")
        XCTAssertTrue(fieldsExist(),app.debugDescription)
        XCTAssertEqual(Set(fieldIDs),Set([subjectKey,teacherKey]))
        XCTAssertEqual(visible(input(subjectKey)).value as? String,subject)
        for key in [subjectKey,teacherKey] { XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"0") }
        assertSubmitEnabled(false)
        inspectSource(teacherKey);edit(input(teacherKey),teacher,id:teacherKey)
        acknowledge(subjectKey);assertSubmitEnabled(false);acknowledge(teacherKey);assertSubmitEnabled(true)
        visible(submit,knownID:"manual-submit").tap();requireReview([subject,teacher],comparable:false)
        tap("訂正と変更を確認して資料全体へ");requirePreview()
        selectCorrectionFromPreview(cell:cell,lesson:lesson,role:"room")
        XCTAssertTrue(fieldsExist(),app.debugDescription)
        XCTAssertEqual(Set(fieldIDs),Set([subjectKey,teacherKey,roomKey]))
        XCTAssertEqual(visible(input(subjectKey)).value as? String,subject)
        XCTAssertEqual(visible(input(teacherKey)).value as? String,teacher)
        for key in [subjectKey,teacherKey,roomKey] { XCTAssertEqual(visible(ack(key),knownID:"manual-ack-"+key).value as? String,"0") }
        inspectSource(roomKey);edit(input(roomKey),room,id:roomKey)
        acknowledge(subjectKey);assertSubmitEnabled(false)
        acknowledge(teacherKey);assertSubmitEnabled(false)
        acknowledge(roomKey);assertSubmitEnabled(true)
        visible(submit,knownID:"manual-submit").tap();requireReview([subject,teacher,room],comparable:false)
        tap("訂正と変更を確認して資料全体へ");requirePreview()
        let current = "recovery-correction-menu-"+cell+"-"+lesson
        // Preview starts at its header; offscreen lesson rows are virtualized.
        // Reveal an actual other lesson before inspecting or operating its menu.
        let otherMenus = app.staticTexts.matching(NSPredicate(
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
        _=visible(app.staticTexts["訂正できる本文は、確認が必要な項目を含め合計3項目までです。"],towardTop:true)
        XCTAssertTrue(app.staticTexts["訂正できる本文は、確認が必要な項目を含め合計3項目までです。"].waitForExistence(timeout:nativeStateTimeout),app.debugDescription)
        requirePreview()
        XCTAssertTrue(app.staticTexts["原本を確認して入力した3項目を含みます。"].exists)
        XCTAssertFalse(app.staticTexts["manual-field-ids"].exists)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
    }

    func adoptAndRequirePersistedCorrection() {
        tap("訂正と変更を確認して資料全体へ")
        requirePreview()
        persistAndRequireProof("adopted=1;valid=true")
    }

    func adoptAndRequirePersistedSelectedCorrections() {
        requirePreview()
        persistAndRequireProof("adopted=3;valid=true")
    }

    func persistAndRequireProof(_ proof:String) {
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains("lastgood-preserved"))
        tap("この資料全体の結果を使用")
        XCTAssertTrue(app.staticTexts["復旧結果を採用しました。"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains(proof))
        app.terminate();app.launchArguments=["--manual-ui","-AppleLanguages","(ja)","-AppleLocale","ja_JP"]
        guard launchApplicationOnce() else { return }
        // The fixture probe also needs an app-root copy to inspect persisted results without reopening a recovery draft.
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertTrue(app.staticTexts["manual-persisted-proof"].firstMatch.label.contains(proof))
    }
}
