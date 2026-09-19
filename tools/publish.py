"""Publish verified assets as one draft-to-public release transition."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

from release import ASSETS, sha256, validate


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True).strip()


def api(path):
    return json.loads(gh("api", path))


def list_releases(repo):
    pages = json.loads(gh("api", "--paginate", "--slurp", f"repos/{repo}/releases?per_page=100"))
    return [item for page in pages for item in page]


def get_draft(repo, tag, commit):
    # The tag endpoint only retrieves published releases. Drafts must be
    # located in the authenticated listing and retrieved by numeric ID.
    matches = [item for item in list_releases(repo) if item["tag_name"] == tag]
    if len(matches) != 1:
        raise ValueError("Expected exactly one matching draft release")
    draft = api(f"repos/{repo}/releases/{matches[0]['id']}")
    if (not draft["draft"] or draft["tag_name"] != tag
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

        notes = scratch / "notes.md"
        notes.write_text(
            f"たくぽけ {metadata['version']} ({metadata['build']})\n\n"
            "AltStore Classic 向けの開発版です。署名は導入時に AltStore 側で行います。\n\n"
            f"Source: https://github.com/{repo}/releases/latest/download/altstore-source.json\n\n"
            "「学校資料を選ぶ」からPDF・XLSXを取得できます。解析・時間割表示は未実装です。OneDriveの継続アクセスは実機確認中です。\n\n"
            f"Commit: {commit}\n", encoding="utf-8"
        )
        # Retry a failed publication using the same verified artifact. Only an
        # unpublished draft for this exact commit may have its assets replaced.
        existing = next((r for r in all_releases if r["tag_name"] == tag), None)
        if existing is not None:
            if not existing["draft"] or existing["target_commitish"] != commit:
                raise ValueError("Refusing to replace an existing published or unrelated release")
            gh("release", "upload", tag, "--repo", repo, "--clobber",
               *[str(output / name) for name in ASSETS])
        else:
            gh("release", "create", tag, "--repo", repo, "--target", commit,
               "--draft", "--title", f"たくぽけ {metadata['version']} ({metadata['build']})",
               "--notes-file", str(notes), *[str(output / name) for name in ASSETS])
        draft = get_draft(repo, tag, commit)
        if {a["name"] for a in draft["assets"]} != set(ASSETS):
            raise ValueError("Draft release asset mismatch")
        if any(a["state"] != "uploaded" or a["size"] != (output / a["name"]).stat().st_size for a in draft["assets"]):
            raise ValueError("Incomplete release upload")
        downloaded = scratch / "downloaded"
        downloaded.mkdir()
        gh("release", "download", tag, "--repo", repo, "--dir", str(downloaded))
        for name in ASSETS:
            if sha256(output / name) != sha256(downloaded / name):
                raise ValueError("Uploaded release checksum mismatch")
        # Recheck after upload so a stale build cannot supersede newer main.
        if api(f"repos/{repo}/commits/main")["sha"] != commit:
            print("Main changed during upload; leaving this release as a draft.")
            return
        gh("release", "edit", tag, "--repo", repo, "--draft=false", "--latest")
        print(f"Published https://github.com/{repo}/releases/tag/{tag}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    publish(args.output)
