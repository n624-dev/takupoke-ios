import importlib.util
from pathlib import Path
import unittest
import re

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

    def test_editor_reacquires_real_hit_region_after_keyboard_focus(self):
        checks=(ROOT/"tests/ui/ManualAssistanceChecks.swift").read_text(encoding="utf-8")
        edit=checks.split('    private func edit(',1)[1].split('    private func editStage(',1)[0]
        self.assertLess(edit.index('visible(e).tap()'),edit.index('let focused=visible(e)'))
        self.assertLess(edit.index('let focused=visible(e)'),edit.index('focused.press(forDuration:1.1)'))
        self.assertIn('menuItems["すべてを選択"]',edit)
        self.assertIn('menuItems["Select All"]',edit)
        self.assertIn('e.typeText(value)',edit)
        self.assertNotIn('sleep(',edit)
        self.assertIn('editStage("after-focus",e)',edit)
        self.assertIn('editStage("before-selection",focused)',edit)
        self.assertIn('TAKUPOKE-MANUAL-EDIT stage=',checks)

    def test_coordinator_preserves_actual_submit_adopt_and_source_guards(self):
        original=(ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        changed=module.coordinator(original)
        self.assertIn('try RecoveryConversion.verifyFile(source',changed)
        self.assertIn('acknowledged == Set(draft.fields.map',changed)
        self.assertIn('selectedSourceIsCurrent',changed)
        self.assertIn('ApplicationData.shared.materials.adoptRecovery(preview)',changed)
        self.assertEqual(changed.count('if SimulatorManualFixture.enabled'),3)
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
        self.assertEqual(checks.count('XCTAssertTrue(fieldsExist()'),3)
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
        self.assertIn('upward ? viewport.minY+12:viewport.maxY-12',checks)
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
        self.assertIn('timeout:5',acknowledge)
        self.assertNotIn('row.tap()',acknowledge)
        self.assertIn('acknowledge(ids[i])',checks)

if __name__=="__main__":unittest.main()
