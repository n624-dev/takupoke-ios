"""Exercise the runner's actual final receipt statements without native OCR."""
import ast
import json
from pathlib import Path
import unittest

HERE = Path(__file__).resolve().parent

def final_receipt(raw):
    tree = ast.parse((HERE / 'run_simulator.py').read_text())
    final = next(node for node in tree.body if isinstance(node, ast.Try))
    raw_exists = next(node for node in final.finalbody if isinstance(node, ast.If)
                      and ast.unparse(node.test) == 'raw_path.is_file()')
    start = next(i for i, node in enumerate(raw_exists.body)
                 if isinstance(node, ast.Assign) and ast.unparse(node.targets[0]) == 'partial')
    selected = ast.Module(body=raw_exists.body[start:], type_ignores=[])
    values = {'record': {}, 'raw_bytes': raw, 'json': json}
    exec(compile(selected, 'actual-final-region-receipt', 'exec'), values)
    return values['record']

class RegionReceiptTests(unittest.TestCase):
    def test_successful_region_counts_survive_final_readback(self):
        captured = [{'type': 'environment'},
                    {'type': 'region', 'region': 'left', 'readReturned': True,
                     'diagnosticComplete': True, 'serializationCompleted': True, 'cropPNG': {}},
                    {'type': 'region', 'region': 'right', 'readReturned': True,
                     'diagnosticComplete': True, 'serializationCompleted': True, 'cropPNG': {}},
                    {'type': 'summary', 'requestCount': 2}]
        receipt = final_receipt(b'\n'.join(json.dumps(v).encode() for v in captured) + b'\n')
        for key in ['recordedRegions', 'readReturnedRegions', 'diagnosticCompletedRegions',
                    'serializationCompletedRegions', 'cropPNGRecordedRegions']:
            self.assertEqual(receipt[key], 2, key)
        self.assertEqual(receipt['plannedRegionsWithoutRecord'], 0)
        self.assertEqual(receipt['recordedOperationalErrors'], 0)

    def test_incomplete_region_is_reported_without_success(self):
        captured = {'type': 'region', 'region': 'left', 'readReturned': False,
                    'serializationCompleted': False, 'operationalError': 'synthetic failure'}
        receipt = final_receipt(json.dumps(captured).encode() + b'\n{incomplete')
        self.assertEqual(receipt['recordedRegions'], 1)
        self.assertEqual(receipt['readReturnedRegions'], 0)
        self.assertEqual(receipt['diagnosticCompletedRegions'], 0)
        self.assertEqual(receipt['cropPNGRecordedRegions'], 0)
        self.assertEqual(receipt['recordedOperationalErrors'], 1)
        self.assertEqual(receipt['plannedRegionsWithoutRecord'], 1)
        self.assertEqual(receipt['nonJSONOrIncompleteRawLines'], 1)

if __name__ == '__main__':
    unittest.main()
