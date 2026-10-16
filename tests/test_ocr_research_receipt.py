"""Research notices expose only bounded counters and hashes, never OCR text."""
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('bounded_ocr_receipt', ROOT/'tools/ocr-research-receipt.py')
report = importlib.util.module_from_spec(spec); spec.loader.exec_module(report)


class BoundedResearchReceiptTests(unittest.TestCase):
    def source(self):
        row = dict(id='qualification-f1-timetable',variant='source2x4096',fields=2040,classNameFields=17,
            visionExact=0,paddleExact=1800,paddleOwnPiecesEligibleWrong=50,paddleUnassignedInBody=2,
            paddleUnassignedIncludingHeaders=40,classOriginalExact=0,classCandidateExact=15,classCandidateEligibleExact=15,
            classCandidateEligibleWrong=2,classASCIIExact=16,classASCIIEligibleExact=16,classASCIIEligibleWrong=1,
            classASCIIGainsOverCellV6=1,classASCIILossesOverCellV6=0,classCandidateRefusedCells=0,
            classCandidateUnexpectedCellInk=0,classASCIIUnexpectedCellInk=0,hybridExact=1800)
        receipt = dict(variant='source2x4096',documents=1,requiredBodyFields=2040,visionInputVariant='current2048',
            visionAllocationUsesOwnOriginalGeometry=True,recognizedFileSHA256='a'*64,actualVisionCalls=0,
            actualV6Calls=2100,actualASCIICalls=17,actualONNXCalls=2117,actualClassCellCalls=17)
        acquisition = dict(variant='source2x4096',documents=[dict(id=row['id'],kind='timetable',
            sourcePDFSHA256='b'*64,nativeVisionState='notRequestedDimensionBound')])
        native = ('FULL_SOURCE_CAPTURE_FINISHED pages=2 actualVisionCalls=1\n'
                  'Test Case testAcquireCompleteFrozenOriginalSource passed\nExecuted 1 test, with 0 failures\n')
        return dict(receipt=receipt,summaries=[row]),acquisition,'f1-timetable',native

    def native(self):
        return dict(study='ios-ascii-v1-cpu-native-input-parity-v1',runtime='1.23.2',iosRuntime='26.5',
            actualNativeCalls=288,actualReferenceCalls=288,nativeRGBTransforms=292,nativeInputCount=2,nativeOutputCount=2,
            nativeValidWidthType='INT64',physicalIPhoneExecution=False,applicationChanged=False,
            sameGreedyTextAndIntervals=True,same085Floor=True,sameReject005Decision=True,
            fullProbabilityMaxDifference=0.,fullRejectProbabilityMaxDifference=0.,nativePeakRSSBytes=160000000,nativeBatchSeconds=32.,
            verifiedTransformProcessIdentity=dict(udid='owned',runtime='26.5.0',pid=10,simulatorCompileTarget=True),
            verifiedInferenceProcessIdentity=dict(udid='owned',pid=11,compileTarget='IOS_SIMULATOR'))

    def test_source_receipt_keeps_wrong_unassigned_and_ineligible_outcomes_visible(self):
        result = report.source_receipt(*self.source())
        self.assertEqual(result['paddleExact'], 1800)
        self.assertEqual(result['paddleOwnPiecesEligibleWrong'], 50)
        self.assertEqual(result['paddleUnassignedInBody'], 2)
        self.assertEqual(result['classASCIIEligibleWrong'], 1)
        self.assertFalse(result['formalAdoptionVerified'])
        self.assertEqual(result['actualBaselineVisionCalls'], 1)
        self.assertEqual(result['actualCandidateVisionCalls'], 0)

    def test_no_original_text_prompt_recovery_result_or_unknown_strings_enter_notice(self):
        args = self.source(); args[0]['teacher'] = 'fictional-sensitive-marker'; args[1]['prompt'] = 'fictional-sensitive-marker'
        args[0]['summaries'][0]['RecoveryResult'] = 'fictional-sensitive-marker'
        encoded = json.dumps(report.source_receipt(*args))
        self.assertNotIn('fictional-sensitive-marker', encoded)
        self.assertNotIn('RecoveryResult', encoded)
        args[0]['summaries'][0]['paddleExact'] = 'fictional-sensitive-marker'
        with self.assertRaisesRegex(ValueError, 'bounded research count'):
            report.source_receipt(*args)

    def test_source_receipt_refuses_missing_scope_wrong_variant_and_unexecuted_native_capture(self):
        for mutate in [lambda a:a[0]['summaries'][0].update(fields=120),
                       lambda a:a[0]['summaries'][0].update(classNameFields=16),
                       lambda a:a[0]['receipt'].update(variant='current2048'),
                       lambda a:a[0]['receipt'].update(actualONNXCalls=2116),
                       lambda a:a[0]['summaries'][0].update(hybridExact=1801)]:
            args = self.source(); mutate(args)
            with self.assertRaises(ValueError): report.source_receipt(*args)
        args = self.source()
        with self.assertRaisesRegex(ValueError, 'exact inventory'):
            report.source_receipt(*args[:3], 'timeout')

    def test_native_receipt_requires_all_original_probability_and_identity_checks(self):
        result = report.native_receipt(self.native())
        self.assertEqual(result['actualNativeCalls'], 288)
        self.assertEqual(result['fullRejectProbabilityMaxDifference'], 0)
        self.assertFalse(result['physicalIPhoneExecution'])
        for delta in [dict(same085Floor=False),dict(sameReject005Decision=False),dict(actualNativeCalls=287),
                      dict(nativeRGBTransforms=291),dict(fullProbabilityMaxDifference=.00006),
                      dict(fullRejectProbabilityMaxDifference=float('nan')),dict(physicalIPhoneExecution=True)]:
            with self.subTest(delta=delta), self.assertRaises(ValueError):
                report.native_receipt(self.native() | delta)
        value = self.native(); value['verifiedInferenceProcessIdentity']['udid'] = 'another-device'
        with self.assertRaisesRegex(ValueError, 'process identities'): report.native_receipt(value)

    def test_counts_hashes_and_measurements_cannot_hide_nonfinite_or_free_text_values(self):
        for value in [True,-1,1.5,'1']:
            with self.subTest(value=value), self.assertRaises(ValueError): report.count(value)
        for value in ['not-a-digest','a'*63,'A'*64]:
            with self.subTest(value=value), self.assertRaises(ValueError): report.digest(value)
        for value in [float('nan'),float('inf'),-1,'0']:
            with self.subTest(value=value), self.assertRaises(ValueError): report.number(value,1)


if __name__ == '__main__': unittest.main()
