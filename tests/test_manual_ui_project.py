import sys
import json
import importlib.util
from pathlib import Path
import unittest
import re
import os
import shutil
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from app_test_project import instrument_recovery_fixture
from ui_test_manifest import manual_check_source

spec=importlib.util.spec_from_file_location("manual_ui_project",ROOT/"tools/manual_ui_project.py")
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

def generated_manual_coordinator(source):
    return module.coordinator(instrument_recovery_fixture(source))

class ManualUIProjectTests(unittest.TestCase):
    def test_missing_or_duplicate_anchor_fails_closed(self):
        for text in ("", "marker marker"):
            with self.assertRaises(ValueError): module.once(text,"marker","new")

    def test_binding_diagnostics_are_opt_in_hashed_and_explicitly_truncated(self):
        fixture=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        event=fixture.split('    static func event(',1)[1].split('    static var enabled:',1)[0]
        self.assertLess(event.index('guard enabled else { return }'),event.index('eventCount += 1'))
        self.assertIn('guard eventCount <= 64 else',event)
        self.assertIn('if eventCount == 65',event)
        self.assertIn('previous+"limited=64\\n"',event)
        self.assertIn('SHA256.hash(data:Data(text.utf8))',event)
        self.assertNotIn('old=\\(old)',event)
        self.assertNotIn('new=\\(new)',event)
        checks=manual_check_source()
        self.assertIn('XCTAssertEqual(uniqueLabel("manual-process-launch",in:observation),processBefore',checks)
        self.assertIn('XCTAssertEqual(header.label,"採用する資料全体",app.debugDescription)',checks)

    def test_editor_uses_physical_clear_and_checks_full_replacement(self):
        checks=manual_check_source()
        edit=checks.split('    func edit(',1)[1].split('    func editStage(',1)[0]
        self.assertLess(edit.index('let target=visible(clear,knownID:'),edit.index('target.tap()'))
        self.assertNotIn('target.waitForExistence',edit)
        self.assertIn('guard ManualScrollNavigation.usable(clearFrame),target.isEnabled,target.isHittable',edit)
        self.assertLess(edit.index('let target=visible(clear,knownID:'),edit.index('let e=editors[0]'))
        self.assertNotIn('clear.waitForExistence',edit)
        self.assertNotIn('visible(original',edit)
        self.assertLess(edit.index('target.tap()'),edit.index('e.typeText(value)'))
        self.assertLess(edit.index('guard cleared == .completed'),edit.index('let e=editors[0]'))
        self.assertIn('guard editors.count==1',edit)
        self.assertIn('.matching(identifier:"manual-value-"+id).allElementsBoundByIndex',edit)
        self.assertIn('guard current.count==1',edit)
        self.assertIn('text.isEmpty || text == "PDFに記載された全文"',edit)
        self.assertIn('Native clear must remove the entire previous input',edit)
        self.assertIn('Clearing text must revoke prior acknowledgement',edit)
        self.assertIn('let clearedAcknowledgements=recoveryList.buttons.matching(identifier:"manual-ack-"+id).allElementsBoundByAccessibilityElement',edit)
        self.assertIn('guard clearedAcknowledgements.count==1',edit)
        self.assertIn('XCTAssertFalse(clearedAcknowledgements[0].isSelected',edit)
        self.assertNotIn('visibleAcknowledgement(id)',edit)
        self.assertLess(edit.index('guard cleared == .completed'),edit.index('let clearedAcknowledgements='))
        self.assertLess(edit.index('Clearing text must revoke prior acknowledgement'),edit.index('e.typeText(value)'))
        self.assertIn('The physical edit must replace the full previous input',edit)
        self.assertIn('e.typeText(value)',edit)
        self.assertNotIn('sleep(',edit)
        self.assertIn('editStage("after-clear-focus",id:id)',edit)
        diagnostic=checks.split('    func editStage(',1)[1].split('    func enterBackground()',1)[0]
        for query in ('e.exists','e.isHittable','e.frame','e.debugDescription','observedKeyboardFrame()'):
            self.assertNotIn(query,diagnostic)
        background=(ROOT/'tests/ui/ManualAssistanceChecks+Lifecycle.swift').read_text(encoding='utf-8').split('func enterBackground()',1)[1]
        self.assertEqual(background.count('XCUIDevice.shared.press(.home)'),1)
        self.assertIn('return state == .runningBackground || state == .runningBackgroundSuspended\n        },object:nil)',background)
        self.assertIn('XCTWaiter.wait(for:[background],timeout:nativeStateTimeout) == .completed',background)
        for query in ('app.debugDescription','app.frame','app.activate()','app.launch()'):
            self.assertNotIn(query,background)
        self.assertNotIn('visible(e).tap()',edit)
        self.assertIn('TAKUPOKE-MANUAL-EDIT stage=',checks)
        self.assertLess(edit.index('e.typeText(value)'), edit.index('guard finishManualEditing()'))
        self.assertLess(edit.index('guard finishManualEditing()'),edit.index('self.app.keyboards.allElementsBoundByIndex.isEmpty'))
        completion=edit.split('    private func finishManualEditing()',1)[1].split('    private func observeManualEditCompletion(',1)[0]
        self.assertIn('systemUptime + nativeStateTimeout', completion)
        self.assertIn('XCTWaiter.wait(for: [ready], timeout: remaining)', completion)
        self.assertIn('app.state == .runningForeground', completion)
        self.assertIn('return ambiguous || targetFrame != nil', completion)
        self.assertIn('!ambiguous, let targetFrame', completion)
        self.assertEqual(completion.count('NativeTestContacts.send('), 1)
        self.assertIn('start: center, end: center, duration: 0.1, pauseAfterLift: 0', completion)
        self.assertNotIn('.tap()', completion)
        view=(ROOT/'Takupoke/PDFRecoveryView.swift').read_text(encoding='utf-8')
        toolbar=view.split('            .toolbar {',1)[1].split('            .sheet(',1)[0]
        self.assertIn('if editingManualField != nil',toolbar)
        self.assertIn('ToolbarItem(placement:.confirmationAction)',toolbar)
        self.assertIn('Button("完了") { editingManualField = nil }',toolbar)
        self.assertNotIn('placement:.keyboard',toolbar)
        self.assertNotIn('manualAcknowledged',toolbar)

    def test_manual_case_filter_is_exact_and_default_keeps_whole_suite(self):
        runner=(ROOT/"tools/test-manual-ui.sh").read_text(encoding="utf-8")
        prefix=runner.split('scratch_dir=',1)[0]
        names=['testChangedOriginalCannotSubmitOrReplaceLastGood',
               'testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground',
               'testThreeFieldsRequireEachAcknowledgementAndFourRefuses',
               'testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch']
        for selected in ['']+names:
            env=os.environ.copy();env['TKPK_MANUAL_CASE']=selected
            result=subprocess.run(['bash','-c',prefix+'\nprintf "%s\\n" "$only_testing"'],
                                  env=env,text=True,capture_output=True)
            self.assertEqual(result.returncode,0,result.stderr)
            expected='-only-testing:PickerTapChecks/ManualAssistanceChecks'+('/'+selected if selected else '')
            self.assertEqual(result.stdout.strip(),expected)
        for selected in ['testUnknown',names[0]+';printf BAD','ManualAssistanceChecks','../ApplicationChecks']:
            env=os.environ.copy();env['TKPK_MANUAL_CASE']=selected
            result=subprocess.run(['bash','-c',prefix+'\nprintf "%s\\n" "$only_testing"'],
                                  env=env,text=True,capture_output=True)
            self.assertEqual(result.returncode,2)
            self.assertEqual(result.stdout,'')

    def test_completion_guard_rejects_missing_duplicate_skipped_failed_or_other_case(self):
        runner=(ROOT/"tools/test-manual-ui.sh").read_text(encoding="utf-8")
        program=runner.split('python3 - "$scratch_dir/manual-ui.log" "$manual_case" "$simulator_id" "$runtime" <<\'PY\'\n',1)[1].split('\nPY',1)[0]
        names=['testChangedOriginalCannotSubmitOrReplaceLastGood',
               'testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground',
               'testThreeFieldsRequireEachAcknowledgementAndFourRefuses',
               'testSelectedHighConfidenceFieldsRetainInputsRejectFourthAndSurviveRelaunch']
        def line(name,status='passed'):
            identity={'case':'-[PickerTapChecks.ManualAssistanceChecks '+name+']',
                      'udid':'00000000-0000-0000-0000-000000000001','runtime':'27.0.0',
                      'simulatorCompileTarget':True,'pid':123}
            return ('TAKUPOKE_UI_EXECUTION_IDENTITY '+json.dumps(identity)+'\n'+
                    "Test Case '-[PickerTapChecks.ManualAssistanceChecks "+name+"]' "+status+" (1.0 seconds).\n")
        with tempfile.TemporaryDirectory() as scratch:
            log=Path(scratch)/'completed.log'
            def run(selected,content):
                log.write_text(content,encoding='utf-8')
                return subprocess.run(['python3','-c',program,str(log),selected,
                    '00000000-0000-0000-0000-000000000001','com.apple.CoreSimulator.SimRuntime.iOS-27-0'],
                    capture_output=True,text=True,cwd=ROOT)
            for name in names:
                self.assertEqual(run(name,line(name)).returncode,0)
            whole=''.join(line(name) for name in names)
            self.assertEqual(run('',whole).returncode,0)
            negatives=[('', ''.join(line(name) for name in names[:-1])),(names[0],''),(names[0],line(names[0])*2),
                       (names[0],line(names[0],'skipped')),(names[0],line(names[0],'failed')),
                       (names[0],line(names[1])),(names[0],whole),('',line(names[0])),
                       ('',whole+line(names[0])),('',whole+line('testUnknown')),('testUnknown',whole)]
            for selected,content in negatives:
                self.assertNotEqual(run(selected,content).returncode,0,(selected,content))

    def test_coordinator_preserves_actual_submit_adopt_and_source_guards(self):
        original=(ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        changed=generated_manual_coordinator(original)
        self.assertIn('try RecoveryConversion.verifyFile(source',changed)
        self.assertIn('acknowledged == Set(draft.fields.map',changed)
        self.assertIn('selectedSourceIsCurrent',changed)
        self.assertIn('ApplicationData.shared.materials.adoptRecovery(preview)',changed)
        self.assertEqual(changed.count('if SimulatorManualFixture.enabled'),5)
        self.assertEqual(changed.count('            cancel(); running = true'),2)
        self.assertIn('func cancel() {\n        fixtureFailure = nil',changed)
        submit=changed.split('func submitManual(',1)[1].split('func selectManualCorrection(',1)[0]
        self.assertLess(submit.index('manual-submit-rejected'),submit.index('manual-submit-accepted'))
        self.assertLess(submit.index('manual-submit-accepted'),submit.index('running = true'))
        self.assertIn('if SimulatorManualFixture.enabled { SimulatorManualFixture.trace("stage=manual-preview-ready") }',changed)
        self.assertIn('if SimulatorManualFixture.enabled { SimulatorManualFixture.failed(error) }',changed)

    def test_view_identifiers_do_not_precheck_or_bypass_existing_disabled_gate(self):
        original=(ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        changed=module.view(original)
        self.assertIn('manualAcknowledged[field.id] ?? false',changed)
        self.assertIn('RecoveryManualInput.update(',changed)
        self.assertIn('coordinator.submitManual(',changed)
        self.assertLess(changed.index('manual-submit-action'),changed.index('coordinator.submitManual('))
        self.assertIn('draft.fields.contains',changed)
        self.assertIn('coordinator.suspendForInactivity()',changed)
        self.assertIn('models.cancel()',changed)
        self.assertEqual(changed.count('accessibilityIdentifier("manual-submit")'),1)
        self.assertEqual(changed.count('accessibilityIdentifier("manual-review-submit")'),1)
        self.assertEqual(changed.count('Text(coordinator.status).accessibilityIdentifier("manual-status")'),1)
        acknowledgement=changed.split('Text("原本と一致することを確認")',1)[1].split('.disabled(',1)[0]
        self.assertLess(acknowledgement.index('.frame(minHeight: 44)'),acknowledgement.index('.contentShape(Rectangle())'))
        self.assertIn('.accessibilityAddTraits(acknowledged ? .isSelected : [])',acknowledgement)
        self.assertIn('.accessibilityIdentifier("manual-ack-" + field.id)',acknowledgement)
        checks=manual_check_source()
        self.assertEqual(checks.count('guard terminateCurrentFixture() else { return };'),3)
        terminate=checks.split('    func terminateCurrentFixture()',1)[1].split('    func launch(',1)[0]
        self.assertEqual(terminate.count('app.terminate()'),1)
        self.assertIn('app.wait(for:.runningForeground,timeout:nativeStateTimeout)',terminate)
        self.assertIn('return false',terminate)
        self.assertLess(terminate.index('app.wait('),terminate.index('app.terminate()'))
        self.assertEqual(checks.count('app.terminate()'),1)
        self.assertIn('"--fixture-year-input-trace"',checks)
        self.assertEqual(checks.count('tap("訂正と変更を確認して資料全体へ"'),1)
        self.assertIn('tap("訂正と変更を確認して資料全体へ",knownID:"manual-review-submit")',checks)
        self.assertEqual(checks.count('openReviewPreview()')-1,6)
        self.assertIn('visible(button,knownID:knownID,buttonLabel:title,ownerID:ownerID,barTitle:barTitle).tap()',checks)
        self.assertIn('requireLastGood(in:rootObservation)',checks)
        self.assertIn('XCTAssertEqual(uniqueLabel("manual-persisted-proof",in:root),proof)',checks)
        self.assertNotIn('app.staticTexts["manual-persisted-proof"]',checks)

    def test_review_readiness_measures_actual_coordinator_state(self):
        changed=module.view((ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8"))
        self.assertEqual(changed.count('.accessibilityIdentifier("manual-observation")'),1)
        self.assertEqual(changed.count('.background(alignment: .topLeading) {\n                if SimulatorManualFixture.enabled'),1)
        self.assertNotIn('.overlay(alignment: .topLeading) {\n                if SimulatorManualFixture.enabled',changed)
        self.assertIn('.accessibilityElement(children:.contain)\n                    .accessibilityIdentifier("manual-observation")\n                    .allowsHitTesting(false)',changed)
        checks=manual_check_source()
        coordinator=checks.split('    private func coordinatorState(',1)[1].split('    func requireReview(',1)[0]
        self.assertEqual(coordinator.count('app.snapshot()'),1)
        self.assertIn('$0.elementType == .other && $0.identifier == "manual-observation"',coordinator)
        self.assertIn('$0.elementType == .staticText && $0.identifier == "manual-coordinator-state"',coordinator)
        self.assertNotIn('allElementsBoundByAccessibilityElement',coordinator)
        self.assertEqual(checks.count('self.coordinatorState(ambiguous:'),2)
        scoped='.otherElements["manual-observation"].staticTexts'
        self.assertEqual(checks.count(scoped+'.matching(identifier:"manual-input-state")'),1)
        self.assertNotIn('app.staticTexts["manual-input-state"]',checks)
        state=next(line for line in changed.splitlines() if 'Text("preview=' in line)
        self.assertIn('review=\\(coordinator.manualReview != nil)',state)
        self.assertIn('preview=\\(coordinator.preview != nil)',state)
        self.assertEqual(changed.count('accessibilityIdentifier("manual-coordinator-state")'),1)

    def test_background_revalidation_proof_is_generated_after_the_real_file_and_identity_checks(self):
        source = (ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        generated = generated_manual_coordinator(source)
        self.assertNotIn('manualQAPreviewRevalidations', source)
        self.assertIn('running = false; fixtureFailure = "架空資料', generated)
        resume = generated.split('    func resumeAfterInactivity()', 1)[1].split('    func invalidateManualIfSourceChanged()', 1)[0]
        before = 'guard preview?.id == candidate.id else { throw CancellationError() }'
        self.assertLess(resume.index('try RecoveryConversion.verifyFile('), resume.index(before))
        self.assertLess(resume.index(before), resume.index('manualQAPreviewRevalidations += 1'))
        self.assertEqual(generated.count('manualQAPreviewRevalidations += 1'), 1)
        checks = manual_check_source()
        case = checks.split('measuredStep("preview-background"', 1)[1].split('measuredStep("save-and-relaunch"', 1)[0]
        self.assertLess(case.index('observedPreviewRevalidations()'), case.index('enterBackground()'))
        self.assertIn('requirePreview(revalidatedAfter: revalidations)', case)

    def test_composed_recovery_fixtures_write_only_the_generated_failure_property(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required to verify generated failure assignments")
        original = (ROOT / "Takupoke/PDFRecoveryCoordinator.swift").read_text()
        general = instrument_recovery_fixture(original)
        manual = generated_manual_coordinator(original)
        self.assertNotIn("fixtureFailure", original)
        for source, writers in [(general, 1), (manual, 2)]:
            self.assertNotRegex(source, r"(?m)(?:;|^\s*)(?:self\.)?failure\s*=")
            declaration = next(line for line in source.splitlines() if "@Published private var fixtureFailure" in line)
            reader = next(line for line in source.splitlines() if "var failure: String?" in line)
            clearer = source.split("    func cancel() {\n", 1)[1].splitlines()[0]
            assignments = [line for line in source.splitlines() if "running = false; fixtureFailure = " in line]
            self.assertEqual(len(assignments), writers)
            methods = "\n".join(f"    func probe{index}(_ error: Error) {{\n{line}\n    }}"
                                for index, line in enumerate(assignments))
            stub = f"""import Foundation
@propertyWrapper struct Published<Value> {{ var wrappedValue: Value }}
struct RecoveryFailure {{ let message: String }}
final class Generated {{
    var failureReason: RecoveryFailure?
    var running = true
{declaration}
{reader}
    func cancel() {{
{clearer}
    }}
{methods}
}}
"""
            with tempfile.TemporaryDirectory(prefix="takupoke-recovery-generation-") as scratch:
                path = Path(scratch)
                (path / "GeneratedCoordinator.swift").write_text(source)
                (path / "GeneratedAssignments.swift").write_text(stub)
                subprocess.run([compiler, "-frontend", "-parse", str(path / "GeneratedCoordinator.swift")],
                               check=True, timeout=30)
                subprocess.run([compiler, "-typecheck", "-module-cache-path", str(path / "modules"),
                                str(path / "GeneratedAssignments.swift")], check=True, timeout=30)

    def test_manual_submit_sends_one_contact_to_the_observed_button(self):
        source = manual_check_source()
        submit = source.split("    func tapSubmit()", 1)[1].split("    func assertSubmitEnabled", 1)[0]
        self.assertIn('knownID: "manual-submit", buttonLabel: "訂正箇所と前回からの変更を確認"', submit)
        self.assertIn("appFrame.contains(observed.frame)", submit)
        self.assertIn("app.state == .runningForeground", submit)
        self.assertIn("CGPoint(x: observed.frame.midX, y: observed.frame.midY)", submit)
        self.assertEqual(submit.count("NativeTestContacts.send("), 1)
        self.assertIn("start: center, end: center, duration: 0.1, pauseAfterLift: 0", submit)
        self.assertNotIn(".tap()", submit)
        self.assertEqual(submit.count("app.snapshot()"), 1)

    def test_manual_snapshots_require_unique_visible_enabled_native_buttons(self):
        compiler = os.environ.get("SWIFTC") or shutil.which("swiftc")
        if not compiler:
            self.skipTest("Swift required for the native control geometry probe")
        source = manual_check_source()
        start = "    private func observeVisibleManualSubmit("
        helper = start + source.split(start, 1)[1].split("    func assertSubmitEnabled", 1)[0]
        finish_start = "    private func observeManualEditCompletion("
        finish = finish_start + source.split(finish_start, 1)[1].split("\n}", 1)[0]
        program = r'''
import Foundation
enum Element { case application, collectionView, navigationBar, keyboard, button, other }
struct Node {
    let elementType: Element
    let identifier: String
    var frame: CGRect
    var label = ""
    var isEnabled = true
    var isSelected = false
    var children: [Node] = []
}
struct ManualButtonObservation { let frame: CGRect; let viewport: CGRect; let isSelected: Bool }
struct ManualScrollNavigation { static func usable(_ rect: CGRect) -> Bool { !rect.isEmpty && !rect.isInfinite } }
var failures = 0
func XCTFail(_ reason: String) { failures += 1 }
struct App {
    let root: Node
    var navigationBars = NavigationQuery(byTitle: [:])
    func snapshot() throws -> Node { root }
}
struct Control { let node: Node; var isHittable = true; func snapshot() throws -> Node { node } }
struct ControlQuery {
    let allElementsBoundByAccessibilityElement: [Control]
    func matching(identifier: String) -> ControlQuery {
        .init(allElementsBoundByAccessibilityElement: allElementsBoundByAccessibilityElement.filter { $0.node.identifier == identifier })
    }
}
struct List { let buttons: ControlQuery }
struct NavigationQuery {
    let byTitle: [String: [Control]]
    var selected: String? = nil
    func matching(identifier: String) -> NavigationQuery { .init(byTitle: byTitle, selected: identifier) }
    func descendants(matching type: Element) -> ControlQuery {
        let matches = selected.flatMap { byTitle[$0] } ?? []
        return .init(allElementsBoundByAccessibilityElement: matches.filter { $0.node.elementType == type })
    }
}
struct Test {
    let app: App
    let recoveryList: List
    func snapshotNodes(in root: Node) -> [Node]? { [root] + root.children.flatMap { snapshotNodes(in: $0) ?? [] } }
    func observed() -> ManualButtonObservation? {
        var appFrame = CGRect.null
        let result = observeVisibleManualSubmit(appFrame: &appFrame)
        precondition(result == nil || appFrame == app.root.frame)
        return result
    }
    func editCompletion(ambiguous expectedAmbiguity: Bool = false) -> CGRect? {
        var ambiguous = false
        var observation = ""
        let frame = observeManualEditCompletion(ambiguous: &ambiguous, observation: &observation)
        precondition(ambiguous == expectedAmbiguity)
        return frame
    }
HELPER
FINISH
}
let appFrame = CGRect(x: 0, y: 0, width: 393, height: 852)
let button = Node(elementType: .button, identifier: "manual-submit", frame: .init(x: 16, y: 700, width: 360, height: 100),
                  label: "訂正箇所と前回からの変更を確認")
func view(_ buttons: [Node], keyboard: CGRect? = nil, hittable: Bool = true, moved: Bool = false) -> Test {
    let list = Node(elementType: .collectionView, identifier: "manual-recovery-list", frame: appFrame, children: buttons)
    let bar = Node(elementType: .navigationBar, identifier: "時間割の復旧", frame: .init(x: 0, y: 50, width: 393, height: 79))
    var screens = [list, bar]
    if let keyboard { screens.append(Node(elementType: .keyboard, identifier: "fictional-keyboard", frame: keyboard)) }
    let bound = buttons.map { button -> Control in
        var node = button
        if moved { node.frame = node.frame.offsetBy(dx: 0, dy: 5) }
        return Control(node: node, isHittable: hittable)
    }
    return Test(app: App(root: Node(elementType: .application, identifier: "fictional", frame: appFrame, children: screens)),
                recoveryList: List(buttons: ControlQuery(allElementsBoundByAccessibilityElement: bound)))
}
precondition(view([button]).observed()?.frame == button.frame)
precondition(view([button], keyboard: .init(x: 0, y: 600, width: 393, height: 252)).observed() == nil)
precondition(view([button], keyboard: .init(x: 0, y: 850, width: 0, height: 0)).observed() == nil && failures == 1)
precondition(view([button], hittable: false).observed() == nil)
precondition(view([button], moved: true).observed() == nil)
var disabled = button
disabled.isEnabled = false
precondition(view([disabled]).observed() == nil)
disabled.isEnabled = true
disabled.label = "架空の別操作"
precondition(view([disabled]).observed() == nil)
precondition(view([button, button]).observed() == nil && failures == 2)
var done = Node(elementType: .button, identifier: "manual-edit-done",
                frame: .init(x: 320, y: 60, width: 48, height: 44), label: "完了")
func editor(_ candidates: [Node], live: [Control], extraBar: [Node]? = nil, foreign: [Control] = []) -> Test {
    let title = "時間割の復旧"
    func bar(_ children: [Node]) -> Node {
        Node(elementType: .navigationBar, identifier: title, frame: .init(x: 0, y: 50, width: 393, height: 79), children: children)
    }
    let list = List(buttons: ControlQuery(allElementsBoundByAccessibilityElement: live))
    let bars = [bar(candidates)] + (extraBar.map { [bar($0)] } ?? [])
    let root = Node(elementType: .application, identifier: "fictional", frame: appFrame, children: bars)
    return Test(app: App(root: root, navigationBars: NavigationQuery(byTitle: [title: live, "別の画面": foreign])),
                recoveryList: list)
}
let live = Control(node: done)
let wrapper = Node(elementType: .other, identifier: "manual-edit-done", frame: done.frame, children: [done])
precondition(editor([done], live: [live]).editCompletion() == done.frame)
precondition(editor([wrapper], live: [live], extraBar: []).editCompletion() == done.frame)
precondition(editor([done], live: [], foreign: [live]).editCompletion() == nil)
precondition(editor([], live: [live]).editCompletion() == nil)
precondition(editor([done], live: []).editCompletion() == nil)
precondition(editor([done], live: [Control(node: done, isHittable: false)]).editCompletion() == nil)
precondition(editor([done, done], live: [live]).editCompletion(ambiguous: true) == nil)
precondition(editor([done], live: [live, live]).editCompletion(ambiguous: true) == nil)
precondition(editor([done], live: [live], extraBar: [done]).editCompletion(ambiguous: true) == nil)
done.frame.origin.x -= 5
precondition(editor([done], live: [live]).editCompletion() == nil)
done.frame = live.node.frame
done.frame.origin.y = 95
precondition(editor([done], live: [live]).editCompletion() == nil)
done.frame = live.node.frame
done.isEnabled = false
precondition(editor([done], live: [live]).editCompletion() == nil)
done.isEnabled = true
done.label = "架空の別操作"
precondition(editor([done], live: [live]).editCompletion() == nil)
precondition(editor([live.node], live: [Control(node: done)]).editCompletion() == nil)
precondition(editor([live.node], live: [live, Control(node: done)]).editCompletion(ambiguous: true) == nil)
'''.replace("HELPER", helper).replace("FINISH", finish)
        with tempfile.TemporaryDirectory(prefix="manual-submit-snapshot-") as directory:
            path = Path(directory) / "main.swift"
            path.write_text(program, encoding="utf-8")
            subprocess.run([compiler, str(path), "-o", str(path.with_suffix(""))], check=True, timeout=30)
            subprocess.run([str(path.with_suffix(""))], check=True, timeout=10)

    def test_comparable_prior_defers_actual_builder_until_qa_window_exists(self):
        fixture=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        seed=fixture.split('    static func seed(',1)[1].split('    private static func seedInput()',1)[0]
        self.assertNotIn('RecoveryDocumentBuilder.build(',seed)
        self.assertLess(seed.index('if requiresAsyncSeed'),seed.index('try seedInput()'))
        asynchronous=fixture.split('    static func finishAsyncSeed()',1)[1].split('    private static func persistSeed(',1)[0]
        self.assertIn('Task.detached(priority:.userInitiated)',asynchronous)
        self.assertIn('try Task.checkCancellation()',asynchronous)
        self.assertIn('systemUptime+30',asynchronous)
        self.assertIn('onCancel:{ worker.cancel() }',asynchronous)
        self.assertLess(asynchronous.index('try await worker.value'),asynchronous.index('try persistSeed('))
        self.assertIn('seededScope=scope',asynchronous)
        prepare=fixture.split('    static func prepare()',1)[1]
        self.assertIn('guard scope.pdfHash==source.digest',prepare)
        self.assertIn('original=scope;seededScope=nil',prepare)
        host=module.application((ROOT/'tests/ui/ApplicationFixture.swift').read_text(encoding='utf-8'))
        self.assertIn('if manualSeedComplete {\n            ContentView()',host)
        self.assertIn('try await SimulatorManualFixture.finishAsyncSeed(); manualSeedComplete = true',host)
        self.assertIn('accessibilityIdentifier("manual-seed-failure")',host)
        # Library save still requires the old selected digest; current source is
        # committed only afterward. Scope comes from the same actual builder.
        persist=fixture.split('    private static func persistSeed(',1)[1].split('    static func changeOriginal()',1)[0]
        self.assertIn('let lessons=scope.requiredSlots.map',persist)
        self.assertLess(persist.index('try library.savePDFAnalysis('),persist.index('try library.commit('))
        self.assertNotIn('ApplicationData.shared',persist)

    def test_review_uses_production_japan_timestamp_without_device_timezone(self):
        original=(ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        changed=module.view(original)
        self.assertIn('Text(date,format:JapaneseDateDisplay.timestamp)',changed)
        self.assertNotIn('date.formatted(date:',changed)
        self.assertIn('JapaneseDateDisplay.swift',(ROOT/"Takupoke.xcodeproj/project.pbxproj").read_text())

    def test_existing_app_generator_raster_anchor_matches_current_acquisition(self):
        import ast
        tree=ast.parse((ROOT/"tools/app_test_project.py").read_text(encoding="utf-8"))
        anchors=[n.value.value for n in ast.walk(tree) if isinstance(n,ast.Assign) and
                 any(isinstance(t,ast.Name) and t.id=="raster_marker" for t in n.targets)]
        self.assertEqual(len(anchors),1)
        source=(ROOT/"Takupoke/PDFRecoveryRecognition.swift").read_text(encoding="utf-8")
        self.assertEqual(source.count(anchors[0]),1)

    def test_generated_host_preserves_production_background_task_registration(self):
        import ast
        generator=ast.parse((ROOT/"tools/app_test_project.py").read_text(encoding="utf-8"))
        replacements=[node for node in ast.walk(generator) if isinstance(node,ast.Call) and
                      isinstance(node.func,ast.Attribute) and ast.unparse(node.func)=="shutil.copyfile" and
                      len(node.args)==2 and ast.unparse(node.args[1])=="copied / 'TakupokeApp.swift'"]
        self.assertEqual(len(replacements),1)
        self.assertEqual(ast.unparse(replacements[0].args[0]),"repo / 'tests/ui/ApplicationFixture.swift'")
        fixture=(ROOT/"tests/ui/ApplicationFixture.swift").read_text(encoding="utf-8")
        production=(ROOT/"Takupoke/TakupokeApp.swift").read_text(encoding="utf-8")
        # Compare the selected QA entrypoint's Scene registration and callback
        # against production. This establishes source parity, not crash cause
        # or native BackgroundTasks execution on any SDK/device.
        pattern=r'        \}\n        (\.backgroundTask\(\.appRefresh\(BackgroundRefresh\.identifier\)\) \{[^{}]*\})'
        normalize=lambda text:"\n".join(line.strip() for line in text.splitlines())
        expected=[normalize(block) for block in re.findall(pattern,production)]
        self.assertEqual(len(expected),1)
        scene=fixture.split("    private static func seed()",1)[0]
        self.assertEqual([normalize(block) for block in re.findall(pattern,scene)],expected,
                         "Generated QA host must register the production app-refresh handler")

    def test_fixture_dimensions_respect_native_capture_limit_and_uniform_rule_scale(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        limit=(ROOT/"Takupoke/RecoveryOCRAcquisition.swift").read_text(encoding="utf-8")
        scale,width,height=re.search(r"let scale=([0-9.]+),width=(\d+),height=(\d+)",source).groups()
        self.assertIn('(1...2048).contains(page.width)',limit)
        self.assertLessEqual(int(width),2048);self.assertLessEqual(int(height),2048)
        self.assertGreaterEqual(int(width),720*float(scale));self.assertGreaterEqual(int(height),200*float(scale))
        for expected in ('x1:20*scale', 'x2:720*scale', 'y1:40*scale', 'y2:200*scale', 'UIFont.systemFont(ofSize:8*scale/3)'):
            self.assertIn(expected,source)
        self.assertEqual(source.count('width:1480,height:960'),2)
        self.assertIn('trace("stage=attach")',source)
        generated=generated_manual_coordinator((ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8"))
        self.assertIn('SimulatorManualFixture.failed(error)',generated)

    def test_actual_qa_failure_stage_and_bitmap_extent_are_observable_in_accessibility_tree(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        self.assertIn('@AppStorage("fixture.manualStage")',source)
        self.assertIn('@AppStorage("fixture.manualPixels")',source)
        self.assertIn('accessibilityIdentifier("manual-qa-diagnostic")',source)
        self.assertIn('String(reflecting:error)',source)
        self.assertIn('raster.grayscale[y*width+x] < 200',source)
        generated=generated_manual_coordinator((ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8"))
        self.assertIn('SimulatorManualFixture.failed(error)',generated)
        self.assertIn('架空資料の補助入力を拒否しました。前回の正常結果を保持しています。',generated)

    def test_raster_ab_preserves_old_rendering_and_uses_same_physical_predicate(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        for text in ('input(integralRails:false)', 'path.lineWidth=1;path.stroke()', 'width:abs(r.x2-r.x1)+1,height:1',
                     'width:1,height:abs(r.y2-r.y1)+1', 'raster.hasUncoveredInk(', 'text:text,rules:page.lines,check:check',
                     'checks<=250000', 'firstUncovered=', 'fixture.manualOldInk', 'fixture.manualCandidateInk'):
            self.assertIn(text,source)
        checks=manual_check_source()
        self.assertIn('"--manual-integral-rails"',checks)
        self.assertNotIn('fromRGBA',checks)
        self.assertIn('emitDiagnostic()',checks)
        # Four original guards, a fresh selected-field source, and both actual
        # high-score selections must all wait for real editor inventory.
        self.assertEqual(checks.count('fieldIDs(expectedCount:1)'),4)
        self.assertEqual(checks.count('fieldIDs(expectedCount:2)'),1)
        self.assertEqual(checks.count('fieldIDs(expectedCount:3)'),2)
        self.assertIn('Set(ids).count==ids.count',checks)
        self.assertIn('TAKUPOKE-MANUAL-QA ',checks)
        self.assertIn('input(integralRails:Bool? = nil)',source)
        self.assertIn('let drawIntegral=integralRails ?? SimulatorManualFixture.integralRails',source)
        self.assertIn('XCTWaiter.wait(for:[ready],timeout:15)',checks)
        self.assertNotIn('inkDiagnostic(',source.split('static func prepare()')[1])

    def test_fixture_uses_current_period_and_actual_builder_proof(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        for required in ('SchoolDataPeriod.current()', 'RecoveryDocumentBuilder.build(', 'fromOCR:[1]',
                         'rasters:[1:raster]', 'RecoveryManualAssistance.attaching(', 'source.digest',
                         'RecoveryManualAssistance.prepare(', 'RecoveryRasterGrid.fromRGBA('):
            self.assertIn(required,source)
        self.assertNotIn('perform(on:',source)
        self.assertNotIn('2032',source)
        self.assertNotIn('https://',source)

    def test_manual_controls_are_scrolled_and_acknowledged_with_the_selection_button(self):
        generated=module.view((ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8"))
        self.assertEqual(generated.count('accessibilityIdentifier("manual-recovery-list")'),1)
        checks=manual_check_source()
        self.assertIn('app.collectionViews["manual-recovery-list"]',checks)
        self.assertIn('keyboardFrame.map { $0.minY-45 }',checks)
        self.assertNotIn('app.keyboards.firstMatch.exists',checks)
        self.assertEqual(checks.count('CGVector(dx:observedX,dy:'),2)
        self.assertNotIn('CGVector(dx:100,dy:',checks)
        self.assertIn('let observedX=safe.midX-listFrame.minX',checks)
        navigation=checks.split('    func visible(',1)[1].split('    func ',1)[0]
        self.assertEqual(navigation.count('list.frame'),1)
        self.assertIn('let listFrame=list.frame,navigationFrame=navigation.frame',navigation)
        self.assertIn('currentLists.count<=1',navigation)
        self.assertIn('listQuery.allElementsBoundByAccessibilityElement',navigation)
        self.assertIn('app.collectionViews.matching(identifier:ownerID)',navigation)
        self.assertNotIn('app.collectionViews.containing(.button',navigation)
        self.assertNotIn('e.exists && e.isHittable',navigation)
        self.assertNotIn('target.exists',navigation)
        for identifier in ("manual-settings-list","manual-materials-list","manual-analysis-list"):
            self.assertIn('ownerID:"'+identifier+'"',checks)
        self.assertIn('controls.buttons["等倍"]',checks)
        self.assertIn('app.navigationBars["原画像の確認"].buttons["確認を終える"]',checks)
        self.assertIn('accessibilityIdentifier("manual-source-controls")',generated)
        self.assertIn('accessibilityIdentifier("manual-source-scroll")',generated)
        self.assertNotIn('app.collectionViews.firstMatch',navigation)
        self.assertIn('for attempt in 0..<16',navigation)
        invalid=navigation.split('guard ManualScrollNavigation.usable(viewport),viewport.height>36 else {',1)[1].split('}',1)[0]
        self.assertIn('continue',invalid)
        self.assertNotIn('tap()',invalid)
        self.assertNotIn('press(',invalid)
        self.assertIn('manualPassiveCell(cells:cells',checks)
        self.assertIn('if inRecovery && texts.contains(where: { $0.identifier.hasPrefix("manual-reviewed-") }) { return false }', checks)
        review_source = (ROOT / 'Takupoke/PDFRecoveryView.swift').read_text(encoding='utf-8')
        review = module.view(review_source).split('if let review = coordinator.manualReview', 1)[1]
        self.assertRegex(review, r'accessibilityIdentifier\("manual-reviewed-" \+ field.id\)\s*\.fixedSize\(horizontal:false,vertical:true\)\.textSelection\(\.enabled\)')
        self.assertIn('list.cells.allElementsBoundByIndex',checks)
        self.assertIn('cell.buttons.count==0 && cell.switches.count==0',checks)
        self.assertIn('cell.textFields.count==0 && cell.textViews.count==0',checks)
        self.assertIn('frame.intersection(viewport)',checks)
        self.assertIn('cell.pickers.count==0 && cell.pickerWheels.count==0',checks)
        self.assertIn('upward ? safe.maxY-12:safe.minY+12',checks)
        self.assertIn('upward ? viewport.minY+12:min(viewport.maxY-12,startY+240)',checks)
        self.assertIn('navigationState.observe(anchor:anchor,atTop:observedTop)',checks)
        self.assertNotIn('if inRecovery && !navigationState.upward',checks)
        self.assertIn('app.navigationBars["時間割の復旧"]',checks)
        self.assertIn('unchanged>=2',checks)
        self.assertIn('guard !reversed',checks)
        self.assertIn('TAKUPOKE-MANUAL-SCROLL',checks)
        self.assertNotIn('CGVector(dx:8,dy:',checks)
        self.assertNotIn('dx:list.frame.width-24',checks)
        self.assertNotIn('dx:listFrame.width-24',checks)
        self.assertNotIn('app.collectionViews.count-1',checks)
        self.assertNotIn('acks.count',checks)
        self.assertIn('fieldIDs(expectedCount:1)?.first',checks)
        self.assertIn('guard let ids=fieldIDs(expectedCount:3)',checks)
        acknowledge=checks.split('func acknowledge(')[1].split('func tapSubmit')[0]
        self.assertIn('_ = visible(recoveryList.buttons[identifier], knownID: identifier, buttonLabel: "原本と一致することを確認")',checks)
        self.assertIn('guard let observed = visibleAcknowledgement(id)',acknowledge)
        self.assertEqual(navigation.count('target.snapshot()'),1)
        self.assertIn('targetFrame = snapshot.frame',navigation)
        self.assertIn('snapshot.elementType == .button, snapshot.identifier == targetID',navigation)
        self.assertIn('snapshot.label == ordinaryButton, snapshot.isEnabled, target.isHittable',navigation)
        self.assertIn('observeButton(.init(frame:targetFrame,viewport:viewport,isSelected:snapshot.isSelected))',navigation)
        three=checks.split('func testThreeFieldsRequireEachAcknowledgementAndFourRefuses()',1)[1].split('    func ',1)[0]
        self.assertIn('acknowledge(ids[i])',three)
        self.assertNotIn('visibleAcknowledgement(',three)
        self.assertNotIn('.tap()',acknowledge)
        self.assertNotIn('.press(',acknowledge)
        self.assertEqual(acknowledge.count('NativeTestContacts.send('),1)
        self.assertIn('NativeTestContacts.send([.init(start: center, end: center, duration: 0.1, pauseAfterLift: 0)]',acknowledge)
        self.assertIn('self.recoveryList.buttons.matching(identifier:identifier).allElementsBoundByAccessibilityElement',acknowledge)
        self.assertIn('XCTAssertFalse(ambiguous',acknowledge)
        self.assertIn('current.count==1 && current[0].isSelected',acknowledge)
        self.assertIn('ManualScrollNavigation.usable(appFrame)',acknowledge)
        self.assertIn('ManualScrollNavigation.usable(targetFrame),viewport.contains(targetFrame)',navigation)
        self.assertIn('appFrame.contains(observed.frame), !observed.isSelected, app.state == .runningForeground',acknowledge)
        self.assertNotIn('observedKeyboardFrame()',acknowledge)
        self.assertNotIn('.navigationBars',acknowledge)
        self.assertIn('let center = CGPoint(x: frame.midX, y: frame.midY)',acknowledge)
        self.assertNotIn('.coordinate(',acknowledge)
        self.assertIn('TAKUPOKE-MANUAL-ACK before',acknowledge)
        self.assertIn('TAKUPOKE-MANUAL-ACK after',acknowledge)
        self.assertNotIn('typeText(',acknowledge)
        self.assertNotIn('sleep(',acknowledge)
        acknowledgement_code = '\n'.join(line.partition('//')[0] for line in acknowledge.splitlines())
        self.assertNotRegex(acknowledgement_code,r'\bfor\s')
        self.assertIn('XCTNSPredicateExpectation',acknowledge)
        opening=checks.split('    func chooseFixtureMenuAction(',1)[1].split('    private func tapFixtureDialogAction(',1)[0]
        self.assertIn('guard current.count==1',opening)
        self.assertLess(opening.index('let barFrame=bar.frame'),opening.index('.allElementsBoundByAccessibilityElement'))
        self.assertEqual(opening.count('.tap()'),1)
        self.assertIn('app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))',opening)
        self.assertIn('CGVector(dx: frame.midX - screenFrame.minX, dy: frame.midY - screenFrame.minY)',opening)
        self.assertIn('origin.withOffset(target).tap()',opening)
        self.assertIn('barFrame.contains(frame),button.isEnabled,button.isHittable,app.state == .runningForeground',opening)
        self.assertIn('FixtureCITrace.mark("manual-fixture-menu-action")\n                    manualQAActionsPresented = true',generated)
        self.assertIn('"manual-fixture-menu-presented" : "manual-fixture-menu-dismissed"',generated)
        self.assertIn('.confirmationDialog("架空検証", isPresented: $manualQAActionsPresented)',generated)
        for action in ('表示サイズを変更','同じ原本の状態を再確認','架空原本のハッシュを変更'):
            self.assertIn(f'"{action}"',opening)
            self.assertIn(f'Button("{action}")',generated)
            self.assertIn(f'chooseFixtureMenuAction("{action}")',checks)
        self.assertIn('coordinator.invalidateManualIfSourceChanged()\n                    manualQARevalidationCount += 1',generated)
        self.assertIn('uniqueLabel("manual-fixture-type-size",in:observation),"expanded"',checks)
        self.assertIn('uniqueLabel("manual-fixture-revalidations",in:observation),"1"',checks)
        self.assertIn('tapFixtureDialogAction(action, requiredTitles: requiredTitles, screenFrame: screenFrame)',opening)
        dialog=checks.split('    private func tapFixtureDialogAction(',1)[1].split('    func tapPopupAction(',1)[0]
        self.assertIn('argumentArray: [requiredTitles.sorted()]',dialog)
        self.assertIn('buttons.count == requiredTitles.count',dialog)
        self.assertIn('snapshot.elementType == .button',dialog)
        self.assertIn('observedTitles.insert(snapshot.label).inserted',dialog)
        self.assertIn('screenFrame.contains(snapshot.frame)',dialog)
        self.assertIn('snapshot.isEnabled',dialog)
        self.assertIn('observedTitles == requiredTitles, let target, target.isHittable',dialog)
        self.assertIn('XCTWaiter.wait(for: [ready], timeout: nativeStateTimeout)',dialog)
        self.assertEqual(dialog.count('selected.tap()'),1)
        self.assertNotIn('app.snapshot()',dialog)
        menu=checks.split('    func tapPopupAction(',1)[1].split('\n    }',1)[0]
        self.assertEqual(menu.count('self.app.snapshot()'),1)
        self.assertIn('$0.elementType == .button',menu)
        self.assertIn('$0.label == title',menu)
        self.assertIn('guard current.count==1',menu)
        self.assertIn('ManualScrollNavigation.usable(frame) && root.frame.contains(frame)',menu)
        self.assertLess(menu.index('guard contained, observed.isEnabled'),menu.index('.allElementsBoundByAccessibilityElement'))
        self.assertIn('if bound.count > 1 { ambiguous = true; return true }',menu)
        self.assertIn('let button = bound.first, let boundSnapshot = try? button.snapshot()',menu)
        self.assertIn('boundSnapshot.elementType == observed.elementType, boundSnapshot.label == title',menu)
        self.assertIn('boundSnapshot.identifier == observed.identifier, boundSnapshot.frame == frame, boundSnapshot.isEnabled',menu)
        self.assertLess(menu.index('boundSnapshot.frame == frame'),menu.index('button.isHittable'))
        self.assertIn('guard hittable, ProcessInfo.processInfo.systemUptime <= deadline',menu)
        self.assertIn('XCTWaiter.wait(for:[ready],timeout:nativeStateTimeout)',menu)
        self.assertIn('guard !ambiguous,result == .completed,let button=readyButton',menu)
        self.assertEqual(menu.count('.tap()'),1)
        self.assertNotIn('coordinate(',menu)
        self.assertIn('let nativeStateTimeout:TimeInterval=45',checks)
        self.assertIn('timeout:nativeStateTimeout',acknowledge)
        self.assertNotIn('row.tap()',acknowledge)
        menu=checks.split('func selectCorrectionFromPreview(')[1].split('func selectHighConfidenceFields')[0]
        self.assertIn('visible(recoveryList.staticTexts[menuID], knownID: menuID)',menu)
        self.assertEqual(menu.count('.press('),1)
        self.assertIn('owner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 2)',menu)
        self.assertIn('tapPopupAction(name+"を訂正")',menu)
        self.assertIn('acknowledge(ids[i])',checks)

if __name__=="__main__":unittest.main()
