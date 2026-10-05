"""Fictional package/API responses only; no network writes or real IPA."""
import copy
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
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

    def artifact(self, *, extra=None):
        self.write_ipa()
        metadata={"repository":dev.REPO,"commit":COMMIT,"version":"0.1.12","build":"12.1",
                  "sha256":{"takupoke.ipa":dev.sha256(self.output/"takupoke.ipa")}}
        path=Path(self.scratch.name)/"artifact.zip"
        with zipfile.ZipFile(path,"w") as z:
            z.write(self.output/"takupoke.ipa","takupoke.ipa")
            z.writestr("release.json",json.dumps(metadata))
            for name,data in (extra or {}).items():z.writestr(name,data)
        target=Path(self.scratch.name)/"extracted";target.mkdir()
        return path,target,metadata

    def test_original_device_metadata_and_bytes_are_inspected(self):
        path,target,expected=self.artifact()
        self.assertEqual(dev.extract_build(path,target,COMMIT),expected)
        self.assertEqual((target/"takupoke.ipa").read_bytes(),(self.output/"takupoke.ipa").read_bytes())

    def test_extra_altstore_or_traversal_entries_are_rejected(self):
        for name in ("altstore-source.json","../unexpected","Payload/extra"):
            with self.subTest(name=name):
                path,target,_=self.artifact(extra={name:"fictional"})
                with self.assertRaises(ValueError):dev.extract_build(path,target,COMMIT)
                target.rmdir()

    def test_wrong_device_commit_cannot_be_rescued_by_outer_metadata(self):
        self.info["TakupokeCommit"]="b"*40
        path,target,_=self.artifact()
        with self.assertRaisesRegex(ValueError,"TakupokeCommit"):
            dev.extract_build(path,target,COMMIT)

    def test_collision_fails_before_any_release_mutation(self):
        self.write_ipa();meta={"version":"0.1.12","build":"12.1",
            "sha256":{"takupoke.ipa":dev.sha256(self.output/"takupoke.ipa")}}
        for name in ("SHA256SUMS","INSTALL.txt"):(self.output/name).write_text("fictional")
        with patch.object(dev,"list_releases",return_value=[{"tag_name":f"dev-ios-123-2-{COMMIT[:12]}"}]), patch.object(dev,"api") as api:
            with self.assertRaisesRegex(ValueError,"collision"):dev.publish(self.output,meta,123,2,COMMIT)
            api.assert_not_called()

    def test_upload_failure_only_removes_its_new_owned_draft(self):
        self.write_ipa();meta={"version":"0.1.12","build":"12.1",
            "sha256":{"takupoke.ipa":dev.sha256(self.output/"takupoke.ipa")}}
        for name in ("SHA256SUMS","INSTALL.txt"):(self.output/name).write_text("fictional")
        calls=[]
        def api(path,*args):
            calls.append((path,args))
            if "/matching-refs/" in path:return []
            if path.endswith("/releases") and "POST" in args:return {"id":789}
            if path.startswith("https://uploads."):raise RuntimeError("fictional upload failure")
            raise AssertionError(path)
        with patch.object(dev,"list_releases",return_value=[]),patch.object(dev,"gate",return_value=2),patch.object(dev,"api",side_effect=api),patch.object(dev,"get_draft",return_value={"prerelease":True,"assets":[]}),patch.object(dev,"gh") as gh:
            with self.assertRaisesRegex(RuntimeError,"upload failure"):dev.publish(self.output,meta,123,2,COMMIT)
            gh.assert_called_once_with("api","--method","DELETE",f"repos/{dev.REPO}/releases/789")
            # The create payload is the only release-writing request before failure.
            self.assertEqual(sum(path.endswith("/releases") for path,_ in calls),1)

    def test_publish_has_three_exact_assets_no_latest_or_altstore_and_public_readback(self):
        self.write_ipa();meta={"version":"0.1.12","build":"12.1",
            "sha256":{"takupoke.ipa":dev.sha256(self.output/"takupoke.ipa")}}
        for name in ("SHA256SUMS","INSTALL.txt"):(self.output/name).write_text("fictional")
        tag=f"dev-ios-123-2-{COMMIT[:12]}"
        assets=[{"id":i+1,"name":n,"state":"uploaded","size":(self.output/n).stat().st_size}
                for i,n in enumerate(dev.ASSETS)]
        draft={"id":789,"tag_name":tag,"target_commitish":COMMIT,"draft":True,"prerelease":True,"assets":assets}
        requests=[];uploaded=[];downloaded=[]
        def api(path,*args):
            if "/matching-refs/" in path:return []
            if path.endswith("/releases"):
                request=json.loads(Path(args[args.index("--input")+1]).read_text());requests.append(request)
                return {"id":789}
            if path.startswith("https://uploads."):
                uploaded.append(path.split("name=")[1]);return {}
            if "PATCH" in args:
                self.assertIn("make_latest=false",args);draft["draft"]=False;return draft
            return draft
        def gh(*args,output=None):
            self.assertNotIn("DELETE",args)
            asset=next(a for a in assets if args[-1].endswith("/"+str(a["id"])))
            downloaded.append(asset["name"]);output.write_bytes((self.output/asset["name"]).read_bytes())
        def read_draft(*args):return draft|{"assets":[] if not uploaded else assets}
        with redirect_stdout(io.StringIO()),patch.object(dev,"list_releases",return_value=[]),patch.object(dev,"gate",return_value=2),patch.object(dev,"api",side_effect=api),patch.object(dev,"get_draft",side_effect=read_draft),patch.object(dev,"gh",side_effect=gh):
            dev.publish(self.output,meta,123,2,COMMIT)
        self.assertEqual(uploaded,list(dev.ASSETS));self.assertEqual(downloaded,list(dev.ASSETS)*2)
        self.assertEqual(requests[0]["make_latest"],"false");self.assertTrue(requests[0]["prerelease"])
        self.assertTrue(requests[0]["draft"])


if __name__=="__main__":unittest.main()
