"""Research-launcher contracts; no Apple request, SDK substitution or network."""
from contextlib import redirect_stdout
import io
import os
from pathlib import Path
import signal
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import native_document_hierarchy_research as research


class ResearchLauncherTests(unittest.TestCase):
    def environment(self):
        return {"GITHUB_REPOSITORY": research.REPO, "GITHUB_EVENT_NAME": "push",
                "GITHUB_REF": "refs/heads/" + research.BRANCH, "GITHUB_SHA": "a" * 40,
                "GITHUB_RUN_ID": "123", "GITHUB_RUN_ATTEMPT": "1"}

    def test_exact_push_first_attempt_and_commit_are_required(self):
        env = self.environment(); research.identity(env, "a" * 40)
        for key, value in [("GITHUB_REPOSITORY", "foreign/repository"), ("GITHUB_EVENT_NAME", "workflow_dispatch"),
                           ("GITHUB_EVENT_NAME", "pull_request"), ("GITHUB_REF", "refs/heads/main"),
                           ("GITHUB_SHA", "a" * 39), ("GITHUB_RUN_ID", "0"), ("GITHUB_RUN_ATTEMPT", "2")]:
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                research.identity(env | {key: value}, "a" * 40)
        with self.assertRaises(ValueError):research.identity(env, "b" * 40)

    def test_both_phone_sdks_typecheck_actual_adapter_with_ios26_availability(self):
        with tempfile.TemporaryDirectory() as d:
            for major in (26, 27):
                plan = research.commands(research.ROOT, Path(d), "/fictional/actual-iPhone-SDK", major,
                                         "/fictional/actual-macOS-SDK")
                command = plan[0][1]
                self.assertIn(str(research.ROOT / "Takupoke/PDFRecoveryRecognition.swift"), command)
                self.assertIn(str(research.ROOT / "Takupoke/RecoveryVisionCapture.swift"), command)
                self.assertIn("-typecheck", command);self.assertIn("arm64-apple-ios26.0", command)
                self.assertIn("/fictional/actual-iPhone-SDK", command)
                self.assertIn(str(research.ROOT / "tests/research/NativeDocumentHierarchyDomainStubs.swift"), command)

    def test_only_sdk26_executes_the_two_native_controls_without_full_app_or_retry(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)
            native=research.commands(research.ROOT,path,"ios",26,"mac")
            other=research.commands(research.ROOT,path,"ios",27)
            self.assertEqual(len(native),3);self.assertEqual(len(other),1)
            self.assertEqual(native[-1][1],[str(path/"native-hierarchy-probe")])
            self.assertEqual(native[-1][2],180)
            self.assertIn("arm64-apple-macos26.0",native[1][1])
            self.assertNotIn(str(research.ROOT/"tests/research/NativeDocumentHierarchyDomainStubs.swift"),native[1][1])
            for _, command, _ in native+other:
                self.assertFalse(any(token in command for token in ["swift", "test", "xcodebuild", "simctl", "--publish"]))

    def test_missing_mac_sdk_or_unknown_architecture_refuses(self):
        for mac, arch in [(None,"arm64"),("mac","unknown")]:
            with self.assertRaises(ValueError):research.commands(research.ROOT,Path("/tmp"),"ios",26,mac,arch)

    def test_domain_stubs_do_not_replace_apple_framework_types(self):
        source=(research.ROOT/"tests/research/NativeDocumentHierarchyDomainStubs.swift").read_text()
        for declaration in ["struct DocumentObservation", "struct RecognizedTextObservation", "struct NormalizedRegion",
                            "struct RecognizeDocumentsRequest", "struct CGImage", "struct PDFDocument", "struct UIImage"]:
            self.assertNotIn(declaration,source)
        helper=(research.ROOT/"Takupoke/RecoveryVisionCapture.swift").read_text()
        self.assertIn("import Vision",helper);self.assertIn("macOS 26.0",helper)
        adapter=(research.ROOT/"Takupoke/PDFRecoveryRecognition.swift").read_text()
        self.assertIn("RecoveryVisionCapture.page",adapter)
        self.assertNotIn("func captureLine(",adapter)

    def test_native_control_requires_observed_table_merged_span_and_actual_raw_mapping(self):
        probe=(research.ROOT/"tests/research/NativeDocumentHierarchyProbe.swift").read_text()
        self.assertEqual(probe.count("RecognizeDocumentsRequest().perform(on: image)"),1)
        self.assertIn("for merged in [false, true]",probe)
        self.assertIn('counts["nativeTables", default: 0] > 0',probe)
        self.assertIn('counts["uniqueMergedSpans", default: 0] > 0',probe)
        self.assertIn('counts["missingRawMatches", default: 0] == 0',probe)
        self.assertIn('counts["ambiguousRawMatches", default: 0] == 0',probe)
        self.assertIn('counts["missingNativeRawMatches", default: 0] == 0',probe)
        self.assertIn('counts["ambiguousNativeRawMatches", default: 0] == 0',probe)
        self.assertIn("compatible && attempted == 2",probe)
        self.assertIn("if !compatible || attempted != 2 { exit(1) }",probe)
        self.assertIn('"fullAcquisitionDisposition"',probe)
        self.assertIn('"wholeDocumentAdoption": "NOT_ATTEMPTED"',probe)
        self.assertNotIn("PDFDocument(",probe)

    def test_workflow_trigger_has_no_main_dispatch_publication_artifact_or_cache(self):
        workflow=(research.ROOT/".github/workflows/native-document-hierarchy-research.yml").read_text()
        self.assertIn("branches: ["+research.BRANCH+"]",workflow)
        self.assertNotIn("workflow_dispatch",workflow);self.assertNotIn("pull_request:",workflow)
        self.assertIn("github.event_name == 'push'",workflow)
        self.assertIn("github.ref == 'refs/heads/"+research.BRANCH+"'",workflow)
        self.assertIn("ref: ${{ github.sha }}",workflow)
        self.assertIn("contents: read",workflow);self.assertNotIn("contents: write",workflow)
        for token in ("upload-artifact", "actions/cache", "--publish", "development_release.py", "release_gate.py"):
            self.assertNotIn(token,workflow)

    def test_actual_local_small_process_preserves_output_and_success(self):
        with tempfile.TemporaryDirectory() as d, patch.object(research,"RESERVE",0):
            research.phase("fictional success",[sys.executable,"-c","print('fictional control')"],seconds=3,scratch=Path(d))

    def test_real_nonzero_child_cannot_be_credited_as_success(self):
        with tempfile.TemporaryDirectory() as d, patch.object(research,"RESERVE",0):
            with self.assertRaisesRegex(RuntimeError,"failed"):
                research.phase("fictional failure",[sys.executable,"-c","raise SystemExit(3)"],seconds=3,scratch=Path(d))

    def test_wall_watchdog_still_applies_after_child_closes_stdout(self):
        with tempfile.TemporaryDirectory() as d, patch.object(research,"RESERVE",0):
            with self.assertRaises(TimeoutError):
                research.phase("closed pipe",[sys.executable,"-c","import os,time;os.close(1);os.close(2);time.sleep(30)"],seconds=.1,scratch=Path(d))

    def test_output_limit_terminates_only_owned_child(self):
        with tempfile.TemporaryDirectory() as d, patch.object(research,"RESERVE",0), patch.object(research,"MAX_OUTPUT",16):
            with self.assertRaisesRegex(RuntimeError,"output limit"):
                research.phase("bounded output",[sys.executable,"-c","print('x'*100)"],seconds=3,scratch=Path(d))

    def test_disk_precondition_fails_before_child_creation(self):
        with tempfile.TemporaryDirectory() as d, patch.object(research,"RESERVE",sys.maxsize), patch.object(research.subprocess,"Popen") as spawn:
            with self.assertRaisesRegex(RuntimeError,"disk reserve"):
                research.phase("no space",[sys.executable,"-c","pass"],seconds=3,scratch=Path(d))
            spawn.assert_not_called()

    def test_owned_rss_limit_cancels_phase(self):
        with tempfile.TemporaryDirectory() as d, patch.object(research,"RESERVE",0), patch.object(research,"owned_rss",return_value=research.MAX_OWNED_RSS+1):
            with self.assertRaisesRegex(RuntimeError,"RSS"):
                research.phase("bounded RSS",[sys.executable,"-c","import time;time.sleep(30)"],seconds=3,scratch=Path(d))

    def test_owned_rss_counts_only_recorded_group(self):
        with patch.object(research.subprocess,"check_output",return_value="123 10\n999 1000\n123 20\n"):
            self.assertEqual(research.owned_rss(123),30*1024)

    def test_launcher_failure_removes_owned_scratch_without_touching_foreign_file(self):
        env=self.environment(); created=[]
        def lookup(command, **_):
            return "a"*40 if command[0]=="git" else ("27.0" if command[-1]=="--show-sdk-version" else "/actual/sdk")
        def fail(_label,_command,*,seconds,scratch):
            created.append(scratch);(scratch/"owned").write_text("fictional")
            raise RuntimeError("fictional phase error")
        with tempfile.TemporaryDirectory() as d:
            foreign=Path(d)/"foreign";foreign.write_text("keep")
            with patch.dict(os.environ,env),patch.object(sys,"argv",["probe","--sdk-major","27"]),patch.object(sys,"platform","darwin"),patch.object(research.subprocess,"check_output",side_effect=lookup),patch.object(research,"phase",side_effect=fail),redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError,"fictional phase error"):research.main()
            self.assertEqual(len(created),1);self.assertFalse(created[0].exists())
            self.assertEqual(foreign.read_text(),"keep")

    def test_nonapple_host_stops_before_sdk_query_or_native_probe(self):
        with patch.dict(os.environ,self.environment()),patch.object(sys,"argv",["probe","--sdk-major","26"]),patch.object(sys,"platform","linux"),patch.object(research.subprocess,"check_output",return_value="a"*40) as lookup:
            with self.assertRaisesRegex(ValueError,"Actual Apple SDK"):research.main()
            self.assertEqual(lookup.call_count,1)

    def test_closed_stdout_timeout_reaps_actual_owned_process_group(self):
        spawned=[]; original=research.subprocess.Popen
        def spawn(command, *args, **kwargs):
            process=original(command,*args,**kwargs)
            if command[0]==sys.executable:spawned.append(process)
            return process
        with tempfile.TemporaryDirectory() as d,patch.object(research,"RESERVE",0),patch.object(research.subprocess,"Popen",side_effect=spawn):
            with self.assertRaises(TimeoutError):
                research.phase("owned cleanup",[sys.executable,"-c","import os,time;os.close(1);os.close(2);time.sleep(30)"],seconds=.1,scratch=Path(d))
        self.assertEqual(len(spawned),1);self.assertIsNotNone(spawned[0].returncode)
        with self.assertRaises(ProcessLookupError):os.killpg(spawned[0].pid,0)

    def test_sdk26_label_cannot_use_an_available_sdk27(self):
        def lookup(command, **_):return "a"*40 if command[0]=="git" else "27.0"
        with patch.dict(os.environ,self.environment()),patch.object(sys,"argv",["probe","--sdk-major","26"]),patch.object(sys,"platform","darwin"),patch.object(research.subprocess,"check_output",side_effect=lookup),patch.object(research,"phase") as phase:
            with self.assertRaisesRegex(ValueError,"Requested iPhone SDK unavailable"):research.main()
            phase.assert_not_called()

    def test_sigterm_handler_unwinds_owned_scratch_and_restores_handlers(self):
        created=[]; previous=signal.getsignal(signal.SIGTERM)
        def lookup(command, **_):
            return "a"*40 if command[0]=="git" else ("27.0" if command[-1]=="--show-sdk-version" else "/actual/sdk")
        def cancel(_label,_command,*,seconds,scratch):
            created.append(scratch);(scratch/"owned").write_text("fictional")
            signal.getsignal(signal.SIGTERM)(signal.SIGTERM,None)
        with patch.dict(os.environ,self.environment()),patch.object(sys,"argv",["probe","--sdk-major","27"]),patch.object(sys,"platform","darwin"),patch.object(research.subprocess,"check_output",side_effect=lookup),patch.object(research,"phase",side_effect=cancel),redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as stopped:research.main()
        self.assertEqual(stopped.exception.code,143)
        self.assertEqual(len(created),1);self.assertFalse(created[0].exists())
        self.assertEqual(signal.getsignal(signal.SIGTERM),previous)


if __name__ == "__main__":unittest.main()
