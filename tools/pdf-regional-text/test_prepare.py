"""Immutable source extraction and fail-closed execution/quality transport receipts."""
import json,tempfile,unittest
from pathlib import Path
import prepare,run_simulator,log_transport
class PrepareTests(unittest.TestCase):
    def test_actual_pinned_raster_only_extraction(self):
        with tempfile.TemporaryDirectory(prefix='pdf-regional-source-') as folder:
            output=Path(folder)/'prepared';prepare.prepare(output)
            for name in prepare.SOURCES:self.assertEqual((output/name).read_bytes(),(prepare.ROOT/'Takupoke'/name).read_bytes())
            generated,raster,unused=prepare.pure_layouts((prepare.ROOT/'Takupoke/PDFRecoveryRecognition.swift').read_text())
            self.assertEqual((output/'ProductionPureRaster.swift').read_bytes(),generated)
            self.assertIn(raster,generated);self.assertNotIn(unused,generated)
            self.assertNotIn(b'RecognizeDocumentsRequest',generated)
            self.assertEqual(len(json.loads((output/'source-receipt.json').read_text())['sourceFiles']),34)
    def test_changed_source_guard_refuses_extraction(self):
        source=(prepare.ROOT/'Takupoke/PDFRecoveryRecognition.swift').read_text()
        for changed in [source+source,source.replace('candidate.confidence >= 0.85','candidate.confidence >= 0.5')]:
            with self.assertRaises(AssertionError):prepare.pure_layouts(changed)
    def test_unassessed_errors_do_not_become_success_or_literal_mismatch(self):
        for failure in ['limit','cancelled','IO','OriginalAcquisitionGuardRefused']:
            records=[{'type':'outcome','analysisReturned':False,'failureStage':failure}, {'type':'literalAssessment','state':'UNASSESSED','assertionError':failure},{'type':'summary','plannedRequests':7,'attemptedRequests':0,'returnedRequests':0,'capturedRegions':0}]
            value=run_simulator.receipt(('\n'.join(map(json.dumps,records))+'\n').encode())
            self.assertTrue(value['recordSequenceComplete']);self.assertTrue(value['literalUnassessed'])
            self.assertFalse(value['all40LiteralMatched']);self.assertFalse(value['assessedLiteralMismatch']);self.assertFalse(value['readableRecoveryFailure'])
        records[1]={'type':'literalAssessment','state':'ASSESSED','all40LiteralMatch':False}
        self.assertTrue(run_simulator.receipt(('\n'.join(map(json.dumps,records))+'\n').encode())['assessedLiteralMismatch'])
    def test_missing_region_capture_cannot_be_counted_complete(self):
        regions=[{'type':'region','regionId':str(i),'attempted':True,'returned':True,'captureComplete':True} for i in range(7)]
        tail=[{'type':'outcome','analysisReturned':False,'failureStage':'actualCoverageSafeBuilder'},{'type':'literalAssessment','state':'UNASSESSED'},{'type':'summary','plannedRequests':7,'attemptedRequests':7,'returnedRequests':7,'capturedRegions':7}]
        raw=lambda rows:('\n'.join(map(json.dumps,rows))+'\n').encode()
        self.assertTrue(run_simulator.receipt(raw(regions+tail))['readableRecoveryFailure'])
        self.assertFalse(run_simulator.receipt(raw(regions[:-1]+tail))['recordSequenceComplete'])
        self.assertFalse(run_simulator.receipt(raw(regions+tail[:-1]))['recordSequenceComplete'])
    def test_exact_three_streams_and_corrupt_chunk_fail(self):
        streams={'native/stdout':b'fictional'*10000,'native/stderr':b'','metadata/execution':b'{}'}
        lines=[line for key,data in streams.items() for line in log_transport.encode(data,key)]
        self.assertEqual(run_simulator.restore_complete('\n'.join(lines)),streams)
        for bad in ['', '\n'.join(lines[:-1]), '\n'.join(lines[1:]),'\n'.join(lines+list(log_transport.encode(b'','extra')))]:
            with self.assertRaises((AssertionError,KeyError)):run_simulator.restore_complete(bad)
if __name__=='__main__':unittest.main()
