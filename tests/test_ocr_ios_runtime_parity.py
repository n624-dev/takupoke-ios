"""Integrity, native-probability and owned-resource boundaries for iOS research."""
import importlib.util
import io
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile


ROOT = Path(__file__).resolve().parents[1] / 'tools/ocr-ios-runtime-parity'


def module(name):
    spec = importlib.util.spec_from_file_location('ios_runtime_probe_' + name, ROOT / (name + '.py'))
    result = importlib.util.module_from_spec(spec); spec.loader.exec_module(result)
    return result


compare, prepare = module('compare'), module('prepare')


class IOSRuntimeParityTests(unittest.TestCase):
    def arrays(self):
        try:
            import numpy as np
        except ImportError:
            self.skipTest('Numerical probe dependencies execute in the dedicated owned environment')
        return np

    def test_full_probability_drift_rejects_even_when_greedy_text_is_unchanged(self):
        np = self.arrays()
        original = np.array([[[.01, .99, 0.]]], dtype=np.float32)
        changed = original.copy(); changed[0, 0, 2] = .0001
        with self.assertRaisesRegex(ValueError, 'full probability tensor drift'):
            compare.compare_probabilities(original, changed, ['', 'A', ' '], .00005)

    def test_crossing_selected_piece_floor_rejects_within_numeric_tolerance(self):
        np = self.arrays()
        a = np.array([[[.1, .850001]]], dtype=np.float32)
        b = np.array([[[.1, .849999]]], dtype=np.float32)
        with self.assertRaisesRegex(ValueError, '.85 floor changed'):
            compare.compare_probabilities(a, b, ['', 'A'], .00005)

    def test_identical_native_probabilities_keep_spaces_and_ctc_intervals(self):
        np = self.arrays()
        a = np.array([[[0, .9, .1], [0, .95, .05], [.9, .1, 0], [0, .1, .9]]], dtype=np.float32)
        difference, pieces = compare.compare_probabilities(a, a.copy(), ['', 'A', ' '], .00005)
        self.assertEqual(difference, 0)
        self.assertEqual([(p['text'], p['start'], p['end']) for p in pieces], [('A', 0, 2), (' ', 3, 4)])

    def test_losing_nan_is_rejected_instead_of_ignored(self):
        np = self.arrays()
        a = np.array([[[.1, .9, 0.]]], dtype=np.float32)
        b = a.copy(); b[0, 0, 2] = np.nan
        with self.assertRaisesRegex(ValueError, 'Invalid native CTC'):
            compare.compare_probabilities(a, b, ['', 'A', ' '], .00005)

    def test_framework_archive_cannot_escape_the_owned_slice(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('onnxruntime.xcframework/ios-arm64/../../outside', b'bad')
        with tempfile.TemporaryDirectory() as temporary:
            with self.assertRaisesRegex(ValueError, 'Unsafe native framework'):
                prepare.extract_slices(data.getvalue(), Path(temporary))
            self.assertFalse((Path(temporary) / 'outside').exists())

    def test_owned_simulator_delete_still_runs_after_shutdown_timeout(self):
        failure = subprocess.TimeoutExpired(['xcrun', 'simctl', 'shutdown'], 60)
        with patch.object(compare.subprocess, 'run', side_effect=[failure, subprocess.CompletedProcess([], 0)]) as run:
            with self.assertRaises(subprocess.TimeoutExpired):
                compare.remove_owned_simulator('owned-fictional-id')
        self.assertEqual(run.call_args_list[1].args[0], ['xcrun', 'simctl', 'delete', 'owned-fictional-id'])

    def test_failed_owned_delete_is_not_counted_as_clean_success(self):
        with patch.object(compare.subprocess, 'run', side_effect=[subprocess.CompletedProcess([], 1),
                  subprocess.CalledProcessError(1, ['xcrun', 'simctl', 'delete'])]):
            with self.assertRaises(subprocess.CalledProcessError):
                compare.remove_owned_simulator('owned-fictional-id')


if __name__ == '__main__':
    unittest.main()
