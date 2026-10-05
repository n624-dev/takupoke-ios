"""Publish a prior completed feature run from a trusted hosted dispatch only."""
import argparse
import os
from pathlib import Path
import re
import subprocess

import development_release as development
from publish import api

ROOT = Path(__file__).resolve().parents[1]


def check_context(environment, checkout_commit):
    current = environment.get("GITHUB_SHA", "")
    source = environment.get("TKPK_DEVELOPMENT_SOURCE", "")
    run = environment.get("TKPK_DEVELOPMENT_RUN_ID", "")
    if (environment.get("GITHUB_REPOSITORY") != development.REPO
            or environment.get("GITHUB_REF") != "refs/heads/" + development.BRANCH
            or environment.get("GITHUB_EVENT_NAME") != "workflow_dispatch"
            or environment.get("GITHUB_JOB") != "development-publish"
            or environment.get("GITHUB_WORKFLOW_REF") != development.REPO
               + "/.github/workflows/ios-release.yml@refs/heads/" + development.BRANCH
            or environment.get("TKPK_DEVELOPMENT_MODE") != "development-publish"
            or not re.fullmatch(r"[0-9a-f]{40}", current)
            or checkout_commit != current
            or not re.fullmatch(r"[0-9a-f]{40}", source)
            or not re.fullmatch(r"[1-9][0-9]{0,19}", run)
            or not re.fullmatch(r"[1-9][0-9]{0,19}", environment.get("GITHUB_RUN_ID", ""))
            or run == environment.get("GITHUB_RUN_ID")):
        raise ValueError("Untrusted development publication dispatch or prior-run input")
    return int(run), source


def publish_prior(run_id, source, output, github_output):
    # This is the prior run's gate. The publication run never earns test credit.
    attempt = development.gate(run_id, source)
    draft = development.find_stage(run_id, attempt, source)
    owned_id = draft["id"]
    # Persist the exact private ownership before download/upload so cancellation
    # cleanup cannot search for, or delete, a different release.
    with github_output.open("a", encoding="utf-8") as stream:
        stream.write(f"draft_id={owned_id}\nqualified_run_id={run_id}\nqualified_source={source}\n")
    latest_before = api(f"repos/{development.REPO}/releases/latest")["id"]
    main_before = api(f"repos/{development.REPO}/commits/main")["sha"]
    metadata, prepared_attempt = development.prepare(run_id, source, output)
    if prepared_attempt != attempt:
        raise ValueError("Qualified run changed during preparation")
    development.publish(output, metadata, run_id, attempt, source, expected_draft_id=owned_id)
    if (api(f"repos/{development.REPO}/releases/latest")["id"] != latest_before
            or api(f"repos/{development.REPO}/commits/main")["sha"] != main_before):
        raise ValueError("Formal latest or main changed during development publication")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    checkout = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    run_id, source = check_context(os.environ, checkout)
    if not os.environ.get("GITHUB_OUTPUT"):
        raise ValueError("Hosted publication needs its ownership output path")
    publish_prior(run_id, source, arguments.output, Path(os.environ["GITHUB_OUTPUT"]))


if __name__ == "__main__":
    main()
