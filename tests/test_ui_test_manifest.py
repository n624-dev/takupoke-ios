"""Test selection, completion checks and the shell runner without Apple tools."""
import json
import io
from contextlib import redirect_stdout
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import release_gate
import ui_test_manifest as manifest
import app_test_project


def result_line(test, status="passed"):
    return f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).\n"


class ManifestTests(unittest.TestCase):
    def test_split_sources_are_registered_in_the_selected_target_only(self):
        project = {'rootObject': 'project', 'objects': {
            'project': {'mainGroup': 'group'}, 'group': {'children': []},
            'app': {'buildPhases': ['app-sources']},
            'test': {'buildPhases': ['test-sources']},
            'app-sources': {'isa': 'PBXSourcesBuildPhase', 'files': []},
            'test-sources': {'isa': 'PBXSourcesBuildPhase', 'files': []},
        }}
        paths = [ROOT / 'tests/ui' / name for name in manifest.CHECK_SOURCES[1:]]
        app_test_project.add_swift_sources(project, 'test', paths, '9B')
        support = ROOT / 'tests/Support/ObservedScreenGeometry.swift'
        app_test_project.add_swift_sources(project, 'test', [support], '9C')
        objects = project['objects']
        registered = [objects[objects[key]['fileRef']]['path']
                      for key in objects['test-sources']['files']]
        self.assertEqual(registered, [str(path) for path in paths] + [str(support)])
        self.assertEqual(objects['app-sources']['files'], [])
        self.assertEqual(len(objects['group']['children']), len(paths) + 1)
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            app_test_project.add_swift_sources(project, 'test', paths, '9B')

    def test_unregistered_split_file_is_rejected(self):
        with tempfile.TemporaryDirectory(prefix='takupoke-ui-source-check-') as directory:
            root = Path(directory)
            folder = root / 'tests/ui'
            folder.mkdir(parents=True)
            for name in manifest.CHECK_SOURCES:
                shutil.copyfile(ROOT / 'tests/ui' / name, folder / name)
            self.assertEqual(manifest.check_source(root), manifest.check_source())
            (folder / 'ApplicationChecks+Unregistered.swift').write_text('func testForgotten() {}')
            with self.assertRaisesRegex(ValueError, 'registered'):
                manifest.check_source(root)

    def test_manual_split_registers_all_helpers_and_refuses_unknown_files(self):
        with tempfile.TemporaryDirectory(prefix='takupoke-manual-source-check-') as directory:
            root = Path(directory)
            folder = root / 'tests/ui'
            folder.mkdir(parents=True)
            for name in manifest.MANUAL_CHECK_SOURCES:
                shutil.copyfile(ROOT / 'tests/ui' / name, folder / name)
            self.assertEqual(manifest.manual_check_source(root), manifest.manual_check_source())
            (folder / 'ManualAssistanceChecks+Unregistered.swift').write_text('func testMissing() {}')
            with self.assertRaisesRegex(ValueError, 'registered'):
                manifest.manual_check_source(root)

    def test_network_rewrite_preserves_standard_xlsx_identifiers_only(self):
        source = (ROOT / "Takupoke/XLSXReader.swift").read_text(encoding="utf-8")
        rewritten = app_test_project.rewrite_network_urls(source)
        for namespace in (
            "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
            "http://schemas.openxmlformats.org/package/2006/relationships",
            "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
        ):
            self.assertIn('"' + namespace + '"', rewritten)
        endpoints = 'let url = "https://files.example.invalid/source"; let other = "http://schemas.openxmlformats.org/spreadsheetml/2006/main?fetch=1"'
        changed = app_test_project.rewrite_network_urls(endpoints)
        self.assertEqual(changed.count('"https://fixture.example.test"'), 2)
        self.assertNotIn("files.example.invalid", changed)
        self.assertNotIn("fetch=1", changed)

    def test_ai_switch_probe_preserves_production_setter_and_rejects_marker_drift(self):
        source = (ROOT / "Takupoke/SettingsView.swift").read_text(encoding="utf-8")
        generated = app_test_project.instrument_ai_switch(source)
        self.assertNotIn("FixtureLaunchDiagnostics", source)
        self.assertEqual(generated.count(app_test_project.AI_SWITCH_BEFORE), 1)
        self.assertEqual(generated.count(app_test_project.AI_SWITCH_AFTER), 1)
        self.assertEqual(generated.replace(app_test_project.AI_SWITCH_BEFORE, "", 1)
                         .replace(app_test_project.AI_SWITCH_AFTER, "", 1), source)
        marker = 'useAiFeatures = $0; LocalAIFeaturePolicy.setEnabled($0)'
        for changed in (source.replace(marker, ""), source + "\n" + marker):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_ai_switch(changed)

    def test_notification_switch_trace_preserves_setters_and_rejects_marker_drift(self):
        source = (ROOT / "Takupoke/NotificationSettingsView.swift").read_text(encoding="utf-8")
        generated = app_test_project.instrument_notification_switch(source)
        self.assertNotIn("FixtureLaunchDiagnostics", source)
        self.assertEqual(generated.count(app_test_project.NOTIFICATION_BINDING_TRACE), 2)
        self.assertEqual(generated.replace(app_test_project.NOTIFICATION_BINDING_TRACE, ""), source)
        for changed in (source.replace("set: { value in", "set: { other in", 1), source + source):
            with self.assertRaises(AssertionError):
                app_test_project.instrument_notification_switch(changed)

    def test_notification_readiness_probe_observes_os_without_granting_or_saving(self):
        fixture = (ROOT / "tests/ui/ApplicationFixture.swift").read_text(encoding="utf-8")
        probe = fixture.split("private struct FixtureNotificationPermissionTouch: View", 1)[1]
        self.assertIn("await UNUserNotificationCenter.current().notificationSettings()", probe)
        self.assertIn("settings.authorizationStatus.rawValue", probe)
        self.assertIn("UIApplication.shared.applicationState.rawValue", probe)
        self.assertIn("@Environment(\\.scenePhase)", probe)
        self.assertIn(".task(id:phase)", probe)
        self.assertNotRegex(probe, r"requestAuthorization|setEnabled|UserDefaults\.standard\.set\(")
        checks = (ROOT / "tests/ui/ApplicationChecks+Notifications.swift").read_text(encoding="utf-8")
        self.assertLess(checks.index("OS notification settings did not respond"),
                        checks.index("tapNativeSwitch(toggle, atCenter: true)"))
        self.assertEqual(checks.count("tapNativeSwitch(toggle, atCenter: true)"), 1)

    def test_owned_launch_trace_filters_other_content_and_refuses_symlinks_and_large_files(self):
        runner = (ROOT / "tools/test-app-ui.sh").read_text(encoding="utf-8")
        collector = runner.split("<<'PY_TRACE'\n", 1)[1].split("\nPY_TRACE", 1)[0]
        allowed = "TAKUPOKE_AI_SWITCH pid=123 time=1791534293.0 phase=before requested=1 stored=0"
        lifecycle = "TAKUPOKE_LIFECYCLE pid=123 time=1791534293.0 stage=application-ready"
        query = lifecycle.replace("application-ready", "notification-settings-enter")
        binding = lifecycle.replace("application-ready", "notification-on-binding")
        removed = "TAKUPOKE_HIT_PATH pid=123 touch=UIView~UISwitch thumb=UIView~UISwitch opposite=UIView~UISwitch"
        with tempfile.TemporaryDirectory(prefix="takupoke-launch-collector-") as directory:
            root = Path(directory)
            owned = root / "tmp/takupoke-fictional-launch-owned.log"
            owned.parent.mkdir()
            def collect():
                output = io.StringIO()
                response = subprocess.CompletedProcess([], 0, stdout=str(root) + "\n")
                with patch.object(subprocess, "run", return_value=response) as call, \
                     patch.object(sys, "argv", ["collector", "owned-simulator"]), redirect_stdout(output):
                    exec(compile(collector, "owned-trace-collector", "exec"), {})
                self.assertEqual(call.call_args.args[0], [
                    "xcrun", "simctl", "get_app_container", "owned-simulator",
                    "jp.n624.takupoke.app-checks", "data"])
                return output.getvalue()
            owned.write_text(allowed + "\n" + lifecycle + "\n" + query + "\n" + binding + "\n" + removed +
                "\n架空の診断対象外本文\n" +
                allowed.replace("requested=1", "requested=架空の本文") + "\n",
                encoding="utf-8")
            self.assertEqual(collect(), allowed + "\n" + lifecycle + "\n" + query + "\n" + binding + "\n")
            owned.write_bytes(b"x" * 65537)
            self.assertEqual(collect(), "TAKUPOKE_LIFECYCLE capture-missing-or-limited\n")
            owned.unlink()
            other = root / "other-owned.txt"
            other.write_text(allowed, encoding="utf-8")
            owned.symlink_to(other)
            self.assertEqual(collect(), "TAKUPOKE_LIFECYCLE capture-missing-or-limited\n")

    def test_picker_completion_rejects_missing_failed_skipped_duplicate_and_unknown_cases(self):
        runner = (ROOT / "tools/test-picker-ui.sh").read_text(encoding="utf-8")
        program = runner.split("<<'PY_PICKER'\n", 1)[1].split("\nPY_PICKER", 1)[0]
        names = ("testInstructionSurroundMatchesFilesBackground", "testReselectionWithMissingAppearanceReturn", "testReselectionThroughActualButtons")
        def row(name, status="passed"):
            return f"Test Case '-[PickerTapChecks.MaterialPickerTapChecks {name}]' {status} (1.0 seconds).\n"
        complete = "".join(row(name) for name in names)
        with tempfile.TemporaryDirectory() as scratch:
            log = Path(scratch) / "picker.log"
            cases = [(complete, True), ("", False), (row(names[0]), False),
                     (complete + row(names[0]), False), (complete + row("testUnknown"), False),
                     (complete.replace(row(names[0]), row(names[0], "failed")), False),
                     (complete.replace(row(names[0]), row(names[0], "skipped")), False)]
            for text, accepted in cases:
                log.write_text(text, encoding="utf-8")
                result = subprocess.run([sys.executable, "-c", program, str(log)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)

    def test_event_cache_probe_changes_only_automatic_startup_in_isolated_copy(self):
        source = (ROOT / "Takupoke/SchoolEventsModel.swift").read_text(encoding="utf-8")
        self.assertNotIn("--events-cache-", source)
        generated = app_test_project.instrument_events_cache(source)
        insertion = generated[len(source.split('    func refreshAtStartup() {')[0]):].split('        loadIfNeeded()', 2)
        self.assertIn('"--events-cache-corrupt"', insertion[0])
        self.assertIn('"--events-cache-probe"', insertion[0])
        self.assertIn('SimulatorEventsYearFixture.enabled', insertion[0])
        self.assertIn('return', insertion[1])
        # Actual manual fetch, response validation, persistence and background
        # refresh remain byte-for-byte identical; no fabricated model readiness.
        self.assertEqual(source.split('    func fetch(year: Int) {', 1)[1],
                         generated.split('    func fetch(year: Int) {', 1)[1])

    def test_native_ocr_probe_preserves_actual_multiline_confidence_guard(self):
        source = (ROOT / "Takupoke/RecoveryVisionCapture.swift").read_text(encoding="utf-8")
        recognition = (ROOT / "Takupoke/PDFRecoveryRecognition.swift").read_text(encoding="utf-8")
        assessment = (ROOT / "Takupoke/RecoveryOCRAcquisition.swift").read_text(encoding="utf-8")
        self.assertNotIn("--recovery-ocr-probe", source)
        generated = app_test_project.instrument_native_ocr(source)
        probe = app_test_project.NATIVE_OCR_DIAGNOSTIC
        self.assertEqual(generated.count(probe), 1)
        self.assertEqual(generated.replace(probe, "", 1), source)
        self.assertNotIn("--recovery-ocr-probe", recognition)
        generator=(ROOT / "tools/app_test_project.py").read_text(encoding="utf-8")
        self.assertIn("if path.name == 'RecoveryVisionCapture.swift':\n            text = instrument_native_ocr(text)", generator)
        marker='                lines.append(try captureLine(line, order: lines.count, hierarchy: false))'
        for changed in (source.replace(marker, ""), source+"\n"+marker):
            with self.assertRaises(AssertionError): app_test_project.instrument_native_ocr(changed)
        self.assertIn("SYNTHETIC_NATIVE_OCR", probe)
        self.assertIn("let captured = lines.last?.candidates.first", probe)
        self.assertIn("$0.lineRange", probe)
        self.assertIn("$0.observationRange", probe)
        self.assertNotIn("topCandidates(", probe)
        self.assertNotRegex(probe, r"\b(?:lines|candidates|characters)\.(?:append|remove|sort)")
        acquire = recognition.split("static func acquire(", 1)[1].split("private static func snapshotHash(", 1)[0]
        for retained in (
                "for candidate in line.topCandidates(5) {",
                "let text = candidate.string",
                "candidate.boundingBox(for: start..<end)",
                "characters.append(RecoveryOCRCharacter(text: characterText, range: range))",
                "lineRange: wholeRange, observationRange:observationRange",
                "lines.append(try captureLine(line, order: lines.count, hierarchy: false))",
                "nativeDocumentCount: observations.count, lines: lines, captureComplete: true"):
            self.assertIn(retained, source)
        self.assertLess(generated.index("lines.append(try captureLine(line"), generated.index("SYNTHETIC_NATIVE_OCR"))
        self.assertLess(generated.index("SYNTHETIC_NATIVE_OCR"), generated.index("var tables ="))
        self.assertIn("hierarchy: true", source)
        for retained in ("for number in required {", "RecoveryVisionCapture.page(", "requiredOCRPages: required, pages: output"):
            self.assertIn(retained, acquire)
        self.assertNotIn("0.85", acquire)
        self.assertNotIn(".assess(", acquire)

        # Confidence still rejects nonfinite/out-of-range candidates. Only original
        # top-one confidence controls the unchanged inclusive .85 direct gate.
        assess = assessment.split("func assess(", 1)[1]
        guard = assess.split("guard !candidate.text.isEmpty,", 1)[1].split("else", 1)[0]
        self.assertIn("candidate.confidence.isFinite", guard)
        self.assertIn("(0...1).contains(candidate.confidence)", guard)
        self.assertIn("pages.count == requiredOCRPages.count", assess)
        self.assertIn(r"pages.map(\.page) == requiredOCRPages", assess)
        self.assertLess(assess.index("guard page.captureComplete"), assess.index("candidate.confidence.isFinite"))
        self.assertIn("let top1 = line.candidates[0]", assess)
        self.assertIn("if top1.confidence < 0.85 { low[page.page, default: []].append(order) }", assess)
        self.assertIn(r"lowConfidenceNativeOrders.values.allSatisfy(\.isEmpty)", assessment)
        strict = recognition.split("func strictLayouts(", 1)[1].split("private func makeLayouts(", 1)[0]
        self.assertLess(strict.index("acquisition.strictAssessment(check: check)"), strict.index("guard assessment.directLayoutsAllowed"))
        self.assertLess(strict.index("guard assessment.directLayoutsAllowed"), strict.index("return try makeLayouts(check: check)"))
        self.assertIn("return try await acquire(url, only: only, check: check).strictLayouts(check: check)", recognition)

    def test_all_source_tests_are_assigned_once_and_both_os_checks_are_required(self):
        manifest.validate_source(manifest.check_source())
        self.assertEqual(len(manifest.selected_tests("all")), 27)
        self.assertTrue(all(manifest.SHARDS[shard] for shard in ("A", "B")))
        self.assertFalse(set(manifest.SHARDS["A"]) & set(manifest.SHARDS["B"]))
        self.assertEqual(release_gate.REQUIRED, manifest.ALL_UI_REQUIRED_JOBS | {"Distribution tests", "Native PDF and recovery tests"})
        self.assertIn(manifest.SYSTEM_SIZE_TEST, manifest.SHARDS["B"])

    def test_missing_obsolete_or_duplicate_source_tests_fail(self):
        source = manifest.check_source()
        for altered in (source + "\nfunc testNewCase() {}",
                        source.replace("testMergedCardsFromAllSources", "testRenamedCase"),
                        source + "\nfunc testMergedCardsFromAllSources() {}"):
            with self.subTest(source=altered[-45:]), self.assertRaises(ValueError):
                manifest.validate_source(altered)

    def test_overlapping_manifest_is_rejected(self):
        with patch.dict(manifest.SHARDS, {"B": manifest.SHARDS["B"] + manifest.SHARDS["A"][:1]}):
            with self.assertRaisesRegex(ValueError, "duplicate tests"):
                manifest.validate_source(manifest.check_source())

    def test_passed_results_with_only_the_declared_voiceover_exception(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                expected = manifest.selected_tests(shard)
                log = "unrelated Xcode output\n" + "".join(result_line(
                    test, "skipped" if ios == 26 and test == manifest.VOICEOVER_TEST else "passed"
                ) for test in expected)
                manifest.validate_results(log, expected, ios)

    def test_empty_missing_extra_and_duplicate_results_fail(self):
        expected = manifest.selected_tests("A")
        log = "".join(result_line(test) for test in expected)
        for altered in ("", log.replace(result_line(expected[0]), ""),
                        log + result_line("testUnexpected"), log + result_line(expected[0])):
            with self.subTest(log=altered[-80:]), self.assertRaises(ValueError):
                manifest.validate_results(altered, expected, 27)

    def test_failure_and_unexpected_skip_fail(self):
        for test, ios, status in ((manifest.SYSTEM_SIZE_TEST, 26, "skipped"),
                                   (manifest.SYSTEM_SIZE_TEST, 27, "failed"),
                                   (manifest.VOICEOVER_TEST, 27, "skipped"),
                                   (manifest.VOICEOVER_TEST, 26, "passed")):
            with self.subTest(test=test, ios=ios, status=status), self.assertRaises(ValueError):
                manifest.validate_results(result_line(test, status), (test,), ios)

    def test_workflow_matrix_matches_gate_and_publish_follows_gate(self):
        workflow = (ROOT / ".github/workflows/ios-release.yml").read_text(encoding="utf-8")
        simulator = workflow.split("  simulator:\n", 1)[1].split("  build-check:\n", 1)[0]
        entries = re.findall(r"- ios: (26|27)\n\s+shard: ([AB])", simulator)
        self.assertEqual(len(entries), 4)
        self.assertEqual({f"Application iOS {ios} UI {shard}" for ios, shard in entries},
                         manifest.REQUIRED_JOBS)
        self.assertIn("name: Application iOS ${{ matrix.ios }} UI ${{ matrix.shard }}", simulator)
        self.assertIn("TKPK_UI_SHARD: ${{ matrix.shard }}", simulator)
        release = workflow.split("  release:\n", 1)[1]
        self.assertIn("needs: checks\n", release)
        self.assertIn("actions: read", release)
        self.assertLess(release.index("tools/release_gate.py"), release.index("tools/publish.py"))

    def test_manual_matrix_requires_every_unchanged_case_on_both_os_separately(self):
        workflow = (ROOT / ".github/workflows/ios-release.yml").read_text(encoding="utf-8")
        manual = workflow.split("  manual:\n", 1)[1].split("  build-check:\n", 1)[0]
        self.assertIn("ios: [26, 27]", manual)
        cases = re.findall(r"^          - (test\w+)$", manual, re.MULTILINE)
        self.assertEqual(cases, list(manifest.MANUAL_CASES))
        declared = re.findall(r"\bfunc\s+(test\w+)\s*\(", manifest.manual_check_source())
        self.assertCountEqual(cases, declared)
        self.assertEqual(len(declared), 3)
        expanded = {f"Manual correction iOS {ios} / {case}" for ios in (26, 27) for case in cases}
        self.assertEqual(expanded, manifest.MANUAL_REQUIRED_JOBS)
        self.assertEqual(len(expanded), 6)
        self.assertEqual(len(manifest.ALL_UI_REQUIRED_JOBS), 10)
        self.assertEqual(len(release_gate.REQUIRED), 12)  # Main builds its IPA in the publishing job.
        self.assertIn("name: Manual correction iOS ${{ matrix.ios }} / ${{ matrix.case }}", manual)
        self.assertIn("TKPK_MANUAL_CASE: ${{ matrix.case }}", manual)
        self.assertIn("TKPK_TEST_IOS: ${{ matrix.ios }}", manual)
        self.assertIn("ref: ${{ github.sha }}", manual)
        self.assertIn('test "$(git rev-parse HEAD)" = "$GITHUB_SHA"', manual)
        self.assertIn("fail-fast: false", manual)
        self.assertIn("timeout-minutes: 45", manual)
        self.assertIn("bash tools/test-manual-ui.sh", manual)
        self.assertNotIn("continue-on-error", manual)
        self.assertEqual(manual.count("TKPK_MANUAL_DIAGNOSTICS: '1'"), 1)
        self.assertEqual(workflow.count("TKPK_MANUAL_DIAGNOSTICS"), 1)
        for ios, runner, xcode in ((26, "macos-26", "26.6"), (27, "xcode-27", "27.0")):
            self.assertIn(f"- ios: {ios}\n            runner: {runner}\n            developer: /Applications/Xcode_{xcode}.app/Contents/Developer", manual)
        simulator = workflow.split("  simulator:\n", 1)[1].split("  manual:\n", 1)[0]
        self.assertIn("timeout-minutes: 45", simulator)
        self.assertNotIn("test-manual-ui.sh", simulator)
        self.assertIn("bash tools/test-app-ui.sh", simulator)

    def test_cli_selects_the_complete_shard_and_rejects_invalid_shard(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        selected = subprocess.check_output(command + ["--shard", "A", "--mode", "selectors"], text=True)
        self.assertEqual(selected.splitlines(), [
            "-only-testing:PickerTapChecks/ApplicationChecks/" + test for test in manifest.SHARDS["A"]])
        invalid = subprocess.run(command + ["--shard", "C", "--mode", "selectors"],
                                 capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)

    def test_cli_reads_japanese_source_with_non_utf8_default_encoding(self):
        environment = os.environ | {"LC_ALL": "C", "PYTHONCOERCECLOCALE": "0", "PYTHONUTF8": "0"}
        result = subprocess.run([sys.executable, "-X", "utf8=0", "-B",
            str(ROOT / "tools/ui_test_manifest.py"), "--shard", "A", "--mode", "selectors"],
            env=environment, capture_output=True, text=True, encoding="utf-8")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), len(manifest.SHARDS["A"]))

    def test_relaunch_diagnosis_cannot_replace_the_full_shard_gate(self):
        self.assertEqual(manifest.RELAUNCH_PROBE_TESTS, (
            "testChangedAccountDataNoticeOpensSharedAcquisition",
            "testChangedDataProducesOneLocalNotification",
            "testHomeAndTimetableDetailsCloseForSavedUpdatesButRemainDuringBusyWork",
            "testLinkPreferencesSurviveRelaunch",
            "testNotificationControlsAndAppearance",
            "testSettingsAccountDataAndFileDetails"))
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        selected = subprocess.check_output(command + ["--relaunch-probe", "--mode", "selectors"], text=True)
        self.assertEqual(selected.splitlines(), [
            "-only-testing:PickerTapChecks/ApplicationChecks/" + test for test in manifest.RELAUNCH_PROBE_TESTS])
        self.assertEqual(subprocess.check_output(command + ["--relaunch-probe", "--mode", "system-size"], text=True).strip(), "0")
        for incompatible in (["--shard", "B"], ["--system-size-only"]):
            result = subprocess.run(command + ["--relaunch-probe", "--mode", "selectors"] + incompatible,
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
        focused = "".join(result_line(test) for test in manifest.RELAUNCH_PROBE_TESTS)
        manifest.validate_results(focused, manifest.RELAUNCH_PROBE_TESTS, 27)
        with self.assertRaises(ValueError):
            manifest.validate_results(focused, manifest.selected_tests("B"), 27)

    def test_single_diagnostic_case_requires_exact_completion_and_cannot_select_full_shards(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py")]
        case = "testChangedDataProducesOneLocalNotification"
        selection = ["--relaunch-probe", "--probe-case", case]
        self.assertEqual(subprocess.check_output(command + selection + ["--mode", "selectors"],
                                                text=True).splitlines(),
                         ["-only-testing:PickerTapChecks/ApplicationChecks/" + case])
        for incompatible in (["--probe-case", case], selection + ["--shard", "A"],
                             ["--relaunch-probe", "--probe-case", "testUnknown"]):
            result = subprocess.run(command + incompatible + ["--mode", "selectors"],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, result.stdout)
        with tempfile.TemporaryDirectory(prefix="takupoke-one-diagnostic-") as directory:
            log = Path(directory) / "owned.log"
            for contents, expected in (
                (result_line(case), True), ("", False), (result_line(case, "failed"), False),
                (result_line(case, "skipped"), False), (result_line(case) * 2, False),
                (result_line("testLinkPreferencesSurviveRelaunch"), False),
                (result_line(case) + result_line("testLinkPreferencesSurviveRelaunch"), False),
            ):
                log.write_text(contents, encoding="utf-8")
                result = subprocess.run(command + selection + ["--mode", "verify", "--ios", "27",
                    "--runner-log", "--log", str(log)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, expected, result.stderr)

    def test_outer_runner_log_rejects_no_tests_and_missing_os_size_runs(self):
        command = [sys.executable, "-B", str(ROOT / "tools/ui_test_manifest.py"),
                   "--shard", "B", "--mode", "verify", "--runner-log"]
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "owned.log"
            for ios in (26, 27):
                base = "".join(result_line(test, "skipped" if ios == 26 and test == manifest.VOICEOVER_TEST else "passed")
                               for test in manifest.selected_tests("B"))
                complete = base + result_line(manifest.SYSTEM_SIZE_TEST) * 3
                for contents, success in (("", False), (base, False), (complete, True),
                                          (complete + result_line(manifest.SYSTEM_SIZE_TEST), False)):
                    path.write_text(contents, encoding="utf-8")
                    result = subprocess.run(command + ["--ios", str(ios), "--log", str(path)],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, success, result.stderr)


@unittest.skipUnless(os.name == "posix", "macOS CI Bash runner")
class ShellRunnerTests(unittest.TestCase):
    def run_synthetic_runner(self, ios, shard, *, omit_result=False):
        with tempfile.TemporaryDirectory(prefix="takupoke-shard-check-") as directory:
            repo = Path(directory)
            (repo / "tools").mkdir()
            (repo / "tests/ui").mkdir(parents=True)
            (repo / "bin").mkdir()
            (repo / "scratch").mkdir()
            for name in ("test-app-ui.sh", "resolve-xcode-packages.sh", "ui_test_manifest.py", "timed_command.py"):
                shutil.copyfile(ROOT / "tools" / name, repo / "tools" / name)
            for name in manifest.CHECK_SOURCES:
                shutil.copyfile(ROOT / "tests/ui" / name, repo / "tests/ui" / name)
            (repo / "tools/app_test_project.py").write_text(
                "import json, os\n"
                "with open(os.environ['CALLS'], 'a') as output:\n"
                "    output.write(json.dumps(['project', os.environ['TKPK_VOICEOVER_AUTOMATION']]) + '\\n')\n")
            fake = "#!" + sys.executable + "\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as output:
    output.write(json.dumps([Path(sys.argv[0]).name] + args) + '\\n')
if Path(sys.argv[0]).name == 'xcodebuild':
    tests = [arg.rsplit('/', 1)[1] for arg in args if arg.startswith('-only-testing:')]
    if os.environ.get('OMIT_RESULT'): tests = tests[1:]
    for test in tests:
        status = 'skipped' if os.environ['TKPK_TEST_IOS'] == '26' and test == 'testVoiceOverReadsTimetableCard' else 'passed'
        print(f"Test Case '-[PickerTapChecks.ApplicationChecks {test}]' {status} (1.234 seconds).",
              file=sys.stderr if os.environ['TKPK_TEST_IOS'] == '26' else sys.stdout)
elif args[:2] == ['simctl', 'list']:
    major = os.environ['TKPK_TEST_IOS']
    print(json.dumps({'runtimes': [{'isAvailable': True, 'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-' + major + '-5', 'version': major + '.5'}],
                      'devicetypes': [{'name': 'iPhone 16', 'identifier': 'synthetic-device'}]}))
elif args[:2] == ['simctl', 'create']: print('synthetic-simulator')
elif args[:2] == ['simctl', 'get_app_container']: print(os.environ['APP_CONTAINER'])
'''
            for tool in ("xcrun", "xcodebuild"):
                path = repo / "bin" / tool
                path.write_text(fake)
                path.chmod(0o755)
            calls_file = repo / "calls"
            environment = os.environ | {
                "PATH": str(repo / "bin") + os.pathsep + os.environ["PATH"],
                "TMPDIR": str(repo / "scratch"), "TKPK_TEST_IOS": str(ios),
                "TKPK_UI_SHARD": shard, "CALLS": str(calls_file),
                "APP_CONTAINER": str(repo / "container"),
            }
            if omit_result:
                environment["OMIT_RESULT"] = "1"
            result = subprocess.run(["bash", "tools/test-app-ui.sh"], cwd=repo, env=environment,
                                    capture_output=True, text=True, timeout=15)
            calls = [json.loads(line) for line in calls_file.read_text().splitlines()]
            self.assertEqual(list((repo / "scratch").iterdir()), [], "Owned scratch data must be removed")
            self.assertIn(["xcrun", "simctl", "shutdown", "synthetic-simulator"], calls)
            self.assertIn(["xcrun", "simctl", "delete", "synthetic-simulator"], calls)
            return result, calls

    def test_both_shards_on_both_os_preserve_selection_and_os_size_checks(self):
        for ios in (26, 27):
            for shard in manifest.SHARDS:
                with self.subTest(ios=ios, shard=shard):
                    result, calls = self.run_synthetic_runner(ios, shard)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn(["project", "1" if ios == 27 else "0"], calls)
                    resolutions = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" in call]
                    self.assertEqual(len(resolutions), 1)
                    builds = [call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" not in call]
                    self.assertEqual(len(builds), 4 if shard == "B" else 1)
                    tests = [arg.rsplit("/", 1)[1] for arg in builds[0] if arg.startswith("-only-testing:")]
                    self.assertEqual(tests, list(manifest.SHARDS[shard]))
                    self.assertEqual(builds[0][-1], "test")
                    sizes = [call[-1] for call in calls if call[:2] == ["xcrun", "simctl"]
                             and "content_size" in call]
                    self.assertEqual(sizes, ["large"] + (["extra-small", "extra-extra-extra-large",
                        "accessibility-extra-extra-extra-large"] if shard == "B" else []))
                    for build in builds[1:]:
                        self.assertEqual(build[-1], "test-without-building")
                        self.assertIn("-only-testing:PickerTapChecks/ApplicationChecks/" + manifest.SYSTEM_SIZE_TEST, build)

    def test_missing_xctest_completion_fails_shell_and_cleans_up(self):
        result, calls = self.run_synthetic_runner(27, "B", omit_result=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("XCTest completion differs", result.stderr)
        self.assertEqual(len([call for call in calls if call[0] == "xcodebuild" and "-resolvePackageDependencies" not in call]), 1)
