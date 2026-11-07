"""Prepare exact iOS 26.5 on the shipping toolchain in a disposable hosted runner."""
import argparse, json, os, re, shutil, subprocess, tempfile, time, uuid
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

def runtime_images(stage, timeout=30):
    result = subprocess.run(["xcrun", "simctl", "runtime", "list", "-j"],
                            check=True, capture_output=True, text=True, timeout=timeout)
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

def known_preference_state(image):
    return (image.get("state") == "Ready" or image.get("state") == "Unusable"
            and image.get("unusableSubstate") == "Cryptex Mount Preferred")

def require_no_started_devices():
    result = subprocess.run(["xcrun", "simctl", "list", "devices", "-j"],
                            check=True, capture_output=True, text=True, timeout=30)
    devices = json.loads(result.stdout)["devices"]
    if any(device.get("state") != "Shutdown" for group in devices.values() for device in group):
        raise SystemExit("Refusing runtime removal while a device is started or unknown")

def owned_asset_image(key, image, asset_path):
    return (exact_image(key, image) and image.get("path") == str(asset_path)
            and image.get("deletable") is True and known_preference_state(image))

def delete_owned_asset_image(key, asset_path):
    removal = subprocess.run(["xcrun", "simctl", "runtime", "delete", key],
                             capture_output=True, text=True, timeout=180)
    print(removal.stdout + removal.stderr, end="", flush=True)
    if removal.returncode:
        # Preserve targeted host evidence if Apple's prescribed cleanup fails.
        # This read-only diagnostic never changes cleanup acceptance.
        asset_hash = asset_path.parent.name.removesuffix(".asset")
        predicate = ('(process == "simdiskimaged" OR process == "mobileassetd") AND '
                     '(eventMessage CONTAINS "' + asset_hash + '" OR '
                     'eventMessage CONTAINS "reclaim" OR eventMessage CONTAINS "purge")')
        try:
            with tempfile.TemporaryFile() as output:
                diagnostic = subprocess.run(["/usr/bin/log", "show", "--last", "2m", "--style", "compact",
                                             "--predicate", predicate], stdout=output, stderr=subprocess.STDOUT,
                                            timeout=15)
                output.seek(0)
                raw = output.read(32769)
                print("TAKUPOKE_IOS26_ASSET_FAILURE " + json.dumps({"exit": diagnostic.returncode,
                      "truncated": len(raw) > 32768, "text": raw[:32768].decode("utf-8", errors="replace")}), flush=True)
        except (OSError, subprocess.TimeoutExpired) as error:
            print("TAKUPOKE_IOS26_ASSET_FAILURE " + json.dumps({"unknown": type(error).__name__}), flush=True)
    return removal

def reclaim_owned_asset(before, download_id, download_image, asset_path):
    if not owned_asset_image(download_id, download_image, asset_path):
        raise SystemExit("Refusing removal of an unowned or unknown runtime image")
    require_no_started_devices()
    removal = delete_owned_asset_image(download_id, asset_path)
    message = removal.stdout + removal.stderr
    if removal.returncode:
        partial = (removal.returncode == 30
            and "(domain=com.apple.CoreSimulator.simdiskimaged.SimDiskImageError, code=30):" in message
            and "Removed the runtime, but did not reclaim its MobileAsset: " + str(asset_path) + "/" in message.splitlines()
            and "Run 'xcrun simctl runtime scan-and-mount' to re-register the runtime, then delete it again." in message.splitlines())
        if not partial:
            raise subprocess.CalledProcessError(removal.returncode, removal.args,
                                                output=removal.stdout, stderr=removal.stderr)
        if target_images(runtime_images("after-partial-removal")):
            raise SystemExit("Partial removal left an unexpected target runtime registration")
        subprocess.run(["xcrun", "simctl", "runtime", "scan-and-mount"], check=True, timeout=180)
        scan_deadline = time.monotonic() + 30
        while True:
            remaining_seconds = scan_deadline - time.monotonic()
            if remaining_seconds <= 0:
                raise SystemExit("Owned asset re-registration did not complete within 30 seconds")
            candidates = target_images(runtime_images("after-owned-asset-rescan", timeout=remaining_seconds))
            if time.monotonic() > scan_deadline:
                raise SystemExit("Owned asset re-registration exceeded its observation deadline")
            if len(candidates) > 1:
                raise SystemExit("Rescan introduced ambiguous runtime images")
            present = asset_path.exists()
            print("TAKUPOKE_IOS26_OWNED_ASSET present=" + str(present).lower(), flush=True)
            if not candidates:
                if not present:
                    break
                time.sleep(min(1, max(0, scan_deadline - time.monotonic())))
                continue
            recovered_id, recovered = next(iter(candidates.items()))
            if recovered_id in before or not owned_asset_image(recovered_id, recovered, asset_path):
                raise SystemExit("Refusing removal of an unowned re-registered runtime image")
            require_no_started_devices()
            delete_owned_asset_image(recovered_id, asset_path).check_returncode()
            break
    if target_images(runtime_images("after-owned-asset-removal")) or asset_path.exists():
        raise SystemExit("The newly owned MobileAsset must be fully reclaimed before import")

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
                        "-architectureVariant", "arm64", "-exportPath", owned], check=True, timeout=600)
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
        images = list(Path(owned).glob("*.exportedBundle")) + list(Path(owned).glob("*.dmg"))
        if len(images) != 1 or images[0].is_symlink() or not (
                images[0].is_dir() if images[0].suffix == ".exportedBundle" else images[0].is_file()):
            raise SystemExit("Comparison requires one owned exported runtime bundle or image")
        # Keep the portable export, and remove our unused MobileAsset BEFORE
        # importing. This avoids creating the duplicate registrations (N226).
        reclaim_owned_asset(before, download_id, download_image, asset_path)
        subprocess.run(["xcodebuild", "-importPlatform", str(images[0])], check=True, timeout=180)
        imported = target_images(runtime_images("after-import"))
        if len(imported) != 1:
            raise SystemExit("Import must leave one unambiguous local runtime image")
        local_id, local_image = next(iter(imported.items()))
        if (local_id in before or local_id == download_id or not exact_image(local_id, local_image)
                or local_image.get("state") != "Ready"
                or local_image.get("path") != "/Library/Developer/CoreSimulator/Cryptex/Images/" + local_id
                or asset_path.exists()):
            raise SystemExit("Import did not preserve one ready local image without the owned MobileAsset")
    versions, _, pinned = available26()
if not versions or max(versions) != (26, 5) or not pinned:
    raise SystemExit("Comparison requires one available iOS 26.5 runtime with exact build " + IOS26_BUILD)
print("Comparison runtime: iOS 26.5 (build " + IOS26_BUILD + ")")
