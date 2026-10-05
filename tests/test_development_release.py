"""Fictional package/API responses only; no network writes or real IPA."""
import copy
from contextlib import redirect_stdout, ExitStack
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import os

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import publish as publisher
import development_release as dev
import release_gate
import ui_test_manifest as manifest
from test_distribution import IPAFixture, COMMIT


class DevelopmentReleaseTests(IPAFixture):
    def context(self):
        run = dict(id=123, run_attempt=2, head_sha=COMMIT, head_branch=dev.BRANCH,
                   repository={"full_name":dev.REPO}, event="workflow_dispatch",
                   status="completed", conclusion="success", workflow_id=456)
        jobs = [dict(name=name, run_id=123, run_attempt=2, head_sha=COMMIT,
                     status="completed", conclusion="success") for name in sorted(dev.REQUIRED)]
        return run, jobs, {"id":456,"path":".github/workflows/ios-release.yml"}

    def test_exact_successful_run_including_device_build_is_required(self):
        run,jobs,workflow = self.context()
        self.assertEqual(dev.check_snapshot(run,jobs,workflow,COMMIT,123),2)
        for index in range(len(jobs)):
            with self.subTest(job=jobs[index]["name"]), self.assertRaises(ValueError):
                dev.check_snapshot(run,jobs[:index]+jobs[index+1:],workflow,COMMIT,123)

    def test_all_thirteen_checks_include_six_manual_cases_without_historical_pass_credit(self):
        run,jobs,workflow = self.context()
        self.assertEqual(len(dev.REQUIRED),13)
        self.assertEqual(dev.REQUIRED,release_gate.REQUIRED|{"Check iPhone build without publishing"})
        ordinary = [job for job in jobs if job["name"] not in manifest.MANUAL_REQUIRED_JOBS]
        self.assertEqual(len(ordinary),7)
        with self.assertRaises(ValueError):
            dev.check_snapshot(run,ordinary,workflow,COMMIT,123)
        for name in manifest.MANUAL_REQUIRED_JOBS:
            for key,value in (("run_attempt",1),("head_sha","b"*40),("run_id",999),
                              ("status","in_progress"),("conclusion","skipped"),("conclusion","failure")):
                changed=copy.deepcopy(jobs)
                next(job for job in changed if job["name"]==name)[key]=value
                with self.subTest(name=name,key=key),self.assertRaises(ValueError):
                    dev.check_snapshot(run,changed,workflow,COMMIT,123)

    def test_wrong_identity_attempt_or_skipped_failure_never_qualifies(self):
        run,jobs,workflow = self.context()
        for key,value in [("head_sha","b"*40),("head_branch","main"),("event","pull_request"),
                          ("status","in_progress"),("conclusion","failure"),("run_attempt",1)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                dev.check_snapshot(run|{key:value},jobs,workflow,COMMIT,123)
        for status in ("failure","cancelled","skipped",None):
            changed=copy.deepcopy(jobs);changed[0]["conclusion"]=status
            with self.assertRaises(ValueError):dev.check_snapshot(run,changed,workflow,COMMIT,123)
        with self.assertRaises(ValueError):dev.check_snapshot(run,jobs+[jobs[0]],workflow,COMMIT,123)
        with self.assertRaises(ValueError):dev.check_snapshot(run,jobs,workflow|{"path":"other.yml"},COMMIT,123)

    def build(self):
        self.write_ipa()
        metadata={"repository":dev.REPO,"commit":COMMIT,"version":"0.1.12","build":"12.1",
                  "sha256":{"takupoke.ipa":dev.sha256(self.output/"takupoke.ipa")}}
        (self.output/"release.json").write_text(json.dumps(metadata),encoding="utf-8")
        return metadata

    def fake(self):
        run,jobs,workflow=self.context()
        return FakeGitHub(run,jobs,workflow)

    def stage(self,fake):
        fake.run.update(status="in_progress",conclusion=None)
        env={"GITHUB_REPOSITORY":dev.REPO,"GITHUB_REF":"refs/heads/"+dev.BRANCH,
             "GITHUB_EVENT_NAME":"workflow_dispatch","GITHUB_RUN_ID":"123",
             "GITHUB_RUN_ATTEMPT":"2","GITHUB_SHA":COMMIT}
        output=Path(self.scratch.name)/"github-output"
        before=output.read_text() if output.exists() else ""
        with patch.dict(os.environ,env),redirect_stdout(io.StringIO()):
            dev.stage(self.output,output)
        self.assertEqual(output.read_text(),before+"draft_id=789\n")
        return fake.drafts[789]

    def test_original_unsigned_device_metadata_and_bytes_are_inspected(self):
        expected=self.build()
        self.assertEqual(dev.inspect_build(self.output,COMMIT),expected)
        self.info["TakupokeCommit"]="b"*40;self.write_ipa()
        expected["sha256"]["takupoke.ipa"]=dev.sha256(self.output/"takupoke.ipa")
        (self.output/"release.json").write_text(json.dumps(expected),encoding="utf-8")
        with self.assertRaisesRegex(ValueError,"TakupokeCommit"):
            dev.inspect_build(self.output,COMMIT)

    def test_staging_is_private_exact_source_and_never_finalizes(self):
        self.build()
        with self.fake() as f:
            draft=self.stage(f)
            self.assertTrue(draft["draft"]);self.assertTrue(draft["prerelease"])
            self.assertEqual(draft["body"],dev.stage_identity(123,2,COMMIT))
            self.assertEqual({a["name"] for a in draft["assets"]},set(dev.STAGED_ASSETS))
            self.assertEqual(len(f.downloads),2)
            request=f.creations[0]
            self.assertEqual(request["make_latest"],"false")
            self.assertEqual(request["target_commitish"],COMMIT)
            self.assertEqual(f.finalizations,[])

    def test_wrong_stage_context_and_collision_do_not_mutate_preexisting_release(self):
        self.build()
        with self.fake() as f:
            with patch.dict(os.environ,{"GITHUB_REPOSITORY":dev.REPO,"GITHUB_REF":"refs/heads/main","GITHUB_EVENT_NAME":"workflow_dispatch"}):
                with self.assertRaises(ValueError):dev.stage(self.output,Path(self.scratch.name)/"out")
            self.assertEqual(f.creations,[])
            self.stage(f);before=copy.deepcopy(f.drafts)
            with self.assertRaisesRegex(ValueError,"collision"):self.stage(f)
            self.assertEqual(f.drafts,before)

    def test_stage_failed_upload_cleans_only_recorded_owned_draft(self):
        self.build()
        with self.fake() as f:
            f.drafts[777]={"id":777,"tag_name":"unrelated","target_commitish":"b"*40,"draft":True}
            f.fail_upload=True
            with self.assertRaisesRegex(RuntimeError,"fictional upload"):
                self.stage(f)
            self.assertIn(777,f.drafts);self.assertNotIn(789,f.drafts)
            self.assertEqual(f.deleted_releases,[789])
            self.assertEqual((Path(self.scratch.name)/"github-output").read_text(),"draft_id=789\n")

    def test_each_other_job_failure_keeps_draft_private_and_blocks_prepare(self):
        self.build()
        with self.fake() as f:
            self.stage(f);f.run.update(status="completed",conclusion="success")
            for index,job in enumerate(f.jobs):
                with self.subTest(name=job["name"]):
                    job["conclusion"]="failure";before=len(f.downloads)
                    with self.assertRaises(ValueError):
                        dev.prepare(123,COMMIT,Path(self.scratch.name)/"prepared")
                    self.assertTrue(f.drafts[789]["draft"])
                    self.assertEqual(len(f.downloads),before);self.assertEqual(f.finalizations,[])
                    job["conclusion"]="success"

    def test_cleanup_refuses_foreign_body_source_attempt_or_published_release(self):
        self.build()
        with self.fake() as f:
            self.stage(f);original=copy.deepcopy(f.drafts[789])
            for key,value in (("body",dev.stage_identity(123,1,COMMIT)),("body","foreign"),
                              ("target_commitish","b"*40),("draft",False),("prerelease",False)):
                f.drafts[789]=copy.deepcopy(original);f.drafts[789][key]=value
                with self.subTest(key=key),self.assertRaises(ValueError):dev.cleanup_stage(789,123,2,COMMIT)
                self.assertEqual(f.deleted_releases,[])
            f.drafts[789]=original;dev.cleanup_stage(789,123,2,COMMIT)
            self.assertEqual(f.deleted_releases,[789])

    def test_tampered_asset_or_foreign_inventory_never_prepares(self):
        self.build()
        with self.fake() as f:
            self.stage(f);f.run.update(status="completed",conclusion="success")
            original=copy.deepcopy(f.drafts[789]);target=Path(self.scratch.name)/"prepared"
            f.corrupt_download=True
            with self.assertRaises(ValueError):dev.prepare(123,COMMIT,target)
            self.assertFalse(target.exists());self.assertTrue(f.drafts[789]["draft"])
            f.corrupt_download=False
            f.drafts[789]["assets"][0]["name"]="altstore-source.json"
            with self.assertRaises(ValueError):dev.prepare(123,COMMIT,target)
            self.assertFalse(target.exists());f.drafts[789]=original

    def test_prepare_rerun_during_download_preserves_caller_directory(self):
        self.build()
        with self.fake() as f:
            self.stage(f);f.run.update(status="completed",conclusion="success")
            target=Path(self.scratch.name)/"lastgood";target.mkdir();(target/"value").write_text("old")
            f.change_attempt_after_download=True
            with self.assertRaises(ValueError):dev.prepare(123,COMMIT,target)
            self.assertEqual((target/"value").read_text(),"old")
            self.assertEqual(f.finalizations,[])

    def test_completed_thirteen_prepare_and_finalize_same_owned_three_assets_with_public_readback(self):
        expected=self.build()
        with self.fake() as f,redirect_stdout(io.StringIO()):
            self.stage(f);f.run.update(status="completed",conclusion="success")
            target=Path(self.scratch.name)/"prepared"
            metadata,attempt=dev.prepare(123,COMMIT,target)
            self.assertEqual(metadata,expected);self.assertEqual(attempt,2)
            dev.publish(target,metadata,123,attempt,COMMIT)
            release=f.drafts[789]
            self.assertFalse(release["draft"]);self.assertTrue(release["prerelease"])
            self.assertEqual({a["name"] for a in release["assets"]},set(dev.ASSETS))
            self.assertEqual(len(f.creations),1)
            self.assertEqual(len(f.finalizations),1)
            self.assertIn("make_latest=false",f.finalizations[0])
            self.assertFalse(any("altstore" in name for name in f.uploaded))
            self.assertEqual(f.uploaded,["takupoke.ipa","release.json","INSTALL.txt","SHA256SUMS"])
            self.assertEqual(len(f.downloads),12) # 2 stage +2 prepare +2 verify +3 private +3 public
            self.assertEqual(f.deleted_releases,[])

    def test_final_upload_failure_or_gate_change_deletes_only_owned_private_draft(self):
        for mode in ("upload","gate"):
            with self.subTest(mode=mode):
                self.build()
                with self.fake() as f,redirect_stdout(io.StringIO()):
                    self.stage(f);f.run.update(status="completed",conclusion="success")
                    target=Path(self.scratch.name)/("prepared-"+mode)
                    metadata,attempt=dev.prepare(123,COMMIT,target)
                    f.drafts[777]={"id":777,"draft":True,"tag_name":"unrelated"}
                    if mode=="upload":f.fail_upload=True
                    else:f.change_attempt_on_final_upload=True
                    with self.assertRaises((RuntimeError,ValueError)):dev.publish(target,metadata,123,attempt,COMMIT)
                    self.assertNotIn(789,f.drafts);self.assertIn(777,f.drafts)
                    self.assertEqual(f.deleted_releases,[789]);self.assertEqual(f.finalizations,[])

    def test_workflow_has_no_artifacts_and_write_scope_is_feature_dispatch_only(self):
        source=(Path(__file__).resolve().parents[1]/".github/workflows/ios-release.yml").read_text()
        self.assertNotIn("actions/upload-artifact",source)
        helper=(Path(__file__).resolve().parents[1]/"tools/development_release.py").read_text()
        self.assertNotIn("/artifacts",helper)
        devjob=source.split("  development-build:\n",1)[1].split("  release:\n",1)[0]
        guard="github.repository == 'n624-dev/takupoke-ios' && github.ref == 'refs/heads/codex/pdf-local-recovery' && github.event_name == 'workflow_dispatch'"
        self.assertIn("if: "+guard,devjob)
        readjob=source.split("  build-check:\n",1)[1].split("  development-build:\n",1)[0]
        self.assertIn("!("+guard+")",readjob)
        self.assertNotIn("contents: write",readjob)
        self.assertIn("name: Check iPhone build outside development distribution",readjob)
        self.assertIn("name: Check iPhone build without publishing",devjob)
        self.assertIn("contents: write",devjob)
        self.assertIn("--stage",devjob);self.assertIn("--cleanup-draft",devjob)
        self.assertNotIn("--publish",devjob)

    def test_conditionally_skipped_nonfeature_build_has_distinct_name_not_duplicate_credit(self):
        run,jobs,workflow=self.context()
        jobs.append(dict(name="Check iPhone build outside development distribution",run_id=123,
                         run_attempt=2,head_sha=COMMIT,status="completed",conclusion="skipped"))
        self.assertEqual(dev.check_snapshot(run,jobs,workflow,COMMIT,123),2)
        jobs[-1]["name"]="Check iPhone build without publishing"
        with self.assertRaises(ValueError):dev.check_snapshot(run,jobs,workflow,COMMIT,123)


class FakeGitHub:
    """In-memory GitHub only; production identity/IPA/gate checks still execute."""
    def __init__(self,run,jobs,workflow):
        self.run=copy.deepcopy(run);self.jobs=copy.deepcopy(jobs);self.workflow=workflow
        self.drafts={};self.payloads={};self.next_asset=1
        self.creations=[];self.uploaded=[];self.downloads=[];self.finalizations=[];self.deleted_releases=[]
        self.fail_upload=False;self.corrupt_download=False
        self.change_attempt_after_download=False;self.change_attempt_on_final_upload=False
    def __enter__(self):
        self.stack=ExitStack()
        self.stack.enter_context(patch.object(dev,"api",side_effect=self.api))
        self.stack.enter_context(patch.object(publisher,"api",side_effect=self.api))
        self.stack.enter_context(patch.object(dev,"gh",side_effect=self.gh))
        self.stack.enter_context(patch.object(dev,"list_releases",side_effect=lambda repo:copy.deepcopy(list(self.drafts.values()))))
        return self
    def __exit__(self,*args):return self.stack.__exit__(*args)
    def api(self,path,*args):
        if path.endswith("/actions/runs/123"):return copy.deepcopy(self.run)
        if path.endswith("/actions/workflows/456"):return self.workflow
        if "/matching-refs/" in path:return []
        if path.startswith("https://uploads."):
            if self.fail_upload:raise RuntimeError("fictional upload failure")
            name=path.split("name=")[1];data=Path(args[args.index("--input")+1]).read_bytes()
            asset={"id":self.next_asset,"name":name,"size":len(data),"state":"uploaded"}
            self.payloads[self.next_asset]=data;self.next_asset+=1
            self.drafts[789]["assets"].append(asset);self.uploaded.append(name)
            if self.change_attempt_on_final_upload:self.run["run_attempt"]=3
            return asset
        if path.endswith("/releases") and "POST" in args:
            request=json.loads(Path(args[args.index("--input")+1]).read_text())
            self.creations.append(request);self.drafts[789]=request|{"id":789,"assets":[]}
            return {"id":789}
        if "/releases/assets/" in path and "DELETE" in args:
            identity=int(path.rsplit("/",1)[1]);self.drafts[789]["assets"]=[a for a in self.drafts[789]["assets"] if a["id"]!=identity]
            return None
        if path.endswith("/releases/789"):
            if "PATCH" in args:
                self.finalizations.append(args);self.drafts[789]["draft"]=False
                self.drafts[789]["body"]=next(x[5:] for x in args if x.startswith("body="))
            return copy.deepcopy(self.drafts[789])
        raise AssertionError((path,args))
    def gh(self,*args,output=None):
        if "DELETE" in args:
            identity=int(args[-1].rsplit("/",1)[1]);self.deleted_releases.append(identity);del self.drafts[identity];return None
        if args[-1].endswith("/jobs?per_page=100"):
            return json.dumps([{"jobs":self.jobs}])
        identity=int(args[-1].rsplit("/",1)[1]);self.downloads.append(identity)
        data=self.payloads[identity]
        output.write_bytes(b"corrupt" if self.corrupt_download else data)
        if self.change_attempt_after_download:self.run["run_attempt"]=3


if __name__=="__main__":unittest.main()
