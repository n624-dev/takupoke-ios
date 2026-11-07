"""Prepare exact iOS 26.5 on the shipping toolchain in a disposable hosted runner."""
import argparse, json, os, re, shutil, subprocess, tempfile, uuid
from contextlib import contextmanager
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
mode = parser.add_mutually_exclusive_group()
mode.add_argument("--hold-export", action="store_true")
mode.add_argument("--cleanup-export", action="store_true")
args = parser.parse_args()
OWNER = b"takupoke-ios26-runtime-export-v1\n"
IOS26_BUILD = "23F77"
IOS26_RUNTIME = "com.apple.CoreSimulator.SimRuntime.iOS-26-5"

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

def runtime_images(stage):
    result = subprocess.run(["xcrun", "simctl", "runtime", "list", "-j"],
                            check=True, capture_output=True, text=True, timeout=30)
    images = json.loads(result.stdout)
    print("TAKUPOKE_IOS26_RUNTIME_IMAGES stage=" + stage + " " +
          json.dumps(images, separators=(",", ":")), flush=True)
    return images

def target_images(images):
    return {key: item for key, item in images.items() if item.get("runtimeIdentifier") == IOS26_RUNTIME}

def exact_image(key, image):
    return (str(uuid.UUID(key)).upper() == key and image.get("identifier") == key
            and image.get("runtimeIdentifier") == IOS26_RUNTIME and image.get("build") == IOS26_BUILD
            and image.get("version") == "26.5"
            and image.get("platformIdentifier") == "com.apple.platform.iphonesimulator")

def owned_unusable(key, image, asset_path):
    return (exact_image(key, image) and image.get("path") == str(asset_path)
            and image.get("deletable") is True and image.get("state") == "Unusable"
            and image.get("unusableSubstate") == "Cryptex Mount Preferred")

def same_ready(key, image, original):
    return (exact_image(key, image) and image.get("state") == "Ready"
            and image.get("path") == original["path"])

versions, registered, pinned = available26()
if not versions:
    if registered:
        raise SystemExit("Registered iOS 26 runtime is unavailable; refusing replacement")
    with export_directory() as owned:
        before = runtime_images("before-download")
        if target_images(before):
            raise SystemExit("Refusing replacement of a pre-existing iOS 26.5 runtime image")
        asset_root = Path("/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime")
        existing_assets = set(asset_root.glob("*.asset"))
        subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", IOS26_BUILD,
                        "-architectureVariant", "arm64",
                        "-exportPath", owned], check=True, timeout=600)
        downloaded = target_images(runtime_images("after-download"))
        if len(downloaded) != 1:
            raise SystemExit("Download must introduce one unambiguous owned runtime image")
        download_id, download_image = next(iter(downloaded.items()))
        asset_path = Path(download_image.get("path", ""))
        if (download_id in before or not exact_image(download_id, download_image)
                or asset_path.name != "AssetData" or asset_path.parent.parent != asset_root
                or not re.fullmatch(r"[0-9a-f]{40}\.asset", asset_path.parent.name)
                or asset_path.parent in existing_assets):
            raise SystemExit("Refusing an unowned downloaded runtime image")
        # The download can register a MobileAsset runtime. Import our own export
        # once so testing uses the supported local registration path (N220).
        images = list(Path(owned).glob("*.exportedBundle")) + list(Path(owned).glob("*.dmg"))
        if len(images) != 1 or images[0].is_symlink() or not (
                images[0].is_dir() if images[0].suffix == ".exportedBundle" else images[0].is_file()):
            raise SystemExit("Comparison requires one owned exported runtime bundle or image")
        subprocess.run(["xcodebuild", "-importPlatform", str(images[0])], check=True, timeout=180)
        imported = target_images(runtime_images("after-import"))
        local = {key: item for key, item in imported.items() if item.get("state") == "Ready"
                 and item.get("path") == "/Library/Developer/CoreSimulator/Cryptex/Images/" + key}
        if len(local) != 1:
            raise SystemExit("Import must leave one ready local runtime image")
        local_id, local_image = next(iter(local.items()))
        if local_id in before or local_id == download_id or not exact_image(local_id, local_image):
            raise SystemExit("Refusing an ambiguous imported runtime image")
        duplicates = {key: item for key, item in imported.items() if key != local_id}
        if duplicates:
            duplicate = duplicates.get(download_id, {})
            if set(duplicates) != {download_id} or not owned_unusable(download_id, duplicate, asset_path):
                raise SystemExit("Refusing removal of an unknown or usable runtime image")
            removal = subprocess.run(["xcrun", "simctl", "runtime", "delete", download_id],
                                     capture_output=True, text=True, timeout=180)
            message = removal.stdout + removal.stderr
            print(message, end="", flush=True)
            if removal.returncode:
                # Apple explicitly reports this partial result and prescribes
                # one re-registration before removing the same owned asset.
                partial = (removal.returncode == 30
                    and "(domain=com.apple.CoreSimulator.simdiskimaged.SimDiskImageError, code=30):" in message
                    and "Removed the runtime, but did not reclaim its MobileAsset: " + str(asset_path) + "/" in message.splitlines()
                    and "Run 'xcrun simctl runtime scan-and-mount' to re-register the runtime, then delete it again." in message.splitlines())
                if not partial:
                    raise subprocess.CalledProcessError(removal.returncode, removal.args,
                                                        output=removal.stdout, stderr=removal.stderr)
                after_partial = target_images(runtime_images("after-partial-removal"))
                if set(after_partial) != {local_id} or not same_ready(local_id, after_partial[local_id], local_image):
                    raise SystemExit("Partial removal did not preserve the ready local image")
                subprocess.run(["xcrun", "simctl", "runtime", "scan-and-mount"], check=True, timeout=180)
                rescanned = target_images(runtime_images("after-owned-asset-rescan"))
                candidates = {key: item for key, item in rescanned.items() if key != local_id}
                if (len(candidates) != 1 or local_id not in rescanned
                        or not same_ready(local_id, rescanned[local_id], local_image)):
                    raise SystemExit("Rescan did not isolate the same owned asset and ready local image")
                recovered_id, recovered = next(iter(candidates.items()))
                if recovered_id in before or not owned_unusable(recovered_id, recovered, asset_path):
                    raise SystemExit("Refusing removal of an unowned re-registered runtime image")
                subprocess.run(["xcrun", "simctl", "runtime", "delete", recovered_id], check=True, timeout=180)
            remaining = target_images(runtime_images("after-owned-duplicate-removal"))
            if (set(remaining) != {local_id} or not same_ready(local_id, remaining[local_id], local_image)
                    or asset_path.exists()):
                raise SystemExit("Owned runtime duplicate removal did not preserve the ready local image")
        if asset_path.exists():
            raise SystemExit("The newly owned MobileAsset must be reclaimed before boot")
    versions, _, pinned = available26()
if not versions or max(versions) != (26, 5) or not pinned:
    raise SystemExit("Comparison requires one available iOS 26.5 runtime with exact build " + IOS26_BUILD)
print("Comparison runtime: iOS 26.5 (build " + IOS26_BUILD + ")")
