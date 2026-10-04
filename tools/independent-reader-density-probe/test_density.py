"""Separate density phase safety/transport regressions; no native API simulation."""
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('density_prepare',HERE/'prepare.py')
prepare=importlib.util.module_from_spec(spec);spec.loader.exec_module(prepare)
spec=importlib.util.spec_from_file_location('density_runner',HERE/'run_simulator.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)


class DensityPhaseTests(unittest.TestCase):
    def inputs(self,folder):
        (folder/'expected.json').write_text('{}')
        rows=[]
        for name in prepare.FILES:
            data=b'%PDF-independent-byte-preflight-only-'+name.encode()
            (folder/name).write_bytes(data)
            rows.append({'file':name,'bytes':len(data),'sha256':prepare.sha(data)})
        pins={'expectedSha256':prepare.sha((folder/'expected.json').read_bytes()),'artifacts':rows,'generatorSha256':prepare.sha((prepare.ROOT/'tools/independent-wide-timetable/generate_dense.py').read_bytes())}
        (folder/'manifest.json').write_text(json.dumps(pins))
        return pins

    def test_current_phase_exports_only_four_pdf_inputs_and_exact_reviewed_sources(self):
        with tempfile.TemporaryDirectory() as owned:
            root=Path(owned);fixtures=root/'fixtures';fixtures.mkdir();pins=self.inputs(fixtures)
            output=root/'prepared';prepare.prepare(output,fixtures,pins)
            self.assertFalse((output/'baseline').exists())
            self.assertFalse((output/'expected.json').exists())
            receipt=json.loads((output/'source-receipt.json').read_text())
            self.assertEqual((receipt['baselineRequests'],receipt['fixedRequests'],receipt['denseRequests'],receipt['wideRequests']),(0,4,4,0))
            rows=json.loads((output/'native-inputs.json').read_text())['files']
            self.assertEqual([r['file'] for r in rows],prepare.FILES)
            for row in rows:self.assertEqual(set(row),{'file','sha256','bytes'})
            for name in prepare.SOURCES:
                self.assertEqual((output/'fixed'/name).read_bytes(),(prepare.ROOT/'Takupoke'/name).read_bytes())

    def test_unreviewed_runtime_drift_is_refused_before_native_calls(self):
        actual=subprocess.check_output
        def mismatched(args,**kw):
            if args[:2]==['git','show'] and args[2].endswith(':Takupoke/PDFPathReader.swift'):
                return b'changed independent diagnostic source bytes'
            return actual(args,**kw)
        with tempfile.TemporaryDirectory() as owned:
            root=Path(owned);fixtures=root/'fixtures';fixtures.mkdir();pins=self.inputs(fixtures)
            with patch.object(prepare.subprocess,'check_output',side_effect=mismatched):
                with self.assertRaisesRegex(AssertionError,'PDFPathReader'):
                    prepare.prepare(root/'prepared',fixtures,pins)
            self.assertFalse((root/'prepared/source-receipt.json').exists())

    def test_three_exact_streams_required_even_for_empty_stderr(self):
        streams={'fixed/stdout':b'fictional complete record\n','fixed/stderr':b'','metadata/execution':b'{"plannedReaderCalls":4}'}
        log='\n'.join(line for key,value in streams.items() for line in runner.log_transport.encode(value,key))
        self.assertEqual(runner.restore_complete(log),streams)
        for broken in ['', '\n'.join(runner.log_transport.encode(b'only metadata','metadata/execution')),
                       log+'\n'+'\n'.join(runner.log_transport.encode(b'forbidden duplicate cohort','baseline/stdout'))]:
            with self.assertRaises(AssertionError):runner.restore_complete(broken)

    def test_partial_record_is_not_complete_or_literal_success(self):
        raw=b'{"type":"fixture","file":"dense-unlabeled-black.pdf","readReturned":false,"analysisReturned":false,"capture":{"complete":false},"failure":{"type":"PDFParseError","code":"limit"}}\n'
        receipt=runner.receipt(raw,prepare.FILES)
        self.assertFalse(receipt['transportComplete'])
        self.assertEqual(receipt['readReturned'],0)
        self.assertEqual(receipt['positiveAll680LiteralMatches'],0)
        self.assertEqual(receipt['failureClasses']['executionOrUnassessed'],1)
        self.assertEqual(len(receipt['plannedFilesWithoutRecord']),3)


if __name__=='__main__':unittest.main()
