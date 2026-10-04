"""Real CI text transport shape; no Reader/OCR/native API fake."""
import json
import unittest
import log_transport as transport


class LogTransportTests(unittest.TestCase):
    def test_large_unicode_single_line_round_trips_exact_bytes_through_bounded_timestamped_lines(self):
        raw = (json.dumps({'fictional': '架空科目' * 150000}, ensure_ascii=False) + '\n').encode()
        lines = list(transport.encode(raw, 'fixed/stdout'))
        self.assertGreater(len(raw), 1024 * 1024)
        self.assertTrue(all(len(line.encode()) < 8192 for line in lines))
        log = '\n'.join('2026-10-04T00:00:00Z ' + line for line in lines)
        self.assertEqual(transport.restore(log), {'fixed/stdout': raw})

    def test_missing_duplicated_and_reordered_chunks_never_become_complete(self):
        lines = list(transport.encode(b'fictional' * 2000, 'fixed/stdout'))
        for changed in [lines[:1] + lines[2:], lines[:2] + lines[1:], [lines[0], lines[2], lines[1]] + lines[3:], lines[:-1]]:
            with self.assertRaises((AssertionError, KeyError)):
                transport.restore('\n'.join(changed))

    def test_valid_base64_corruption_fails_full_byte_sha_check(self):
        lines = list(transport.encode(b'fictional' * 2000, 'fixed/stdout'))
        value = json.loads(lines[1][len(transport.PREFIX):])
        value['base64'] = ('A' if value['base64'][0] != 'A' else 'B') + value['base64'][1:]
        lines[1] = transport.PREFIX + json.dumps(value)
        with self.assertRaises(AssertionError):
            transport.restore('\n'.join(lines))

    def test_empty_stderr_has_explicit_zero_byte_receipt(self):
        self.assertEqual(transport.restore('\n'.join(transport.encode(b'', 'baseline/stderr'))), {'baseline/stderr': b''})


if __name__ == '__main__':
    unittest.main()
