"""Prepare exact iOS 26.5 on the shipping toolchain in a disposable hosted runner."""
import argparse, json, os, shutil, subprocess, tempfile
from contextlib import contextmanager
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
mode = parser.add_mutually_exclusive_group()
mode.add_argument("--hold-export", action="store_true")
mode.add_argument("--cleanup-export", action="store_true")
args = parser.parse_args()
OWNER = b"takupoke-ios26-runtime-export-v1\n"
IOS26_BUILD = "23F77"

def owned_export():
    return Path(os.environ["RUNNER_TEMP"]).resolve(strict=True) / "takupoke-ios26-runtime-export-owned"

def cleanup_export():
    owned = owned_export()
    if owned.is_symlink():
        raise SystemExit("Refusing symlink runtime export")
    if not owned.exists():
        return
    marker = owned / ".takupoke-owner"
    if not owned.is_dir() or marker.is_symlink() or not marker.is_file() or marker.read_bytes() != OWNER:
        raise SystemExit("Refusing unowned runtime export")
    shutil.rmtree(owned)

@contextmanager
def export_directory():
    if args.hold_export:
        # CoreSimulator may still use an exported image after registration.
        # Keep its backing files through all tests and device cleanup in this job.
        owned = owned_export()
        owned.mkdir(mode=0o700)
        (owned / ".takupoke-owner").write_bytes(OWNER)
        yield str(owned)
    else:
        with tempfile.TemporaryDirectory(prefix="takupoke-runtime-owned-", dir=os.environ["RUNNER_TEMP"]) as owned:
            yield owned

if args.cleanup_export:
    cleanup_export()
    raise SystemExit(0)

expected_sdk = os.environ.get("TKPK_EXPECTED_IOS_SDK", "27.0")
if expected_sdk not in ("27.0", "27.1", "27.2"):
    raise SystemExit("Unsupported explicit comparison SDK")
actual_sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                            check=True, capture_output=True, text=True, timeout=30).stdout.strip()
if actual_sdk != expected_sdk:
    raise SystemExit("iOS 26.5 comparison requires the exact requested SDK " + expected_sdk)

def available26():
    result = subprocess.run(["xcrun", "simctl", "list", "runtimes", "-j"],
                            check=True, capture_output=True, text=True, timeout=30)
    registered = [r for r in json.loads(result.stdout)["runtimes"]
            if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
            and r["version"].split(".")[0] == "26"]
    available = [r for r in registered if r.get("isAvailable")]
    exact = [r for r in available if r["version"] == "26.5"]
    pinned = len(exact) == 1 and exact[0].get("buildversion") == IOS26_BUILD
    return [tuple(map(int, r["version"].split("."))) for r in available], bool(registered), pinned
versions, registered, pinned = available26()
if not versions:
    if registered:
        raise SystemExit("Registered iOS 26 runtime is unavailable; refusing replacement")
    with export_directory() as owned:
        subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", IOS26_BUILD,
                        "-architectureVariant", "arm64",
                        "-exportPath", owned], check=True, timeout=600)
        versions, _, pinned = available26()
        if not versions:
            images = list(Path(owned).glob("*.dmg"))
            if len(images) != 1 or images[0].is_symlink() or not images[0].is_file():
                raise SystemExit("Comparison requires installed runtime or one exported image")
            subprocess.run(["xcodebuild", "-importPlatform", str(images[0])], check=True, timeout=180)
    versions, _, pinned = available26()
if not versions or max(versions) != (26, 5) or not pinned:
    raise SystemExit("Comparison requires one available iOS 26.5 runtime with exact build " + IOS26_BUILD)
print("Comparison runtime: iOS 26.5 (build " + IOS26_BUILD + ")")
