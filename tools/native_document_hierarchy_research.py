"""Research-only real Apple compilation/probe, with owned bounded cleanup.

No artifact, release, cache, dispatch, school input or language-model operation.
The caller must be the single exact research push; this never launches CI.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import selectors
import shutil
import signal
import subprocess
import sys
import tempfile
import time

REPO = "n624-dev/takupoke-ios"
BRANCH = "codex/ios-native-document-hierarchy-validation-20261005"
RESERVE = 2 * 1024**3 + 256 * 1024**2
MAX_OUTPUT = 256 * 1024
MAX_OWNED_RSS = 2 * 1024**3
ROOT = Path(__file__).resolve().parents[1]
SOURCES = ("Takupoke/RecoveryOCRAcquisition.swift", "Takupoke/RecoveryOCRStructure.swift",
           "Takupoke/RecoveryVisionCapture.swift")


def identity(env, actual_head):
    if (env.get("GITHUB_REPOSITORY") != REPO or env.get("GITHUB_EVENT_NAME") != "push"
            or env.get("GITHUB_REF") != "refs/heads/" + BRANCH
            or not re.fullmatch(r"[0-9a-f]{40}", env.get("GITHUB_SHA", ""))
            or actual_head != env["GITHUB_SHA"]
            or not re.fullmatch(r"[1-9][0-9]*", env.get("GITHUB_RUN_ID", ""))
            or env.get("GITHUB_RUN_ATTEMPT") != "1"):
        raise ValueError("Only the exact first-attempt research push is permitted")


def owned_rss(group):
    # Observed owned-process-group RSS only; system Vision services are separate.
    output = subprocess.check_output(["ps", "-axo", "pgid=,rss="], text=True, timeout=5)
    return sum(int(parts[1]) * 1024 for line in output.splitlines()
               if len(parts := line.split()) == 2 and parts[0] == str(group))


def stop_owned(process):
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            pass
        if sig == signal.SIGTERM:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                continue
        else:
            process.wait(timeout=5)


def phase(label, command, *, seconds, scratch):
    print("RESEARCH phase start: " + label, flush=True)
    if shutil.disk_usage(scratch).free < RESERVE:
        raise RuntimeError("Research disk reserve failed before phase")
    env = os.environ | {"TMPDIR": str(scratch), "CLANG_MODULE_CACHE_PATH": str(scratch / "modules")}
    started = time.monotonic()
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True, env=env)
    total = 0; peak = 0
    selector = selectors.DefaultSelector()
    try:
        os.set_blocking(process.stdout.fileno(), False)
        selector.register(process.stdout, selectors.EVENT_READ)
        while selector.get_map() or process.poll() is None:
            if time.monotonic() - started > seconds:
                raise TimeoutError("Research phase wall limit: " + label)
            peak = max(peak, owned_rss(process.pid))
            if peak > MAX_OWNED_RSS or shutil.disk_usage(scratch).free < RESERVE:
                raise RuntimeError("Research owned RSS or disk reserve limit")
            for key, _ in selector.select(timeout=1):
                block = os.read(key.fd, 16 * 1024)
                if not block:
                    selector.unregister(key.fileobj)
                    continue
                total += len(block)
                if total > MAX_OUTPUT:
                    raise RuntimeError("Research phase output limit")
                sys.stdout.buffer.write(block); sys.stdout.buffer.flush()
        code = process.wait(timeout=max(1, seconds - (time.monotonic() - started)))
        print("RESEARCH phase result: " + json.dumps({"phase": label, "exit": code,
            "seconds": round(time.monotonic() - started, 3), "outputBytes": total,
            "maximumObservedOwnedRSSBytes": peak}), flush=True)
        if code:
            raise RuntimeError("Research phase failed: " + label)
    finally:
        selector.close()
        process.stdout.close()
        stop_owned(process)


def commands(root, scratch, ios_sdk, major, mac_sdk=None, arch="arm64"):
    sources = [str(root / source) for source in SOURCES]
    ios = ["xcrun", "--sdk", "iphoneos", "swiftc", "-swift-version", "5", "-parse-as-library",
           "-typecheck", "-sdk", ios_sdk, "-target", "arm64-apple-ios26.0",
           "-module-cache-path", str(scratch / "modules")] + sources + [
           str(root / "Takupoke/PDFRecoveryRecognition.swift"),
           str(root / "tests/research/NativeDocumentHierarchyDomainStubs.swift")]
    result = [("actual iPhone SDK adapter typecheck", ios, 300)]
    if major == 26:
        if mac_sdk is None or arch not in ("arm64", "x86_64"):
            raise ValueError("Native probe requires its actual macOS SDK/architecture")
        native = ["xcrun", "--sdk", "macosx", "swiftc", "-swift-version", "5", "-parse-as-library",
                  "-sdk", mac_sdk, "-target", arch + "-apple-macos26.0", "-module-cache-path",
                  str(scratch / "modules")] + sources + [str(root / "tests/research/NativeDocumentHierarchyProbe.swift"),
                  "-o", str(scratch / "native-hierarchy-probe")]
        result += [("actual macOS26 shared production capture compile", native, 300),
                   ("two independent native Vision correspondence controls", [str(scratch / "native-hierarchy-probe")], 180)]
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdk-major", type=int, choices=(26, 27), required=True)
    args = parser.parse_args()
    actual_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    identity(os.environ, actual_head)
    if sys.platform != "darwin":
        raise ValueError("Actual Apple SDK runner required; no stub SDK substitute")
    sdk_version = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], text=True).strip()
    if sdk_version.split(".")[0] != str(args.sdk_major):
        raise ValueError("Requested iPhone SDK unavailable: " + sdk_version)
    ios_sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    mac_sdk = None
    if args.sdk_major == 26:
        mac_version = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-version"], text=True).strip()
        os_version = subprocess.check_output(["sw_vers", "-productVersion"], text=True).strip()
        if mac_version.split(".")[0] != "26" or os_version.split(".")[0] != "26":
            raise ValueError("Actual macOS26 SDK and runtime required")
        mac_sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
    print("RESEARCH identity: " + json.dumps({"sha": actual_head, "runID": os.environ["GITHUB_RUN_ID"],
        "attempt": 1, "iPhoneSDK": sdk_version, "deploymentTarget": "iOS26.0",
        "unrelatedDomainStubsForUIKitTypecheck": True, "nativeProbeCases": 2 if args.sdk_major == 26 else 0,
        "systemVisionServiceRSS": "UNASSESSED", "semanticQuality": "UNASSESSED"}), flush=True)
    previous = {}; scratch = None
    def interrupted(signum, _frame):
        raise SystemExit(128 + signum)
    try:
        for sig in (signal.SIGINT, signal.SIGTERM):
            previous[sig] = signal.signal(sig, interrupted)
        with tempfile.TemporaryDirectory(prefix="takupoke-native-hierarchy-") as directory:
            scratch = Path(directory)
            for label, command, seconds in commands(ROOT, scratch, ios_sdk, args.sdk_major, mac_sdk, platform.machine()):
                phase(label, command, seconds=seconds, scratch=scratch)
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
        removed = scratch is None or not scratch.exists()
        print("RESEARCH cleanup: " + json.dumps({"ownedScratchRemoved": removed,
            "noArtifactsOrSharedCache": True}), flush=True)


if __name__ == "__main__":
    main()
