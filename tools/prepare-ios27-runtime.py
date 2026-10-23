"""Prepare exact iOS 27.0 on the shipping toolchain in a disposable hosted runner."""
import json, os, subprocess, tempfile
from pathlib import Path
actual_sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                            check=True, capture_output=True, text=True, timeout=30).stdout.strip()
if actual_sdk != "27.0":
    raise SystemExit("iOS 27.0 comparison requires shipping SDK 27.0")

def available27():
    result = subprocess.run(["xcrun", "simctl", "list", "runtimes", "-j"],
                            check=True, capture_output=True, text=True, timeout=30)
    registered = [r for r in json.loads(result.stdout)["runtimes"]
            if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
            and r["version"] == "27.0"]
    return [tuple(map(int, r["version"].split("."))) for r in registered
            if r.get("isAvailable")], bool(registered)
versions, registered = available27()
if not versions:
    if registered:
        raise SystemExit("Registered iOS 27 runtime is unavailable; refusing replacement")
    with tempfile.TemporaryDirectory(prefix="takupoke-runtime-owned-", dir=os.environ["RUNNER_TEMP"]) as owned:
        subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", "27.0",
                        "-exportPath", owned], check=True, timeout=600)
        versions, _ = available27()
        if not versions:
            images = list(Path(owned).glob("*.dmg"))
            if len(images) != 1 or images[0].is_symlink() or not images[0].is_file():
                raise SystemExit("Comparison requires installed runtime or one exported image")
            subprocess.run(["xcodebuild", "-importPlatform", str(images[0])], check=True, timeout=180)
    versions, _ = available27()
if not versions or max(versions) != (27, 0):
    raise SystemExit("Comparison requires unchanged iOS 27.0 runtime")
print("Comparison runtime: iOS 27.0")
