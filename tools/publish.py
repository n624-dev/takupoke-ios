"""Publish verified assets as one draft-to-public release transition."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from release import ASSETS, sha256, validate


def gh(*args, output=None):
    if output is not None:
        with output.open("wb") as stream:
            subprocess.run(["gh", *args], stdout=stream, check=True)
        return ""
    return subprocess.check_output(["gh", *args], text=True).strip()


def api(path, *options):
    return json.loads(gh("api", "--header", "Cache-Control: no-cache", *options, path))


def list_releases(repo):
    pages = json.loads(gh("api", "--header", "Cache-Control: no-cache", "--paginate", "--slurp",
                         f"repos/{repo}/releases?per_page=100"))
    return [item for page in pages for item in page]


def get_draft(repo, release_id, tag, commit):
    # Use the creation response ID. A just-created draft may not appear in
    # the listing yet, and the tag endpoint does not retrieve drafts.
    if type(release_id) is not int or release_id <= 0:
        raise ValueError("Invalid release ID")
    draft = api(f"repos/{repo}/releases/{release_id}")
    if (draft["id"] != release_id or not draft["draft"] or draft["tag_name"] != tag
            or draft["target_commitish"] != commit):
        raise ValueError("Refusing an unexpected or already published release")
    return draft


def release_is_newer(candidate, current):
    def numbers(value):
        return tuple(int(part) for part in value.split("."))
    return (numbers(candidate["version"]), numbers(candidate["build"])) > (
        numbers(current["version"]), numbers(current["build"])
    )


def publish(output):
    metadata = validate(output)
    repo, tag, commit = metadata["repository"], metadata["tag"], metadata["commit"]
    # Only the trusted main-branch workflow may publish, including manual runs.
    if (os.environ.get("GITHUB_REPOSITORY") != repo
            or os.environ.get("GITHUB_REF") != "refs/heads/main"
            or os.environ.get("GITHUB_SHA") != commit
            or os.environ.get("GITHUB_EVENT_NAME") not in ("push", "workflow_dispatch")):
        raise ValueError("Publishing is restricted to the configured main branch")
    if api(f"repos/{repo}/commits/main")["sha"] != commit:
        print("A newer main commit exists; this run will not publish.")
        return

    # Refuse to move latest backwards when an old run is retried. Any download
    # failure aborts publication instead of assuming that no prior release exists.
    all_releases = list_releases(repo)
    published = [r for r in all_releases if not r["draft"] and not r["prerelease"]]
    with tempfile.TemporaryDirectory(prefix="takupoke-publish-") as scratch:
        scratch = Path(scratch)
        if published:
            latest = api(f"repos/{repo}/releases/latest")
            previous = scratch / "previous"
            previous.mkdir()
            gh("release", "download", latest["tag_name"], "--repo", repo,
               "--pattern", "release.json", "--dir", str(previous))
            current = json.loads((previous / "release.json").read_text(encoding="utf-8"))
            if not release_is_newer(metadata, current):
                print("This version is already published or older than latest; skipped.")
                return

        notes = (
            f"たくポケ {metadata['version']} ({metadata['build']})\n\n"
            "AltStore Classic 向けの開発版です。署名は導入時に AltStore 側で行います。\n\n"
            f"Source: https://github.com/{repo}/releases/latest/download/altstore-source.json\n\n"
            "アプリ名を「たくポケ」に修正。OneDriveは個別ファイル選択を基本とし、学校行事は学校サイトから取得・保持します。変更なしなら再ダウンロードを省きます。解析・時間割表示は未実装です。\n\n"
            f"Commit: {commit}\n"
        )
        # Retry a failed publication using the same verified artifact. Only an
        # unpublished draft for this exact commit may have its assets replaced.
        matches = [r for r in all_releases if r["tag_name"] == tag]
        if len(matches) > 1:
            raise ValueError("Ambiguous existing release")
        existing = matches[0] if matches else None
        if existing is not None:
            if not existing["draft"] or existing["target_commitish"] != commit:
                raise ValueError("Refusing to replace an existing published or unrelated release")
            release_id = existing["id"]
        else:
            request = scratch / "release-request.json"
            request.write_text(json.dumps({
                "tag_name": tag, "target_commitish": commit, "draft": True,
                "prerelease": False,
                "name": f"たくポケ {metadata['version']} ({metadata['build']})",
                "body": notes,
            }, ensure_ascii=False), encoding="utf-8")
            created = api(f"repos/{repo}/releases", "--method", "POST", "--input", str(request))
            release_id = created["id"]
        draft = get_draft(repo, release_id, tag, commit)
        if any(a["name"] not in ASSETS for a in draft["assets"]):
            raise ValueError("Unexpected asset in existing draft")
        # ID-based operations avoid the CLI's tag/list discovery for drafts.
        for asset in draft["assets"]:
            gh("api", "--method", "DELETE", f"repos/{repo}/releases/assets/{asset['id']}")
        for name in ASSETS:
            api(f"https://uploads.github.com/repos/{repo}/releases/{release_id}/assets?name={name}",
                "--method", "POST", "--header", "Content-Type: application/octet-stream",
                "--input", str(output / name))
        draft = get_draft(repo, release_id, tag, commit)
        if len(draft["assets"]) != len(ASSETS) or {a["name"] for a in draft["assets"]} != set(ASSETS):
            raise ValueError("Draft release asset mismatch")
        if any(a["state"] != "uploaded" or a["size"] != (output / a["name"]).stat().st_size for a in draft["assets"]):
            raise ValueError("Incomplete release upload")
        downloaded = scratch / "downloaded"
        downloaded.mkdir()
        for asset in draft["assets"]:
            gh("api", "--header", "Accept: application/octet-stream",
               f"repos/{repo}/releases/assets/{asset['id']}", output=downloaded / asset["name"])
        for name in ASSETS:
            if sha256(output / name) != sha256(downloaded / name):
                raise ValueError("Uploaded release checksum mismatch")
        # Recheck after upload so a stale build cannot supersede newer main.
        if api(f"repos/{repo}/commits/main")["sha"] != commit:
            print("Main changed during upload; leaving this release as a draft.")
            return
        published_release = api(f"repos/{repo}/releases/{release_id}", "--method", "PATCH",
            "--field", "draft=false", "--raw-field", "make_latest=true")
        if (published_release["id"] != release_id or published_release["draft"]
                or published_release["tag_name"] != tag
                or published_release["target_commitish"] != commit):
            raise ValueError("Unexpected publication response")
        print(f"Published https://github.com/{repo}/releases/tag/{tag}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    publish(args.output)
