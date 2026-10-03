#!/usr/bin/env python3
"""Build the separately loaded iOS 27 runtime using the pinned Apple package."""
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile


def main():
    if os.environ.get("PLATFORM_NAME") != "iphoneos":
        return
    version = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], text=True).strip()
    if int(version.split(".")[0]) < 27:
        return
    sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], text=True).strip()
    host_sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
    destination = Path(os.environ["BUILT_PRODUCTS_DIR"]) / os.environ["FRAMEWORKS_FOLDER_PATH"] / "CoreAIRecoveryRuntime.framework"
    destination.parent.mkdir(parents=True, exist_ok=True)
    source = Path(os.environ["SRCROOT"]) / "Vendor/CoreAIRecoveryRuntime"
    with tempfile.TemporaryDirectory(prefix="takupoke-coreai-", dir=os.environ["TARGET_TEMP_DIR"]) as temporary:
        owned = Path(temporary)
        package = owned / "package"
        shutil.copytree(source, package, ignore=shutil.ignore_patterns(".build", ".swiftpm"))
        command = ["xcrun", "--sdk", "macosx", "swift", "build", "--package-path", str(package), "--scratch-path", str(owned / "build"),
                   "--configuration", "release", "--product", "CoreAIRecoveryRuntime", "--disable-automatic-resolution",
                   "--triple", "arm64-apple-ios27.0", "--sdk", sdk]
        # Package manifests execute on macOS, even when the product targets iOS.
        # Xcode's build-phase SDKROOT must not give the host compiler an iOS SDK.
        environment = dict(os.environ, SDKROOT=host_sdk, IPHONEOS_DEPLOYMENT_TARGET="27.0")
        environment.pop("SWIFTC_PASS_SDKROOT", None)
        subprocess.run(command, env=environment, check=True)
        output = subprocess.check_output(command + ["--show-bin-path"], env=environment, text=True).strip()
        library = Path(output) / "libCoreAIRecoveryRuntime.dylib"
        if not library.is_file():
            raise ValueError("Core AI runtime was not built")
        prepared = owned / "CoreAIRecoveryRuntime.framework"
        prepared.mkdir()
        executable = prepared / "CoreAIRecoveryRuntime"
        shutil.copy2(library, executable)
        subprocess.run(["xcrun", "install_name_tool", "-id", "@rpath/CoreAIRecoveryRuntime.framework/CoreAIRecoveryRuntime", str(executable)], check=True)
        info = {"CFBundleExecutable": "CoreAIRecoveryRuntime", "CFBundleIdentifier": "jp.n624.takupoke.coreai-runtime",
                "CFBundleName": "CoreAIRecoveryRuntime", "CFBundlePackageType": "FMWK", "CFBundleShortVersionString": "1.0",
                "CFBundleVersion": "1", "MinimumOSVersion": "27.0", "CFBundleSupportedPlatforms": ["iPhoneOS"]}
        (prepared / "Info.plist").write_bytes(plistlib.dumps(info))
        # SwiftPM's generated Bundle.module accessor also looks beside Bundle.main.
        # Keep the bundles there after the temporary build directory is removed;
        # the dylib's framework directory alone does not satisfy that lookup.
        app_resources = destination.parent.parent
        for resource in Path(output).glob("*.bundle"):
            shutil.copytree(resource, prepared / resource.name)
            installed_resource = app_resources / resource.name
            if installed_resource.exists():
                shutil.rmtree(installed_resource)
            shutil.copytree(resource, installed_resource)
        if os.environ.get("CODE_SIGNING_ALLOWED") != "NO":
            subprocess.run(["/usr/bin/codesign", "--force", "--sign", os.environ.get("EXPANDED_CODE_SIGN_IDENTITY") or "-",
                            "--timestamp=none", str(prepared)], check=True)
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(prepared, destination)


if __name__ == "__main__":
    main()
