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
sys.path.insert(0, str(ROOT / "tools"))
from ui_test_manifest import manual_check_source

spec = importlib.util.spec_from_file_location('diagnostics', ROOT / 'tools/manual_ui_diagnostics.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ManualDiagnosticsTests(unittest.TestCase):
    def test_owned_launch_trace_exports_only_fixed_stages_and_rejects_unknown_content(self):
        stages=('init-enter','seed-enter','seed-complete','scene-construction','content-appeared',
                'root-task-enter','application-ready','fixture-ready','fixture-ready-timeout',
                'year-input-observer-installed','year-edit-began','year-edit-ended','year-edit-changed',
                'year-keyboard-will-show','year-keyboard-did-show','year-keyboard-will-hide','year-keyboard-did-hide')
        valid=['TAKUPOKE_LIFECYCLE pid=123 time=42.25 stage='+stage for stage in stages]
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'owned.log'
            path.write_text('\n'.join(valid+[valid[0]+' private body',valid[0].replace('init-enter','unknown'),
                valid[0].replace('pid=123','pid=private'),valid[0].replace('time=42.25','time=nan'),
                'arbitrary app content']),encoding='utf-8')
            self.assertEqual(module.launch_trace_lines(path),valid)
            alias=Path(tmp)/'alias';alias.symlink_to(path)
            self.assertEqual(module.launch_trace_lines(alias),[])
            path.write_text((valid[0]+'\n')*129,encoding='utf-8')
            self.assertEqual(module.launch_trace_lines(path),[valid[0]]*128)
            path.write_bytes(b'X'*65537);self.assertEqual(module.launch_trace_lines(path),[])
            path.write_bytes(b'\xff');self.assertEqual(module.launch_trace_lines(path),[])

    def test_owned_input_trace_is_bounded_and_rejects_body_symlinks_and_invalid_encoding(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'owned.log'
            valid = 'TAKUPOKE_INPUT pid=123 time=42.25 phase=began x=331.50 y=672.67 views=UIKit.UISwitch,UIKit.UIView'
            invalid = [valid.replace('phase=began', 'phase=changed'), valid.replace('x=331.50', 'x=nan'),
                       valid + ' arbitrary-body', '{"unrelated":"content"}', valid.replace('views=UIKit.UISwitch,UIKit.UIView', 'views=invalid value')]
            path.write_text('\n'.join([valid] + invalid), encoding='utf-8')
            self.assertEqual(module.input_trace_lines(path), [valid])
            observed = valid + ' gestures=ScrollPan:3:1:0:1,Tap:5:0:0:0'
            none = valid + ' gestures=none'
            invalid_gestures = [observed.replace('ScrollPan:3', 'ScrollPan:6'),
                                observed.replace('Tap:5:0', 'Tap:5:2'),
                                observed + ',Tap:0:1:0:1' * 5,
                                valid + ' gestures=private content', observed + ' body']
            path.write_text('\n'.join([observed, none] + invalid_gestures), encoding='utf-8')
            self.assertEqual(module.input_trace_lines(path), [observed, none])
            native = observed + ' native=0:0:0/1:0:0'
            absent = none + ' native=none'
            path.write_text('\n'.join([native, absent, native + ' private body',
                native.replace('native=0:', 'native=2:'), native + '/0:0:0']), encoding='utf-8')
            self.assertEqual(module.input_trace_lines(path), [native, absent])
            press = 'TAKUPOKE_PRESS pid=123 time=42.25 phase=ended touchTime=10.500000 eventTime=10.500000 recognizers=5:500:10000:0:1'
            no_press = press.replace('5:500:10000:0:1', 'none')
            invalid_presses = [press + ' private body', press.replace('touchTime=10.500000', 'touchTime=nan'),
                press.replace('recognizers=5:', 'recognizers=6:'), press + ',5:500:10000:0:1' * 6,
                press.replace(':0:1', ':0:11'), press.replace('recognizers=5:500:10000:0:1', 'recognizers=private text')]
            path.write_text('\n'.join([native,press,no_press] + invalid_presses),encoding='utf-8')
            self.assertEqual(module.input_trace_lines(path),[native,press,no_press])
            alias = Path(tmp) / 'alias.log'
            alias.symlink_to(path)
            self.assertEqual(module.input_trace_lines(alias), [])
            path.write_text((valid + '\n') * 129, encoding='utf-8')
            self.assertEqual(len(module.input_trace_lines(path)), 128)
            path.write_bytes(b'x' * 65537)
            self.assertEqual(module.input_trace_lines(path), [])
            path.write_bytes(b'\xff')
            self.assertEqual(module.input_trace_lines(path), [])

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
        function = source[source.index('stage() {'):source.index('\ntrap cleanup EXIT')]
        shell = '''set -eu
scratch_dir=owned-scratch
simulator_id=owned-simulator
diagnostic_started=0
TKPK_MANUAL_DIAGNOSTICS=1
python3() {
    if [[ "$2" == tools/manual_ui_diagnostics.py ]]; then
        echo diagnostic-before-delete >> "$CALLS"
        return 6
    fi
    [[ "$2" == tools/timed_command.py && "$3 $4 $5 $6" == '--timeout 10 --cleanup-grace 3' ]] || exit 99
    shift 7
    "$@"
}
xcrun() { echo "$*" >> "$CALLS"; return 9; }
rm() { echo "delete-$*" >> "$CALLS"; }
''' + function + '\ntrap cleanup EXIT\nexit "$ORIGINAL_EXIT"\n'
        with tempfile.TemporaryDirectory() as directory:
            calls = Path(directory) / 'calls'
            for original_exit in (0, 7, 143):
                with self.subTest(original_exit=original_exit):
                    calls.write_text('')
                    run = subprocess.run(['bash', '-c', shell], text=True, capture_output=True,
                                         env=os.environ | {'CALLS': str(calls), 'ORIGINAL_EXIT': str(original_exit)})
                    self.assertEqual(run.returncode, original_exit, run.stderr)
                    self.assertEqual(calls.read_text().splitlines(), [
                        'diagnostic-before-delete', 'simctl shutdown owned-simulator',
                        'simctl delete owned-simulator', 'delete--rf owned-scratch'])
                    self.assertEqual(run.stdout.splitlines(), [
                        'TAKUPOKE_MANUAL_RUNNER stage=' + stage for stage in (
                            'cleanup-enter', 'cleanup-diagnostics-enter', 'cleanup-shutdown-enter',
                            'cleanup-delete-enter', 'cleanup-files-enter', 'cleanup-complete')])

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
        checks = manual_check_source()
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
