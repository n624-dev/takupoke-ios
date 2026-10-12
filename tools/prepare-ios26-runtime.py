"""Prepare exact iOS 26.5 on the shipping toolchain in a disposable hosted runner."""
import json, os, subprocess, tempfile
from pathlib import Path
actual_sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"],
                            check=True, capture_output=True, text=True, timeout=30).stdout.strip()
if actual_sdk != "27.0":
    raise SystemExit("iOS 26.5 comparison requires shipping SDK 27.0")

def available26():
    result = subprocess.run(["xcrun", "simctl", "list", "runtimes", "-j"],
                            check=True, capture_output=True, text=True, timeout=30)
    registered = [r for r in json.loads(result.stdout)["runtimes"]
            if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
            and r["version"].split(".")[0] == "26"]
    return [tuple(map(int, r["version"].split("."))) for r in registered
            if r.get("isAvailable")], bool(registered)
versions, registered = available26()
if not versions:
    if registered:
        raise SystemExit("Registered iOS 26 runtime is unavailable; refusing replacement")
    with tempfile.TemporaryDirectory(prefix="takupoke-runtime-owned-", dir=os.environ["RUNNER_TEMP"]) as owned:
        subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", "26.5",
                        "-exportPath", owned], check=True, timeout=600)
        versions, _ = available26()
        if not versions:
            images = list(Path(owned).glob("*.dmg"))
            if len(images) != 1 or images[0].is_symlink() or not images[0].is_file():
                raise SystemExit("Comparison requires installed runtime or one exported image")
            subprocess.run(["xcodebuild", "-importPlatform", str(images[0])], check=True, timeout=180)
    versions, _ = available26()
if not versions or max(versions) != (26, 5):
    raise SystemExit("Comparison requires unchanged iOS 26.5 runtime")
print("Comparison runtime: iOS 26.5")
