"""Partial native transport and semantic failures stay distinct; no native API fake."""
import json
import unittest
from run_simulator import receipt


class ReceiptTests(unittest.TestCase):
    def test_complete_transport_preserves_reader_failure_instead_of_claiming_semantic_pass(self):
        raw = b'\n'.join(json.dumps(v).encode() for v in [
            {'type': 'fixture', 'file': 'main.pdf', 'readReturned': False, 'analysisReturned': False, 'failure': {'code': 'unsupported'}},
            {'type': 'summary'}]) + b'\n'
        actual = receipt(raw, ['main.pdf'])
        self.assertTrue(actual['transportComplete'])
        self.assertEqual(actual['sourceFailures'], 1)
        self.assertEqual(actual['positiveAll680LiteralMatches'], 0)
        self.assertEqual(actual['analysesReturned'], 0)

    def test_killed_worker_reports_unrecorded_fixture_without_scoring_partial_record(self):
        raw = b'{"type":"fixture","file":"a.pdf","readReturned":true}\n{"type":"fixture","file":"b.pdf"'
        actual = receipt(raw, ['a.pdf', 'b.pdf'])
        self.assertFalse(actual['transportComplete'])
        self.assertEqual(actual['recordedFiles'], ['a.pdf'])
        self.assertEqual(actual['plannedFilesWithoutRecord'], ['b.pdf'])
        self.assertEqual(actual['nonJSONOrIncompleteLines'], 1)
        self.assertEqual(actual['readReturned'], 1)


if __name__ == '__main__':
    unittest.main()
