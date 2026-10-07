import importlib.util
import json
import os
import signal
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('diagnostics', ROOT / 'tools/manual_ui_diagnostics.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ManualDiagnosticsTests(unittest.TestCase):
    def test_command_timeout_and_output_cap_are_explicit(self):
        slow = module.command([sys.executable, '-c', 'import time;time.sleep(2)'], timeout=.1)
        self.assertEqual(slow['limited'], 'timeout')
        self.assertLess(slow['seconds'], 1)
        noisy = module.command([sys.executable, '-c', 'print("x"*8192)'], cap=512)
        self.assertEqual(noisy['limited'], 'output-cap')
        self.assertLessEqual(len(noisy['text']), 512)

    def test_sigterm_reaps_owned_command_and_keeps_signal_exit(self):
        with tempfile.TemporaryDirectory() as tmp:
            pid_file = Path(tmp) / 'child.pid'
            child = 'import os,time;from pathlib import Path;Path(' + repr(str(pid_file)) + ').write_text(str(os.getpid()));time.sleep(10)'
            script = ('import importlib.util,signal,sys;'
                      's=importlib.util.spec_from_file_location("d",' + repr(str(ROOT / 'tools/manual_ui_diagnostics.py')) + ');'
                      'd=importlib.util.module_from_spec(s);s.loader.exec_module(d);'
                      'signal.signal(signal.SIGTERM,d.interrupted);'
                      'd.command([sys.executable,"-c",' + repr(child) + '],timeout=10)')
            parent = subprocess.Popen([sys.executable, '-c', script])
            try:
                until = time.monotonic() + 3
                while not pid_file.exists() and time.monotonic() < until:
                    time.sleep(.02)
                self.assertTrue(pid_file.exists())
                pid = int(pid_file.read_text())
                parent.send_signal(signal.SIGTERM)
                self.assertEqual(parent.wait(timeout=3), 143)
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
            finally:
                if parent.poll() is None:
                    parent.kill()
                    parent.wait(timeout=2)

    def test_crash_capture_filters_exact_app_time_size_and_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Takupoke.ips'
            now = time.time()
            path.write_text('{"bundleID":"jp.n624.takupoke.app-checks","app_name":"Takupoke","exception":"SIGABRT"}')
            report = module.report_matches(path, now - 1)
            self.assertIn('SIGABRT', report['text'])
            self.assertEqual(report['bytes'], len(path.read_bytes()))
            path.write_text(json.dumps({'app_name': module.PROCESS, 'bundleID': module.BUNDLE}) + '\n' +
                            json.dumps({'procName': module.PROCESS, 'bundleInfo': {'CFBundleIdentifier': module.BUNDLE}, 'exception': 'SIGABRT'}))
            self.assertEqual(module.report_matches(path, now - 1)['scope'], 'exact-app-crash')
            self.assertIsNone(module.report_matches(path, now + 10))
            alias = Path(tmp) / 'alias.ips'
            alias.symlink_to(path)
            self.assertIsNone(module.report_matches(alias, now - 1))
            path.write_text('{"bundleID":"unrelated.private.app"}')
            self.assertIsNone(module.report_matches(path, now - 1))
            path.write_bytes(b'x' * (module.MAX_REPORT + 1))
            self.assertIsNone(module.report_matches(path, now - 1))

    def test_crash_identity_rejects_prefix_helper_and_arbitrary_mentions(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Other.ips'
            for payload in (
                {'bundleID': module.BUNDLE + '-helper', 'app_name': 'DifferentApp'},
                {'bundleID': 'com.example.other', 'app_name': 'DifferentApp', 'message': module.BUNDLE},
                {'bundleID': module.BUNDLE, 'app_name': 'Takupoke-helper'},
            ):
                path.write_text(json.dumps(payload))
                self.assertIsNone(module.report_matches(path, time.time() - 1))

    def test_jetsam_exports_only_exact_app_entry(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Jetsam.ips'
            header = {'bug_type': '298', 'timestamp': 'fictional-time'}
            payload = {'reason': 'memory-pressure', 'processes': [
                {'name': 'Takupoke', 'pid': 123, 'reason': 'per-process-limit'},
                {'name': 'OtherPrivateProcess', 'pid': 456},
                {'name': 'Takupoke-helper', 'pid': 789},
            ]}
            path.write_text(json.dumps(header) + '\n' + json.dumps(payload))
            self.assertIsNone(module.report_matches(path, time.time() - 1))
            result = module.report_matches(path, time.time() - 1, allow_jetsam=True)
            self.assertIsNotNone(result)
            self.assertNotIn('OtherPrivateProcess', result['text'])
            self.assertNotIn('Takupoke-helper', result['text'])
            self.assertIn('per-process-limit', result['text'])
            self.assertEqual(result['scope'], 'exact-app-jetsam-entry')

    def test_legacy_crash_requires_exact_identity_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'Takupoke.crash'
            valid = 'Process: Takupoke [123]\nIdentifier: ' + module.BUNDLE + '\nException Type: SIGABRT\n'
            path.write_text(valid)
            self.assertIsNotNone(module.report_matches(path, time.time() - 1))
            path.write_text('Process: DifferentApp [456]\nIdentifier: com.example.other\nMessage: ' + module.BUNDLE)
            self.assertIsNone(module.report_matches(path, time.time() - 1))

    def test_legacy_failure_excludes_attachment_payloads(self):
        result = {'issues': {'testFailureSummaries': {'_values': [
            {'message': {'_value': 'Application is not running'},
             'testCaseName': {'_value': 'ManualChecks.testOne'},
             'attachments': [{'payload': 'SCREENSHOT_BASE64'}]}]}}}
        failures = module.legacy_failures(result)
        self.assertEqual(failures[0]['message'], 'Application is not running')
        self.assertNotIn('SCREENSHOT_BASE64', json.dumps(failures))

    def test_always_collection_retains_original_exit_when_tools_fail(self):
        # Execute the exact cleanup function, substituting harmless external commands.
        source = (ROOT / 'tools/test-manual-ui.sh').read_text()
        function = source[source.index('cleanup() {'):source.index('\ntrap cleanup EXIT')]
        shell = '''set -eu
scratch_dir=owned-scratch
simulator_id=owned-simulator
diagnostic_started=0
TKPK_MANUAL_DIAGNOSTICS=1
python3() { echo diagnostic-before-delete; return 6; }
xcrun() { echo "$*"; }
rm() { echo delete-owned-scratch; }
''' + function + '\ntrap cleanup EXIT\nexit 7\n'
        run = subprocess.run(['bash', '-c', shell], text=True, capture_output=True)
        self.assertEqual(run.returncode, 7)
        self.assertEqual(run.stdout.splitlines()[0], 'diagnostic-before-delete')
        self.assertEqual(run.stdout.splitlines()[-1], 'delete-owned-scratch')

    def test_collection_tool_errors_stay_unknown_no_binary_payload(self):
        with tempfile.TemporaryDirectory() as tmp:
            scratch = Path(tmp)
            (scratch / 'ManualResults.xcresult').mkdir()
            with patch.object(module, 'command', side_effect=OSError('unsupported tool')), \
                 patch.object(module.Path, 'home', return_value=scratch), \
                 patch('builtins.print') as printed:
                module.collect(scratch, 'owned-simulator', time.time(), 143)
            record = json.loads(printed.call_args.args[0].split(' ', 1)[1])
            self.assertEqual(record['originalExit'], 143)
            self.assertEqual(record['crashCause'], 'unassessed')
            self.assertEqual(record['matchingTextReports'], 0)
            self.assertEqual(record['xcresultError'], 'OSError')
            self.assertEqual(record['logError'], 'OSError')

    def test_assertions_completion_guard_and_result_bundle_remain(self):
        runner = (ROOT / 'tools/test-manual-ui.sh').read_text()
        checks = (ROOT / 'tests/ui/ManualAssistanceChecks.swift').read_text()
        self.assertIn('-resultBundlePath "$scratch_dir/ManualResults.xcresult"', runner)
        self.assertNotIn('-collect-test-diagnostics on-failure', runner)
        self.assertIn('-collect-test-diagnostics never', runner)
        project = (ROOT / 'Takupoke.xcodeproj/project.pbxproj').read_text()
        self.assertIn('productName = ' + module.PROCESS + ';', project)
        self.assertIn("settings['PRODUCT_BUNDLE_IDENTIFIER']='" + module.BUNDLE + "'", (ROOT / 'tools/app_test_project.py').read_text())
        self.assertIn('${TKPK_MANUAL_DIAGNOSTICS:-0}', runner)
        self.assertIn("any(status!='passed' for _,status in rows)", runner)
        self.assertIn('app.wait(for:.runningForeground,timeout:10)', checks)
        self.assertLess(checks.index('guard app.state != .notRunning'), checks.index('        app.activate()'))
        self.assertIn('XCTAssertEqual(ids.count,3)', checks)
        self.assertIn('adopted=1;valid=true', checks)
        self.assertIn('launch(["--manual-four"])', checks)
        self.assertIn('XCTAssertFalse(submit.exists)', checks)


if __name__ == '__main__':
    unittest.main()
