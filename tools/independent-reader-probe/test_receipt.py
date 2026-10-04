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

    def test_negative_semantic_refusals_exclude_limit_cancellation_io_and_arbitrary_errors(self):
        errors = [{'type': 'PDFParseError', 'code': c} for c in ['unsupported', 'ambiguous', 'limit', 'cancelled', 'storage', 'unreadable']]
        errors += [{'type': 'NSError', 'domain': 'NSCocoaErrorDomain', 'code': 260}, {'type': 'CancellationError', 'domain': 'Swift.CancellationError', 'code': 1}]
        planned = ['p1', 'p2', 'p3', 'p4'] + [f'n{i}' for i in range(len(errors))]
        records = [{'type': 'fixture', 'file': planned[4+i], 'analysisReturned': False, 'failure': error} for i, error in enumerate(errors)]
        actual = receipt(b'\n'.join(json.dumps(v).encode() for v in records), planned)
        self.assertEqual(actual['negativeSemanticRefusals'], 2)
        self.assertEqual(actual['negativeExecutionOrUnassessed'], 6)
        self.assertEqual(actual['negativeAnalysesReturned'], 0)

    def test_unfinished_rules_and_structure_routes_remain_separate_from_refusal(self):
        planned = ['p1', 'p2', 'p3', 'p4', 'rules', 'structure']
        records = [{'type': 'fixture', 'file': name, 'analysisReturned': False,
                    'failure': {'type': 'NSError', 'domain': domain, 'code': 1}} for name, domain in [
                        ('rules', 'SourceOnlyRulesNotComplete'), ('structure', 'StructureProposalNotAssessed')]]
        actual = receipt(b'\n'.join(json.dumps(v).encode() for v in records), planned)
        self.assertEqual(actual['negativeSemanticRefusals'], 0)
        self.assertEqual(actual['negativeRulesIncomplete'], 1)
        self.assertEqual(actual['negativeStructureUnassessed'], 1)

    def test_assertion_error_is_unassessed_and_only_actual_false_is_literal_mismatch(self):
        records = [
            {'type': 'fixture', 'file': 'wrong', 'analysisReturned': True, 'literalAssertion': {'all680LiteralMatch': False}},
            {'type': 'fixture', 'file': 'error', 'analysisReturned': True, 'assertionError': {'domain': 'AssertionOracleChanged'}},
            {'type': 'fixture', 'file': 'right', 'analysisReturned': True, 'literalAssertion': {'all680LiteralMatch': True}}]
        actual = receipt(b'\n'.join(json.dumps(v).encode() for v in records), ['wrong', 'error', 'right'])
        self.assertEqual(actual['positiveAll680LiteralMatches'], 1)
        self.assertEqual(actual['positiveLiteralMismatches'], 1)
        self.assertEqual(actual['positiveLiteralUnassessed'], 1)


if __name__ == '__main__':
    unittest.main()
