"""Prepare or publish a verified feature IPA without changing AltStore/latest."""
import argparse
import json
from pathlib import Path
import re
import shutil
import tempfile
import zipfile

from publish import api, gh, get_draft, list_releases
from release import inspect_ipa, read_config, sha256
from ui_test_manifest import REQUIRED_JOBS

REPO = "n624-dev/takupoke-ios"
BRANCH = "codex/pdf-local-recovery"
REQUIRED = REQUIRED_JOBS | {"Distribution tests", "Native PDF and recovery tests",
                            "Check iPhone build without publishing"}
ASSETS = ("takupoke.ipa", "SHA256SUMS", "INSTALL.txt")
MAX_ARCHIVE = 256 * 1024 * 1024


def check_snapshot(run, jobs, workflow, commit, run_id):
    if not re.fullmatch(r"[0-9a-f]{40}", commit) or type(run_id) is not int or run_id <= 0:
        raise ValueError("A full commit and positive run ID are required")
    attempt = run.get("run_attempt")
    if (run.get("id") != run_id or type(attempt) is not int or attempt <= 0
            or run.get("head_sha") != commit or run.get("head_branch") != BRANCH
            or run.get("repository", {}).get("full_name") != REPO
            or run.get("event") != "workflow_dispatch"
            or run.get("status") != "completed" or run.get("conclusion") != "success"
            or workflow.get("id") != run.get("workflow_id")
            or workflow.get("path") != ".github/workflows/ios-release.yml"):
        raise ValueError("Development build does not match the completed feature workflow")
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


def gate(run_id, commit):
    run = api(f"repos/{REPO}/actions/runs/{run_id}")
    workflow_id = run.get("workflow_id")
    if type(workflow_id) is not int or workflow_id <= 0:
        raise ValueError("Invalid workflow ID")
    workflow = api(f"repos/{REPO}/actions/workflows/{workflow_id}")
    attempt = run.get("run_attempt")
    if type(attempt) is not int or attempt <= 0:
        raise ValueError("Invalid run attempt")
    pages = json.loads(gh("api", "--paginate", "--slurp",
        f"repos/{REPO}/actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100"))
    return check_snapshot(run, [job for page in pages for job in page["jobs"]], workflow, commit, run_id)


def extract_build(archive_path, destination, commit):
    if archive_path.stat().st_size > MAX_ARCHIVE:
        raise ValueError("Artifact exceeds the download bound")
    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
        if len(entries) != 2 or {e.filename for e in entries} != {"takupoke.ipa", "release.json"}:
            raise ValueError("Artifact must contain exactly the IPA and build metadata")
        for entry in entries:
            limit = MAX_ARCHIVE if entry.filename == "takupoke.ipa" else 1024 * 1024
            if entry.file_size <= 0 or entry.file_size > limit or entry.external_attr >> 16 & 0o170000 == 0o120000:
                raise ValueError("Invalid artifact entry")
            with archive.open(entry) as source, (destination / entry.filename).open("xb") as target:
                shutil.copyfileobj(source, target, length=1024 * 1024)
    metadata = json.loads((destination / "release.json").read_text(encoding="utf-8"))
    if (metadata.get("repository") != REPO or metadata.get("commit") != commit
            or metadata.get("sha256", {}).get("takupoke.ipa") != sha256(destination / "takupoke.ipa")):
        raise ValueError("Artifact metadata or IPA checksum mismatch")
    config = read_config()
    if config["repository"] != REPO:
        raise ValueError("Unexpected distribution configuration")
    # Existing device/platform/unsigned/diagnostic/privacy/version/commit checks.
    inspect_ipa(destination / "takupoke.ipa", config, metadata["version"], metadata["build"], commit)
    return metadata


def prepare(run_id, commit, output):
    attempt = gate(run_id, commit)
    pages = json.loads(gh("api", "--paginate", "--slurp",
                         f"repos/{REPO}/actions/runs/{run_id}/artifacts?per_page=100"))
    expected = "takupoke-ios-development-" + commit
    artifacts = [a for page in pages for a in page["artifacts"] if a.get("name") == expected]
    if len(artifacts) != 1:
        raise ValueError("Missing or ambiguous development artifact")
    artifact = artifacts[0]
    if (type(artifact.get("id")) is not int or artifact["id"] <= 0 or artifact.get("expired") is not False
            or not 0 < artifact.get("size_in_bytes", 0) <= MAX_ARCHIVE
            or artifact.get("workflow_run", {}).get("id") != run_id
            or artifact["workflow_run"].get("head_sha") != commit):
        raise ValueError("Artifact identity, expiry or size mismatch")
    with tempfile.TemporaryDirectory(prefix="takupoke-dev-artifact-") as scratch:
        scratch = Path(scratch)
        archive = scratch / "artifact.zip"
        gh("api", f"repos/{REPO}/actions/artifacts/{artifact['id']}/zip", output=archive)
        digest = artifact.get("digest")
        if digest is not None and digest != "sha256:" + sha256(archive):
            raise ValueError("Downloaded artifact digest mismatch")
        built = scratch / "built"; built.mkdir()
        metadata = extract_build(archive, built, commit)
        if gate(run_id, commit) != attempt:
            raise ValueError("Required run was rerun during artifact download")
        output.mkdir()  # Never replace an existing directory or caller files.
        try:
            shutil.copyfile(built / "takupoke.ipa", output / "takupoke.ipa")
            (output / "INSTALL.txt").write_text(
                f"たくポケ iOS 開発版 {metadata['version']} ({metadata['build']})\n"
                f"Commit: {commit}\nCI: https://github.com/{REPO}/actions/runs/{run_id} (attempt {attempt})\n\n"
                "更新: 原本と照合した最大3項目の訂正は、全体プレビュー後に別操作で採用します。Homeの授業表示は時間割カードと共通です。\n"
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


def publish(output, metadata, run_id, attempt, commit):
    if ({p.name for p in output.iterdir()} != set(ASSETS)
            or sha256(output / "takupoke.ipa") != metadata["sha256"]["takupoke.ipa"]):
        raise ValueError("Prepared package changed before publication")
    inspect_ipa(output / "takupoke.ipa", read_config(), metadata["version"], metadata["build"], commit)
    tag = f"dev-ios-{run_id}-{attempt}-{commit[:12]}"
    if any(r.get("tag_name") == tag for r in list_releases(REPO)):
        raise ValueError("Development release collision; nothing will be replaced")
    refs = api(f"repos/{REPO}/git/matching-refs/tags/{tag}")
    if any(r.get("ref") == "refs/tags/" + tag for r in refs):
        raise ValueError("Development tag already exists")
    expected_hashes = {name: sha256(output / name) for name in ASSETS}
    owned_id = None
    with tempfile.TemporaryDirectory(prefix="takupoke-dev-upload-") as scratch:
        scratch = Path(scratch)
        request = scratch / "request.json"
        request.write_text(json.dumps({"tag_name": tag, "target_commitish": commit,
            "draft": True, "prerelease": True, "make_latest": "false",
            "name": f"たくポケ iOS 開発版 {metadata['version']} ({metadata['build']})",
            "body": (output / "INSTALL.txt").read_text(encoding="utf-8")}, ensure_ascii=False), encoding="utf-8")
        try:
            if gate(run_id, commit) != attempt:
                raise ValueError("Required run was rerun before publication")
            created = api(f"repos/{REPO}/releases", "--method", "POST", "--input", str(request))
            if type(created.get("id")) is not int or created["id"] <= 0:
                raise ValueError("Invalid new draft ID")
            owned_id = created["id"]
            draft = get_draft(REPO, owned_id, tag, commit)
            if not draft.get("prerelease") or draft.get("assets"):
                raise ValueError("Unexpected newly created draft")
            for name in ASSETS:
                api(f"https://uploads.github.com/repos/{REPO}/releases/{owned_id}/assets?name={name}",
                    "--method", "POST", "--header", "Content-Type: application/octet-stream", "--input", str(output / name))
            draft = get_draft(REPO, owned_id, tag, commit)
            assets = draft["assets"]
            if len(assets) != 3 or {a["name"] for a in assets} != set(ASSETS):
                raise ValueError("Uploaded asset inventory mismatch")
            for asset in assets:
                if asset["state"] != "uploaded" or asset["size"] != (output / asset["name"]).stat().st_size:
                    raise ValueError("Incomplete upload")
                saved = scratch / asset["name"]
                gh("api", "--header", "Accept: application/octet-stream",
                   f"repos/{REPO}/releases/assets/{asset['id']}", output=saved)
                if sha256(saved) != expected_hashes[asset["name"]]:
                    raise ValueError("Uploaded byte readback mismatch")
            if gate(run_id, commit) != attempt:
                raise ValueError("Required run changed during upload")
            response = api(f"repos/{REPO}/releases/{owned_id}", "--method", "PATCH",
                           "--field", "draft=false", "--field", "prerelease=true", "--raw-field", "make_latest=false")
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
            if owned_id is not None:
                # Never discover/delete another draft or remove a published release.
                try:
                    draft = get_draft(REPO, owned_id, tag, commit)
                    if draft.get("prerelease"):
                        gh("api", "--method", "DELETE", f"repos/{REPO}/releases/{owned_id}")
                except Exception as cleanup:
                    print(f"Owned draft cleanup was not completed: {type(cleanup).__name__}")
            raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", type=int, required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--output", type=Path, required=True, help="A new caller-owned package directory")
    parser.add_argument("--publish", action="store_true", help="Upload and publish after byte readback")
    args = parser.parse_args()
    metadata, attempt = prepare(args.run_id, args.commit, args.output)
    print(f"Verified development package: {args.output}")
    if args.publish:
        publish(args.output, metadata, args.run_id, attempt, args.commit)


if __name__ == "__main__":
    main()
