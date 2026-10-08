import importlib.util
from pathlib import Path
import unittest
import re
import os
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("manual_ui_project",ROOT/"tools/manual_ui_project.py")
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

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
        checks=(ROOT/"tests/ui/ManualAssistanceChecks.swift").read_text(encoding="utf-8")
        self.assertIn('XCTAssertEqual(app.staticTexts["manual-process-launch"].firstMatch.label,processBefore',checks)
        self.assertIn('XCTAssertEqual(header.label,"採用する資料全体",app.debugDescription)',checks)

    def test_editor_uses_physical_clear_and_checks_full_replacement(self):
        checks=(ROOT/"tests/ui/ManualAssistanceChecks.swift").read_text(encoding="utf-8")
        edit=checks.split('    private func edit(',1)[1].split('    private func editStage(',1)[0]
        self.assertLess(edit.index('let target=visible(clear,knownID:'),edit.index('target.tap()'))
        self.assertLess(edit.index('target.tap()'),edit.index('e.typeText(value)'))
        self.assertIn('Native clear must remove the entire previous input',edit)
        self.assertIn('Clearing text must revoke prior acknowledgement',edit)
        self.assertIn('The physical edit must replace the full previous input',edit)
        self.assertIn('e.typeText(value)',edit)
        self.assertNotIn('sleep(',edit)
        self.assertIn('editStage("after-clear-focus",e)',edit)
        self.assertNotIn('visible(e).tap()',edit)
        self.assertIn('TAKUPOKE-MANUAL-EDIT stage=',checks)

    def test_manual_case_filter_is_exact_and_default_keeps_whole_suite(self):
        runner=(ROOT/"tools/test-manual-ui.sh").read_text(encoding="utf-8")
        prefix=runner.split('scratch_dir=',1)[0]
        names=['testChangedOriginalCannotSubmitOrReplaceLastGood',
               'testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground',
               'testThreeFieldsRequireEachAcknowledgementAndFourRefuses']
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
        program=runner.split('python3 - "$scratch_dir/manual-ui.log" "$manual_case" <<\'PY\'\n',1)[1].split('\nPY',1)[0]
        names=['testChangedOriginalCannotSubmitOrReplaceLastGood',
               'testOneCorrectionRequiresUncheckedAcknowledgementAndSurvivesBackground',
               'testThreeFieldsRequireEachAcknowledgementAndFourRefuses']
        def line(name,status='passed'):
            return "Test Case '-[PickerTapChecks.ManualAssistanceChecks "+name+"]' "+status+" (1.0 seconds).\n"
        with tempfile.TemporaryDirectory() as scratch:
            log=Path(scratch)/'completed.log'
            def run(selected,content):
                log.write_text(content,encoding='utf-8')
                return subprocess.run(['python3','-c',program,str(log),selected],capture_output=True,text=True)
            for name in names:
                self.assertEqual(run(name,line(name)).returncode,0)
            whole=''.join(line(name) for name in names)
            self.assertEqual(run('',whole).returncode,0)
            negatives=[(names[0],''),(names[0],line(names[0])*2),
                       (names[0],line(names[0],'skipped')),(names[0],line(names[0],'failed')),
                       (names[0],line(names[1])),(names[0],whole),('',line(names[0])),
                       ('',whole+line(names[0])),('',whole+line('testUnknown')),('testUnknown',whole)]
            for selected,content in negatives:
                self.assertNotEqual(run(selected,content).returncode,0,(selected,content))

    def test_coordinator_preserves_actual_submit_adopt_and_source_guards(self):
        original=(ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        changed=module.coordinator(original)
        self.assertIn('try RecoveryConversion.verifyFile(source',changed)
        self.assertIn('acknowledged == Set(draft.fields.map',changed)
        self.assertIn('selectedSourceIsCurrent',changed)
        self.assertIn('ApplicationData.shared.materials.adoptRecovery(preview)',changed)
        self.assertEqual(changed.count('if SimulatorManualFixture.enabled'),4)
        self.assertEqual(changed.count('            cancel(); failure = nil; running = true'),1)
        self.assertIn('if SimulatorManualFixture.enabled { SimulatorManualFixture.trace("stage=manual-preview-ready") }',changed)
        self.assertIn('if SimulatorManualFixture.enabled { SimulatorManualFixture.failed(error) }',changed)

    def test_view_identifiers_do_not_precheck_or_bypass_existing_disabled_gate(self):
        original=(ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        changed=module.view(original)
        self.assertIn('manualAcknowledged[field.id] ?? false',changed)
        self.assertIn('RecoveryManualInput.update(',changed)
        self.assertIn('coordinator.submitManual(',changed)
        self.assertIn('draft.fields.contains',changed)
        self.assertIn('coordinator.suspendForInactivity()',changed)
        self.assertIn('models.cancel()',changed)
        self.assertEqual(changed.count('accessibilityIdentifier("manual-submit")'),1)

    def test_review_readiness_measures_actual_coordinator_state(self):
        changed=module.view((ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8"))
        state=next(line for line in changed.splitlines() if 'Text("preview=' in line)
        self.assertIn('review=\\(coordinator.manualReview != nil)',state)
        self.assertIn('preview=\\(coordinator.preview != nil)',state)
        self.assertEqual(changed.count('accessibilityIdentifier("manual-coordinator-state")'),1)

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
        generated=module.coordinator((ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8"))
        self.assertIn('SimulatorManualFixture.failed(error)',generated)

    def test_actual_qa_failure_stage_and_bitmap_extent_are_observable_in_accessibility_tree(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        self.assertIn('@AppStorage("fixture.manualStage")',source)
        self.assertIn('@AppStorage("fixture.manualPixels")',source)
        self.assertIn('accessibilityIdentifier("manual-qa-diagnostic")',source)
        self.assertIn('String(reflecting:error)',source)
        self.assertIn('raster.grayscale[y*width+x] < 200',source)
        generated=module.coordinator((ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8"))
        self.assertIn('SimulatorManualFixture.failed(error)',generated)
        self.assertIn('架空資料の補助入力を拒否しました。前回の正常結果を保持しています。',generated)

    def test_raster_ab_preserves_old_rendering_and_uses_same_physical_predicate(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        for text in ('input(integralRails:false)', 'path.lineWidth=1;path.stroke()', 'width:abs(r.x2-r.x1)+1,height:1',
                     'width:1,height:abs(r.y2-r.y1)+1', 'raster.hasUncoveredInk(', 'text:text,rules:page.lines,check:check',
                     'checks<=250000', 'firstUncovered=', 'fixture.manualOldInk', 'fixture.manualCandidateInk'):
            self.assertIn(text,source)
        checks=(ROOT/"tests/ui/ManualAssistanceChecks.swift").read_text(encoding="utf-8")
        self.assertIn('"--manual-integral-rails"',checks)
        self.assertNotIn('fromRGBA',checks)
        self.assertIn('emitDiagnostic()',checks)
        self.assertEqual(checks.count('XCTAssertTrue(fieldsExist()'),4)
        self.assertIn('TAKUPOKE-MANUAL-QA ',checks)
        self.assertIn('input(integralRails:Bool? = nil)',source)
        self.assertIn('let drawIntegral=integralRails ?? SimulatorManualFixture.integralRails',source)
        self.assertIn('waitForExistence(timeout:15)',checks)
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

    def test_manual_controls_are_scrolled_and_acknowledged_without_keyboard_or_outer_switch_taps(self):
        generated=module.view((ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8"))
        self.assertEqual(generated.count('accessibilityIdentifier("manual-recovery-list")'),1)
        checks=(ROOT/"tests/ui/ManualAssistanceChecks.swift").read_text(encoding="utf-8")
        self.assertIn('app.collectionViews["manual-recovery-list"]',checks)
        self.assertIn('app.keyboards.firstMatch.frame.minY-45',checks)
        self.assertEqual(checks.count('CGVector(dx:100,dy:'),2)
        self.assertIn('list.cells.allElementsBoundByIndex',checks)
        self.assertIn('$0.buttons.count==0 && $0.switches.count==0',checks)
        self.assertIn('$0.textFields.count==0 && $0.textViews.count==0',checks)
        self.assertIn('frame.intersection(viewport)',checks)
        self.assertIn('$0.pickers.count==0 && $0.pickerWheels.count==0',checks)
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
        self.assertNotIn('app.collectionViews.count-1',checks)
        self.assertNotIn('acks.count',checks)
        self.assertIn('XCTAssertEqual(fieldIDs.count,1)',checks)
        self.assertIn('XCTAssertEqual(ids.count,3)',checks)
        acknowledge=checks.split('private func acknowledge(')[1].split('private func assertSubmitEnabled')[0]
        self.assertIn('let control=row.switches.firstMatch',acknowledge)
        self.assertEqual(acknowledge.count('.tap()'),1)
        self.assertIn('let actual=visible(control)',acknowledge)
        self.assertIn('manualAcknowledgementPoint(outer:outerFrame,inner:innerFrame,viewport:viewport)',acknowledge)
        self.assertIn('dx:point.x-appFrame.minX,dy:point.y-appFrame.minY',acknowledge)
        self.assertIn('TAKUPOKE-MANUAL-ACK before',acknowledge)
        self.assertIn('TAKUPOKE-MANUAL-ACK after',acknowledge)
        self.assertNotIn('typeText(',acknowledge)
        self.assertNotIn('sleep(',acknowledge)
        self.assertNotIn('for ',acknowledge)
        self.assertIn('XCTNSPredicateExpectation',acknowledge)
        self.assertIn('private let nativeStateTimeout:TimeInterval=45',checks)
        self.assertIn('timeout:nativeStateTimeout',acknowledge)
        self.assertNotIn('row.tap()',acknowledge)
        self.assertIn('acknowledge(ids[i])',checks)

if __name__=="__main__":unittest.main()
