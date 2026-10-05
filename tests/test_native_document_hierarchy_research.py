"""Research-launcher contracts; no Apple request, SDK substitution or network."""
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import signal
import subprocess
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

    def test_only_sdk26_executes_four_matched_native_controls_without_full_app_or_retry(self):
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)
            native=research.commands(research.ROOT,path,"ios",26,"mac")
            other=research.commands(research.ROOT,path,"ios",27)
            self.assertEqual(len(native),3);self.assertEqual(len(other),1)
            self.assertEqual(native[-1][1],[str(path/"native-hierarchy-probe")])
            self.assertEqual(native[-1][2],180)
            self.assertIn("arm64-apple-macos26.0",native[1][1])
            self.assertIn(str(research.ROOT/"tests/research/NativeDocumentHierarchyDiagnostics.swift"),native[1][1])
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
        self.assertEqual(probe.count("request.perform(on: image)"),1)
        self.assertIn('for languageProfile in ["default", "ja-en-auto"]',probe)
        self.assertIn("for merged in [false, true]",probe)
        self.assertIn('counts["nativeTables", default: 0] > 0',probe)
        self.assertIn('counts["uniqueMergedSpans", default: 0] > 0',probe)
        self.assertIn('counts["missingRawMatches", default: 0] == 0',probe)
        self.assertIn('counts["ambiguousRawMatches", default: 0] == 0',probe)
        self.assertIn('counts["missingNativeRawMatches", default: 0] == 0',probe)
        self.assertIn('counts["ambiguousNativeRawMatches", default: 0] == 0',probe)
        self.assertIn("compatible && attempted == 4",probe)
        self.assertIn("if !compatible || !acquisitionCompatible || attempted != 4 { exit(1) }",probe)
        self.assertIn('"nativeFullAcquisitionControlsPassed": acquisitionCompatible && attempted == 4',probe)
        self.assertIn("acquisitionPassed = assessment.directLayoutsAllowed",probe)
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

    def test_inventory_only_inspects_selected_group_sessions(self):
        with patch.object(research.subprocess,"check_output",return_value="11 42\n12 99\n13 42\n"),patch.object(research.os,"getpgid",return_value=42),patch.object(research.os,"getsid",return_value=42) as sid:
            self.assertEqual(research.owned_group_members(42),[11,13])
        self.assertEqual([call.args[0] for call in sid.call_args_list],[11,13])

    def test_foreign_session_refuses_signal(self):
        process=unittest.mock.Mock(pid=42);process.poll.return_value=None
        with patch.object(research.subprocess,"check_output",return_value="11 42\n"),patch.object(research.os,"getpgid",return_value=42),patch.object(research.os,"getsid",return_value=99),patch.object(research.os,"killpg") as kill:
            result=research.stop_owned(process)
        self.assertFalse(result["complete"]);kill.assert_not_called()

    def test_uninspectable_selected_session_refuses_signal(self):
        process=unittest.mock.Mock(pid=42);process.poll.return_value=None
        with patch.object(research.subprocess,"check_output",return_value="11 42\n"),patch.object(research.os,"getpgid",return_value=42),patch.object(research.os,"getsid",side_effect=PermissionError("fictional denied")),patch.object(research.os,"killpg") as kill:
            result=research.stop_owned(process)
        self.assertFalse(result["complete"]);kill.assert_not_called()

    def test_changed_selected_group_refuses_signal(self):
        process=unittest.mock.Mock(pid=42);process.poll.return_value=None
        with patch.object(research.subprocess,"check_output",return_value="11 42\n"),patch.object(research.os,"getpgid",return_value=99),patch.object(research.os,"getsid") as sid,patch.object(research.os,"killpg") as kill:
            result=research.stop_owned(process)
        self.assertFalse(result["complete"]);kill.assert_not_called();sid.assert_not_called()

    def test_group_inventory_malformed_or_oversized_refuses(self):
        for text in ["not a pid\n","1 2\n"*100000]:
            with patch.object(research.subprocess,"check_output",return_value=text):
                with self.assertRaises(RuntimeError):research.owned_group_members(42)

    def test_kill_after_term_reverifies_then_requires_empty_group(self):
        process=unittest.mock.Mock(pid=42);process.poll.return_value=0
        with patch.object(research,"GROUP_CLEANUP_SECONDS",0),patch.object(research,"owned_group_members",side_effect=[[11],[11],[11],[]]) as inventory,patch.object(research.os,"killpg") as kill:
            result=research.stop_owned(process)
        self.assertTrue(result["complete"]);self.assertEqual(inventory.call_count,4)
        self.assertEqual([call.args for call in kill.call_args_list],[(42,signal.SIGTERM),(42,signal.SIGKILL)])

    def test_remaining_descendants_after_kill_cannot_be_success(self):
        process=unittest.mock.Mock(pid=42);process.poll.return_value=0
        with patch.object(research,"GROUP_CLEANUP_SECONDS",0),patch.object(research,"owned_group_members",return_value=[11]),patch.object(research.os,"killpg"):
            result=research.stop_owned(process)
        self.assertFalse(result["complete"]);self.assertEqual(result["remainingOwnedGroupPids"],[11])

    def test_interrupt_during_cleanup_becomes_unknown_group_hold(self):
        process=unittest.mock.Mock(pid=42);process.poll.return_value=None
        with patch.object(research,"owned_group_members",side_effect=SystemExit(143)):
            result=research.stop_owned(process)
        self.assertFalse(result["complete"]);self.assertIn("SystemExit",result["errors"][0])

    def test_post_spawn_selector_failure_still_proves_group_empty(self):
        spawned=[];original=research.subprocess.Popen
        def spawn(command,*args,**kwargs):
            process=original(command,*args,**kwargs)
            if command[0]==sys.executable:spawned.append(process)
            return process
        with tempfile.TemporaryDirectory() as d,patch.object(research,"RESERVE",0),patch.object(research.subprocess,"Popen",side_effect=spawn),patch.object(research.selectors,"DefaultSelector",side_effect=OSError("fictional selector failure")):
            with self.assertRaisesRegex(OSError,"fictional selector failure"):
                research.phase("selector fault",[sys.executable,"-c","import time;time.sleep(30)"],seconds=3,scratch=Path(d))
        self.assertEqual(len(spawned),1);self.assertIsNotNone(spawned[0].returncode)
        self.assertEqual(research.owned_group_members(spawned[0].pid),[])

    def retained_main(self, failure):
        created=[];spawned=[];real_lookup=research.subprocess.check_output;real_spawn=research.subprocess.Popen
        real_directory=research.tempfile.mkdtemp;real_kill=os.killpg
        def directory(*args,**kwargs):
            d=real_directory(*args,**kwargs);created.append(Path(d));return d
        def lookup(command,**kwargs):
            if command[0]=="git":return "a"*40
            if command[0]=="xcrun":return "27.0" if command[-1]=="--show-sdk-version" else "/actual/sdk"
            return real_lookup(command,**kwargs)
        def spawn(command,*args,**kwargs):
            process=real_spawn(command,*args,**kwargs)
            if command[0]==sys.executable:spawned.append(process)
            return process
        patches=[patch.dict(os.environ,self.environment()),patch.object(sys,"argv",["probe","--sdk-major","27"]),patch.object(sys,"platform","darwin"),patch.object(research.subprocess,"check_output",side_effect=lookup),patch.object(research.subprocess,"Popen",side_effect=spawn),patch.object(research.tempfile,"mkdtemp",side_effect=directory),patch.object(research,"RESERVE",0),patch.object(research,"commands",return_value=[("fictional cleanup failure",[sys.executable,"-c","import time;time.sleep(30)"],.1)])]
        from contextlib import ExitStack
        try:
            with ExitStack() as stack:
                for p in patches:stack.enter_context(p)
                if failure in ("kill","stdout","cancel"):stack.enter_context(patch.object(research.os,"killpg",side_effect=PermissionError("fictional kill denied")))
                else:stack.enter_context(patch.object(research,"owned_group_members",side_effect=RuntimeError("fictional inventory unavailable")))
                if failure in ("stdout","cancel"):
                    def output(value,*args,**kwargs):
                        if str(value).startswith("RESEARCH owned group cleanup:"):
                            if failure=="stdout":raise BrokenPipeError("fictional cleanup stdout unavailable")
                            signal.getsignal(signal.SIGTERM)(signal.SIGTERM,None)
                    stack.enter_context(patch("builtins.print",side_effect=output))
                with redirect_stdout(io.StringIO()):
                    with self.assertRaises(Exception):research.main()
            self.assertEqual(len(created),1)
            self.assertTrue(created[0].exists(),"Unproved cleanup must retain owned scratch")
            logs=list(created[0].glob("phase-*.log"));self.assertEqual(len(logs),1)
            receipt=json.loads((created[0]/"owned-cleanup-failure.json").read_text())
            self.assertTrue(receipt["scratchRetained"]);self.assertFalse(receipt["cleanup"]["complete"])
            self.assertEqual(receipt["sourceSHA"],"a"*40);self.assertEqual(receipt["runAttempt"],1)
            if failure in ("stdout","cancel"):
                self.assertIn("BrokenPipeError" if failure=="stdout" else "SystemExit",receipt["cleanup"]["diagnosticFailure"])
        finally:
            for process in spawned:
                try:real_kill(process.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                process.wait(timeout=5)
            for d in created:research.shutil.rmtree(d,ignore_errors=True)

    def test_actual_kill_failure_retains_scratch_log_and_error_receipt(self):
        self.retained_main("kill")

    def test_actual_inventory_failure_retains_scratch_log_and_error_receipt(self):
        self.retained_main("inventory")

    def test_cleanup_stdout_broken_pipe_cannot_downgrade_retention(self):
        self.retained_main("stdout")

    def test_cleanup_stdout_sigterm_cannot_downgrade_retention(self):
        self.retained_main("cancel")

    def test_actual_owned_descendant_group_is_proved_empty_before_success(self):
        code="import subprocess,signal,sys,time\nchild=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])\ndef stop(*_):\n child.terminate();child.wait(timeout=3);sys.exit(0)\nsignal.signal(signal.SIGTERM,stop)\nprint('ready',flush=True)\ntime.sleep(30)"
        process=subprocess.Popen([sys.executable,"-c",code],stdout=subprocess.PIPE,start_new_session=True)
        try:
            import select
            self.assertTrue(select.select([process.stdout],[],[],3)[0]);self.assertEqual(process.stdout.readline(),b"ready\n")
            self.assertEqual(len(research.owned_group_members(process.pid)),2)
            result=research.stop_owned(process)
            self.assertTrue(result["complete"],result);self.assertEqual(research.owned_group_members(process.pid),[])
        finally:
            if process.poll() is None:
                os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5)
            process.stdout.close()

    def test_actual_term_ignoring_leader_requires_kill_and_empty_readback(self):
        process=subprocess.Popen([sys.executable,"-c","import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);print('ready',flush=True);time.sleep(30)"],stdout=subprocess.PIPE,start_new_session=True)
        try:
            import select
            self.assertTrue(select.select([process.stdout],[],[],3)[0]);self.assertEqual(process.stdout.readline(),b"ready\n")
            with patch.object(research,"GROUP_CLEANUP_SECONDS",.15):result=research.stop_owned(process)
            self.assertTrue(result["complete"],result);self.assertEqual(process.returncode,-signal.SIGKILL)
            self.assertEqual(research.owned_group_members(process.pid),[])
        finally:
            if process.poll() is None:
                os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=5)
            process.stdout.close()


if __name__ == "__main__":unittest.main()
