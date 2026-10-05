import importlib.util
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location("manual_ui_project",ROOT/"tools/manual_ui_project.py")
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class ManualUIProjectTests(unittest.TestCase):
    def test_missing_or_duplicate_anchor_fails_closed(self):
        for text in ("", "marker marker"):
            with self.assertRaises(ValueError): module.once(text,"marker","new")

    def test_coordinator_preserves_actual_submit_adopt_and_source_guards(self):
        original=(ROOT/"Takupoke/PDFRecoveryCoordinator.swift").read_text(encoding="utf-8")
        changed=module.coordinator(original)
        self.assertIn('try RecoveryConversion.verifyFile(source',changed)
        self.assertIn('acknowledged == Set(draft.fields.map',changed)
        self.assertIn('selectedSourceIsCurrent',changed)
        self.assertIn('ApplicationData.shared.materials.adoptRecovery(preview)',changed)
        self.assertEqual(changed.count('if SimulatorManualFixture.enabled'),1)

    def test_view_identifiers_do_not_precheck_or_bypass_existing_disabled_gate(self):
        original=(ROOT/"Takupoke/PDFRecoveryView.swift").read_text(encoding="utf-8")
        changed=module.view(original)
        self.assertIn('manualAcknowledged[field.id] ?? false',changed)
        self.assertIn('manualAcknowledged[field.id] = false',changed)
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

    def test_fixture_uses_current_period_and_actual_builder_proof(self):
        source=(ROOT/"tests/ui/ManualAssistanceFixture.swift").read_text(encoding="utf-8")
        for required in ('SchoolDataPeriod.current()', 'RecoveryDocumentBuilder.build(', 'fromOCR:[1]',
                         'rasters:[1:raster]', 'RecoveryManualAssistance.attaching(', 'source.digest',
                         'RecoveryManualAssistance.prepare(', 'RecoveryRasterGrid.fromRGBA('):
            self.assertIn(required,source)
        self.assertNotIn('perform(on:',source)
        self.assertNotIn('2032',source)
        self.assertNotIn('https://',source)

if __name__=="__main__":unittest.main()
