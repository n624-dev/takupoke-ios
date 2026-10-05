"""Exact statement/source extraction and observed receipt tests; no fake Vision types."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
import os
import shutil
import subprocess
import prepare
import log_transport
import run_simulator


class PrepareTests(unittest.TestCase):
    def test_copied_production_and_original_statement_blocks_are_byte_exact(self):
        with tempfile.TemporaryDirectory(prefix='ios-forty-prepare-test-') as folder:
            output=Path(folder)/'prepared';prepare.prepare(output)
            receipt=json.loads((output/'source-receipt.json').read_text())
            self.assertEqual(len(receipt['sourceFiles']),34)
            for name in prepare.SOURCES:self.assertEqual((output/name).read_bytes(),(prepare.ROOT/'Takupoke'/name).read_bytes())
            source=(prepare.ROOT/'Takupoke/PDFRecoveryRecognition.swift').read_text()
            generated,raster,suffix=prepare.pure_layouts(source)
            self.assertEqual((output/'ProductionPureLayouts.swift').read_bytes(),generated)
            self.assertIn(raster,generated);self.assertIn(suffix,generated)
            self.assertNotIn(b'RecognizeDocumentsRequest',generated)
            self.assertFalse(receipt['runtimeSourceProductionPatchMixedIn'])

    def test_duplicate_method_selector_or_missing_guard_cannot_be_extracted(self):
        source=(prepare.ROOT/'Takupoke/PDFRecoveryRecognition.swift').read_text()
        for changed in [source+source,source.replace('candidate.confidence >= 0.85','candidate.confidence >= 0.50')]:
            with self.assertRaises(AssertionError):prepare.pure_layouts(changed)

    def test_changed_shared_drawing_or_oracle_pin_is_rejected_before_native(self):
        pins=json.loads((prepare.HERE/'fixture-pins.json').read_text())
        for name,digest in pins['files'].items():
            value=(prepare.HERE/name).read_bytes()
            self.assertEqual(prepare.sha(value),digest)
            self.assertNotEqual(prepare.sha(value+b' '),digest)

    def test_operational_or_guard_refusal_is_unassessed_not_literal_success(self):
        def records(assessment):
            return [{'type':'input'},{'type':'page','failure':{'code':'limit'}},{'type':'drawing'},assessment,{'type':'summary','attemptedRequests':1,'returnedRequests':1,'analysesReturned':0}]
        for assessment in [{'type':'literalAssessment','state':'UNASSESSED','assertionError':'IO'}, {'type':'literalAssessment','state':'UNASSESSED','reason':'guard refused'}]:
            raw=('\n'.join(json.dumps(v) for v in records(assessment))+'\n').encode()
            result=run_simulator.receipt(raw)
            self.assertTrue(result['recordSequenceComplete']);self.assertTrue(result['literalUnassessed'])
            self.assertFalse(result['all40LiteralMatched']);self.assertFalse(result['assessedLiteralMismatch'])
        assessment={'type':'literalAssessment','state':'ASSESSED','all40LiteralMatch':False}
        raw=('\n'.join(json.dumps(v) for v in records(assessment))+'\n').encode()
        self.assertTrue(run_simulator.receipt(raw)['assessedLiteralMismatch'])

    def test_exact_three_stream_transport_and_no_record_repair(self):
        values={'native/stdout':b'fictional'*10000,'native/stderr':b'','metadata/execution':b'{}'}
        lines=[line for key,data in values.items() for line in log_transport.encode(data,key)]
        self.assertEqual(run_simulator.restore_complete('\n'.join(lines)),values)
        for bad in ['', '\n'.join(lines[:-1]), '\n'.join(lines[:1]+lines[2:]), '\n'.join(lines+list(log_transport.encode(b'','unexpected')))]:
            with self.assertRaises((AssertionError,KeyError)):run_simulator.restore_complete(bad)
        self.assertFalse(run_simulator.receipt(b'{}\n')['recordSequenceComplete'])

    def test_independent_ink_error_preserves_baseline_but_never_proves_projection(self):
        compiler=os.environ.get('SWIFTC') or shutil.which('swiftc')
        self.assertTrue(compiler,'Swift compiler required for actual diagnostic handoff test')
        with tempfile.TemporaryDirectory(prefix='ios-forty-ink-policy-') as folder:
            main=Path(folder)/'main.swift'
            main.write_text('''enum Failure:Error {case diagnosticLimit, cancellation, deadline}
let unavailable=try IndependentInkProof.measure(evaluate:{throw Failure.diagnosticLimit},check:{})
precondition(unavailable.uncoveredInk == nil && unavailable.error != nil)
precondition(unavailable.uncoveredInk != false)
for value in [false,true] {
    let proof=try IndependentInkProof.measure(evaluate:{value},check:{})
    precondition(proof.uncoveredInk == value && proof.error == nil)
}
for terminal in [Failure.cancellation,Failure.deadline] {
    do {
        _=try IndependentInkProof.measure(evaluate:{throw Failure.diagnosticLimit},check:{throw terminal})
        fatalError("Task cancellation/deadline must not resume baseline")
    } catch let actual as Failure {precondition(String(describing:actual)==String(describing:terminal))}
}
print("independent diagnostic handoff PASS")
''')
            binary=Path(folder)/'ink-policy'
            subprocess.run([compiler,str(prepare.HERE/'IndependentInkProof.swift'),str(main),'-o',str(binary)],check=True,capture_output=True)
            result=subprocess.run([str(binary)],check=True,capture_output=True,text=True)
            self.assertIn('handoff PASS',result.stdout)


if __name__=='__main__':unittest.main()
