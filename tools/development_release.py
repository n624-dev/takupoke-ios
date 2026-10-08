"""Prepare or publish a verified feature IPA without changing AltStore/latest."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import tempfile

from publish import api, gh, get_draft, list_releases
from release import inspect_ipa, read_config, sha256, validate_notes
from ui_test_manifest import ALL_UI_REQUIRED_JOBS

REPO = "n624-dev/takupoke-ios"
BRANCH = "codex/pdf-local-recovery"
REQUIRED = ALL_UI_REQUIRED_JOBS | {"Distribution tests", "Native PDF and recovery tests",
                            "Check iPhone build without publishing"}
ASSETS = ("takupoke.ipa", "SHA256SUMS", "INSTALL.txt")
STAGED_ASSETS = ("takupoke.ipa", "release.json")
MAX_IPA = 256 * 1024 * 1024
STAGING_JOB = "Check iPhone build without publishing"


def check_identity(run, workflow, commit, run_id):
    if not re.fullmatch(r"[0-9a-f]{40}", commit) or type(run_id) is not int or run_id <= 0:
        raise ValueError("A full commit and positive run ID are required")
    attempt = run.get("run_attempt")
    if (run.get("id") != run_id or type(attempt) is not int or attempt <= 0
            or run.get("head_sha") != commit or run.get("head_branch") != BRANCH
            or run.get("repository", {}).get("full_name") != REPO
            or run.get("event") != "workflow_dispatch"
            or workflow.get("id") != run.get("workflow_id")
            or workflow.get("path") != ".github/workflows/ios-release.yml"):
        raise ValueError("Development build does not match the feature workflow")
    return attempt


def check_snapshot(run, jobs, workflow, commit, run_id):
    attempt = check_identity(run, workflow, commit, run_id)
    if run.get("status") != "completed" or run.get("conclusion") != "success":
        raise ValueError("Development workflow is not completed successfully")
    found = {}
    for job in jobs:
        name = job.get("name")
        if name not in REQUIRED:
            continue
        if name in found or (job.get("run_id") != run_id or job.get("run_attempt") != attempt
                            or job.get("head_sha") != commit or job.get("status") != "completed"
                            or job.get("conclusion") != "success"):
            raise ValueError("Required job has wrong identity, status or duplicate name")
        found[name] = job
    if set(found) != REQUIRED:
        raise ValueError("Required development checks are missing")
    return attempt


def check_stage_snapshot(run, jobs, workflow, commit, run_id, attempt, job_key):
    current = check_identity(run, workflow, commit, run_id)
    # GitHub can report an aggregate run as queued while matrix siblings wait
    # and this build job is already executing. Verify the actual executing job.
    if (current != attempt or job_key != "development-build"
            or run.get("status") not in ("queued", "in_progress")
            or run.get("conclusion") is not None):
        raise ValueError("Staging run/source/attempt is not current")
    matches = [job for job in jobs if job.get("name") == STAGING_JOB]
    if len(matches) != 1:
        raise ValueError("Current development build job is missing or ambiguous")
    job = matches[0]
    if (type(job.get("id")) is not int or job["id"] <= 0
            or job.get("run_id") != run_id or job.get("run_attempt") != attempt
            or job.get("head_sha") != commit or job.get("status") != "in_progress"
            or job.get("conclusion") is not None or not job.get("started_at")
            or job.get("completed_at") is not None):
        raise ValueError("Development build job is not executing for this source and attempt")
    return current


def fetch_jobs(run_id, attempt):
    pages = json.loads(gh("api", "--paginate", "--slurp",
        f"repos/{REPO}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100"))
    return [job for page in pages for job in page["jobs"]]


def gate(run_id, commit):
    run = api(f"repos/{REPO}/actions/runs/{run_id}")
    workflow_id = run.get("workflow_id")
    if type(workflow_id) is not int or workflow_id <= 0:
        raise ValueError("Invalid workflow ID")
    workflow = api(f"repos/{REPO}/actions/workflows/{workflow_id}")
    attempt = run.get("run_attempt")
    if type(attempt) is not int or attempt <= 0:
        raise ValueError("Invalid run attempt")
    return check_snapshot(run, fetch_jobs(run_id, attempt), workflow, commit, run_id)


def inspect_build(destination, commit):
    for name, cap in (("takupoke.ipa", MAX_IPA), ("release.json", 1024 * 1024)):
        path = destination / name
        if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= cap:
            raise ValueError("Invalid staged build file")
    metadata = json.loads((destination / "release.json").read_text(encoding="utf-8"))
    if (metadata.get("repository") != REPO or metadata.get("commit") != commit
            or metadata.get("sha256", {}).get("takupoke.ipa") != sha256(destination / "takupoke.ipa")):
        raise ValueError("Build metadata or IPA checksum mismatch")
    validate_notes(metadata.get("releaseNotes"))
    config = read_config()
    if config["repository"] != REPO:
        raise ValueError("Unexpected distribution configuration")
    # Existing device/platform/unsigned/diagnostic/privacy/version/commit checks.
    inspect_ipa(destination / "takupoke.ipa", config, metadata["version"], metadata["build"], commit)
    return metadata


def stage_identity(run_id, attempt, commit):
    return "TAKUPOKE-DEVELOPMENT-STAGE\n" + json.dumps(
        {"schemaVersion": 1, "repository": REPO, "branch": BRANCH,
         "runId": run_id, "attempt": attempt, "commit": commit}, sort_keys=True)


def tag_name(run_id, attempt, commit):
    return f"dev-ios-{run_id}-{attempt}-{commit[:12]}"


def owned_stage(draft_id, run_id, attempt, commit):
    if type(draft_id) is not int or draft_id <= 0:
        raise ValueError("Invalid owned draft ID")
    draft = get_draft(REPO, draft_id, tag_name(run_id, attempt, commit), commit)
    if draft.get("prerelease") is not True or draft.get("body") != stage_identity(run_id, attempt, commit):
        raise ValueError("Draft does not carry the exact staging ownership proof")
    return draft


def find_stage(run_id, attempt, commit):
    matches = [r for r in list_releases(REPO) if r.get("tag_name") == tag_name(run_id, attempt, commit)]
    if len(matches) != 1:
        raise ValueError("Missing or ambiguous staged development draft")
    return owned_stage(matches[0].get("id"), run_id, attempt, commit)


def cleanup_stage(draft_id, run_id, attempt, commit):
    # The recorded ID, exact tag/SHA/body and still-private state must all match.
    # Never search for/delete another draft, or remove a published release.
    owned_stage(draft_id, run_id, attempt, commit)
    gh("api", "--method", "DELETE", f"repos/{REPO}/releases/{draft_id}")


def download_assets(draft, destination, expected):
    assets = draft.get("assets", [])
    if len(assets) != len(expected) or {a.get("name") for a in assets} != set(expected):
        raise ValueError("Staged asset inventory mismatch")
    for asset in assets:
        name = asset["name"]
        cap = MAX_IPA if name == "takupoke.ipa" else 1024 * 1024
        if (type(asset.get("id")) is not int or asset["id"] <= 0 or asset.get("state") != "uploaded"
                or type(asset.get("size")) is not int or not 0 < asset["size"] <= cap):
            raise ValueError("Incomplete or oversized staged asset")
        target = destination / name
        gh("api", "--header", "Accept: application/octet-stream",
           f"repos/{REPO}/releases/assets/{asset['id']}", output=target)
        if target.stat().st_size != asset["size"]:
            raise ValueError("Staged asset size readback mismatch")
        digest = asset.get("digest")
        if digest is not None and digest != "sha256:" + sha256(target):
            raise ValueError("Staged asset digest readback mismatch")


def stage(build, github_output):
    # This creates a PRIVATE draft only. It never substitutes for the thirteen-
    # completed-job gate used by prepare/publish.
    if (os.environ.get("GITHUB_REPOSITORY") != REPO or os.environ.get("GITHUB_REF") != "refs/heads/" + BRANCH
            or os.environ.get("GITHUB_EVENT_NAME") != "workflow_dispatch"):
        raise ValueError("Staging is restricted to the trusted feature dispatch")
    run_id = int(os.environ["GITHUB_RUN_ID"])
    commit = os.environ["GITHUB_SHA"]
    attempt = int(os.environ["GITHUB_RUN_ATTEMPT"])
    run = api(f"repos/{REPO}/actions/runs/{run_id}")
    workflow = api(f"repos/{REPO}/actions/workflows/{run['workflow_id']}")
    check_stage_snapshot(run, fetch_jobs(run_id, attempt), workflow, commit, run_id,
                         attempt, os.environ.get("GITHUB_JOB"))
    metadata = inspect_build(build, commit)
    tag = tag_name(run_id, attempt, commit)
    if any(r.get("tag_name") == tag for r in list_releases(REPO)):
        raise ValueError("Development release collision; nothing will be replaced")
    refs = api(f"repos/{REPO}/git/matching-refs/tags/{tag}")
    if any(r.get("ref") == "refs/tags/" + tag for r in refs):
        raise ValueError("Development tag already exists")
    owned_id = None
    with tempfile.TemporaryDirectory(prefix="takupoke-dev-stage-") as scratch:
        scratch = Path(scratch)
        request = scratch / "request.json"
        request.write_text(json.dumps({"tag_name": tag, "target_commitish": commit,
            "draft": True, "prerelease": True, "make_latest": "false",
            "name": f"たくポケ iOS 開発版 {metadata['version']} ({metadata['build']})",
            "body": stage_identity(run_id, attempt, commit)}, ensure_ascii=False), encoding="utf-8")
        try:
            created = api(f"repos/{REPO}/releases", "--method", "POST", "--input", str(request))
            if type(created.get("id")) is not int or created["id"] <= 0:
                raise ValueError("Invalid new draft ID")
            owned_id = created["id"]
            # Record ownership before any upload; Actions/root can clean this ID
            # on failure/cancellation, without touching a preexisting release.
            with github_output.open("a", encoding="utf-8") as handle:
                handle.write(f"draft_id={owned_id}\n")
            draft = owned_stage(owned_id, run_id, attempt, commit)
            if draft.get("assets"):
                raise ValueError("New staging draft is not empty")
            for name in STAGED_ASSETS:
                api(f"https://uploads.github.com/repos/{REPO}/releases/{owned_id}/assets?name={name}",
                    "--method", "POST", "--header", "Content-Type: application/octet-stream", "--input", str(build / name))
            downloaded = scratch / "verified"; downloaded.mkdir()
            download_assets(owned_stage(owned_id, run_id, attempt, commit), downloaded, STAGED_ASSETS)
            if any(sha256(downloaded / name) != sha256(build / name) for name in STAGED_ASSETS):
                raise ValueError("Staging byte readback mismatch")
            inspect_build(downloaded, commit)
            print(f"Private development draft staged: {owned_id}; run={run_id}; attempt={attempt}; commit={commit}")
        except BaseException:
            if owned_id is not None:
                try:
                    cleanup_stage(owned_id, run_id, attempt, commit)
                except Exception as cleanup:
                    print(f"Owned draft cleanup was not completed: {type(cleanup).__name__}")
            raise


def prepare(run_id, commit, output):
    attempt = gate(run_id, commit)
    draft = find_stage(run_id, attempt, commit)
    with tempfile.TemporaryDirectory(prefix="takupoke-dev-package-") as scratch:
        scratch = Path(scratch)
        built = scratch / "built"; built.mkdir()
        download_assets(draft, built, STAGED_ASSETS)
        metadata = inspect_build(built, commit)
        if gate(run_id, commit) != attempt:
            raise ValueError("Required run was rerun during staged download")
        output.mkdir()  # Never replace an existing directory or caller files.
        try:
            shutil.copyfile(built / "takupoke.ipa", output / "takupoke.ipa")
            (output / "INSTALL.txt").write_text(
                f"たくポケ iOS 開発版 {metadata['version']} ({metadata['build']})\n"
                f"Commit: {commit}\nCI: https://github.com/{REPO}/actions/runs/{run_id} (attempt {attempt})\n\n"
                f"更新:\n{metadata['releaseNotes']}\n\n"
                "追加の生成AIモデルは品質未合格のため配信していません。\n\n"
                "iOS 26 以上向けの未署名 IPA です。直接インストールはできません。\n"
                "AltStore Classic 等の署名・サイドロード手段で、この IPA を手動で取り込んでください。\n"
                "署名に使うアカウント情報を本リポジトリへ送信する必要はありません。\n"
                "この添付は正式 AltStore Source を更新しません。実機での動作確認は別途必要です。\n"
                "自動テストの成功は学校の実資料に対する復旧精度の合格を意味しません。\n",
                encoding="utf-8")
            (output / "SHA256SUMS").write_text("".join(
                f"{sha256(output / name)}  {name}\n" for name in ("takupoke.ipa", "INSTALL.txt")), encoding="utf-8")
        except BaseException:
            shutil.rmtree(output)
            raise
    return metadata, attempt


def publish(output, metadata, run_id, attempt, commit, expected_draft_id=None):
    if ({p.name for p in output.iterdir()} != set(ASSETS)
            or sha256(output / "takupoke.ipa") != metadata["sha256"]["takupoke.ipa"]):
        raise ValueError("Prepared package changed before publication")
    inspect_ipa(output / "takupoke.ipa", read_config(), metadata["version"], metadata["build"], commit)
    tag = tag_name(run_id, attempt, commit)
    if gate(run_id, commit) != attempt:
        raise ValueError("Required run was rerun before publication")
    draft = find_stage(run_id, attempt, commit)
    owned_id = draft["id"]
    if expected_draft_id is not None and owned_id != expected_draft_id:
        raise ValueError("Owned development draft changed before publication")
    expected_hashes = {name: sha256(output / name) for name in ASSETS}
    with tempfile.TemporaryDirectory(prefix="takupoke-dev-upload-") as scratch:
        scratch = Path(scratch)
        try:
            verified = scratch / "staged"; verified.mkdir()
            download_assets(draft, verified, STAGED_ASSETS)
            staged_metadata = inspect_build(verified, commit)
            if staged_metadata != metadata or sha256(verified / "takupoke.ipa") != expected_hashes["takupoke.ipa"]:
                raise ValueError("Prepared package no longer matches the owned staged build")
            for name in ("INSTALL.txt", "SHA256SUMS"):
                api(f"https://uploads.github.com/repos/{REPO}/releases/{owned_id}/assets?name={name}",
                    "--method", "POST", "--header", "Content-Type: application/octet-stream", "--input", str(output / name))
            draft = owned_stage(owned_id, run_id, attempt, commit)
            assets = draft["assets"]
            if len(assets) != 4 or {a["name"] for a in assets} != set(ASSETS) | {"release.json"}:
                raise ValueError("Uploaded asset inventory mismatch")
            for asset in assets:
                if asset["name"] == "release.json":
                    continue
                if asset["state"] != "uploaded" or asset["size"] != (output / asset["name"]).stat().st_size:
                    raise ValueError("Incomplete upload")
                saved = scratch / asset["name"]
                gh("api", "--header", "Accept: application/octet-stream",
                   f"repos/{REPO}/releases/assets/{asset['id']}", output=saved)
                if sha256(saved) != expected_hashes[asset["name"]]:
                    raise ValueError("Uploaded byte readback mismatch")
            if gate(run_id, commit) != attempt:
                raise ValueError("Required run changed during upload")
            staged_json = next(a for a in assets if a["name"] == "release.json")
            api(f"repos/{REPO}/releases/assets/{staged_json['id']}", "--method", "DELETE")
            final = owned_stage(owned_id, run_id, attempt, commit)
            if len(final.get("assets", [])) != 3 or {a["name"] for a in final["assets"]} != set(ASSETS):
                raise ValueError("Final owned draft inventory mismatch")
            if gate(run_id, commit) != attempt:
                raise ValueError("Required run changed before finalization")
            response = api(f"repos/{REPO}/releases/{owned_id}", "--method", "PATCH",
                           "--field", "draft=false", "--field", "prerelease=true", "--raw-field", "make_latest=false",
                           "--raw-field", "body=" + (output / "INSTALL.txt").read_text(encoding="utf-8"))
            if (response.get("id") != owned_id or response.get("draft") is not False
                    or response.get("prerelease") is not True or response.get("tag_name") != tag
                    or response.get("target_commitish") != commit):
                raise ValueError("Unexpected published release response")
            public = api(f"repos/{REPO}/releases/{owned_id}")
            if (public.get("id") != owned_id or public.get("draft") is not False or public.get("prerelease") is not True
                    or public.get("tag_name") != tag or public.get("target_commitish") != commit
                    or len(public.get("assets", [])) != 3
                    or {a["name"] for a in public["assets"]} != set(ASSETS)):
                raise ValueError("Published release identity or inventory mismatch")
            for asset in public["assets"]:
                saved = scratch / ("public-" + asset["name"])
                gh("api", "--header", "Accept: application/octet-stream",
                   f"repos/{REPO}/releases/assets/{asset['id']}", output=saved)
                if sha256(saved) != expected_hashes[asset["name"]]:
                    raise ValueError("Published asset byte readback mismatch")
            print(f"Published https://github.com/{REPO}/releases/tag/{tag}")
        except BaseException:
            try:
                cleanup_stage(owned_id, run_id, attempt, commit)
            except Exception as cleanup:
                print(f"Owned draft cleanup was not completed: {type(cleanup).__name__}")
            raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", type=int)
    parser.add_argument("--commit")
    parser.add_argument("--output", type=Path, help="A new caller-owned package directory")
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--stage", type=Path, help="Stage a local build as a private owned draft only")
    modes.add_argument("--cleanup-draft", type=int, help="Delete only the exact private owned draft")
    modes.add_argument("--publish", action="store_true", help="Finalize only after all thirteen checks and byte readback")
    args = parser.parse_args()
    if args.stage:
        if not os.environ.get("GITHUB_OUTPUT"):
            parser.error("Staging needs the Actions ownership-output path")
        stage(args.stage, Path(os.environ["GITHUB_OUTPUT"]))
        return
    if args.run_id is None or args.commit is None:
        parser.error("Preparation/cleanup requires exact run and commit")
    if args.cleanup_draft is not None:
        run = api(f"repos/{REPO}/actions/runs/{args.run_id}")
        workflow = api(f"repos/{REPO}/actions/workflows/{run['workflow_id']}")
        attempt = check_identity(run, workflow, args.commit, args.run_id)
        cleanup_stage(args.cleanup_draft, args.run_id, attempt, args.commit)
        return
    if args.output is None:
        parser.error("Preparation requires a new caller-owned output directory")
    metadata, attempt = prepare(args.run_id, args.commit, args.output)
    print(f"Verified development package: {args.output}")
    if args.publish:
        publish(args.output, metadata, args.run_id, attempt, args.commit)


if __name__ == "__main__":
    main()
