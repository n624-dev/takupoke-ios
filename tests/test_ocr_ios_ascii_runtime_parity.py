"""The native ASCII reject tensor and INT64 width may not bypass parity."""
import hashlib
import importlib.util
from pathlib import Path
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]/'tools/ocr-ios-ascii-runtime-parity'
spec = importlib.util.spec_from_file_location('ascii_ios_probe', ROOT/'compare.py')
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class IOSASCIIRuntimeParityTests(unittest.TestCase):
    def arrays(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest('Numerical dependencies execute in the owned native study')
        return np

    def test_inference_identity_requires_its_own_udid_pid_and_ios_simulator_target(self):
        valid = 'ORT_IOS_INFERENCE_IDENTITY\towned-id\t123\tIOS_SIMULATOR'
        self.assertEqual(compare.verify_inference_identity(valid, 'owned-id'),
                         dict(udid='owned-id', pid=123, compileTarget='IOS_SIMULATOR'))
        for changed in [valid.replace('owned-id','other-id'), valid.replace('123','0'),
                        valid.replace('123','-1'), valid.replace('IOS_SIMULATOR','MACOS'),
                        'ORT_IOS_READY\t1.23.2']:
            with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, 'inference process identity changed'):
                compare.verify_inference_identity(changed, 'owned-id')

    def test_reject_output_has_its_own_probability_tolerance(self):
        np = self.arrays()
        with self.assertRaisesRegex(ValueError, 'reject probability drift'):
            compare.compare_reject(np.array([.01]), np.array([.011]), .00005)

    def test_reject_threshold_crossing_fails_inside_numeric_tolerance(self):
        np = self.arrays()
        with self.assertRaisesRegex(ValueError, '.05 decision changed'):
            compare.compare_reject(np.array([.049999]), np.array([.050001]), .00005)

    def test_reject_probability_requires_exact_shape_finite_unit_domain(self):
        np = self.arrays()
        reference = np.array([.01])
        for changed in [np.array([[.01]]), np.array([]), np.array([.01, .01]),
                        np.array([np.nan]), np.array([np.inf]), np.array([-.01]), np.array([1.01])]:
            with self.subTest(changed=changed), self.assertRaisesRegex(ValueError, 'Invalid original reject output'):
                compare.compare_reject(reference, changed, .00005)

    def test_identical_reject_output_retains_both_decisions(self):
        np = self.arrays()
        for value in [.0, .01, .05, .95, 1.]:
            a = np.array([value], dtype=np.float32)
            self.assertEqual(compare.compare_reject(a, a.copy(), .00005), 0)

    def test_actual_native_width_must_match_both_value_and_int64_bytes(self):
        fields = ['ORT_IOS_RESULT', '0', '80', '438', 'image-hash', 'probability-hash',
                  hashlib.sha256(struct.pack('<q', 137)).hexdigest(), 'reject-hash', '137']
        compare.verify_width(fields, 137)
        for index, value in [(8, '136'), (6, hashlib.sha256(struct.pack('<i', 137)).hexdigest()),
                             (6, hashlib.sha256(struct.pack('>q', 137)).hexdigest())]:
            changed = fields.copy(); changed[index] = value
            with self.subTest(index=index), self.assertRaisesRegex(ValueError, 'valid_width input changed'):
                compare.verify_width(changed, 137)

    def test_same_greedy_text_cannot_hide_changed_ascii_nonwinning_probability(self):
        np = self.arrays()
        a = np.array([[[.01, .99, 0.]]], dtype=np.float32)
        b = a.copy(); b[0, 0, 2] = .001
        with self.assertRaisesRegex(ValueError, 'full probability tensor drift'):
            compare.compare_probabilities(a, b, ['', 'I', '1'], .00005)


if __name__ == '__main__':
    unittest.main()
