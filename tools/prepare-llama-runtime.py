#!/usr/bin/env python3
"""Embed the pinned official device runtime; models are never bundled here."""
import hashlib
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tempfile
import urllib.request
import zipfile

URL = "https://github.com/ggml-org/llama.cpp/releases/download/b11371/llama-b11371-xcframework.zip"
SHA256 = "328b0e9d20b8c18df19ccb9fb204200844c081a67ac59ec4a1faf3e50fd571c3"
SIZE = 61784599


def main():
    # Official b11371 contains a device slice and macOS slice, no iOS simulator.
    if os.environ.get("PLATFORM_NAME") != "iphoneos":
        return
    destination = Path(os.environ["BUILT_PRODUCTS_DIR"]) / os.environ["FRAMEWORKS_FOLDER_PATH"] / "llama.framework"
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="takupoke-llama-", dir=os.environ["TARGET_TEMP_DIR"]) as temporary:
        archive = Path(temporary) / "runtime.zip"
        digest = hashlib.sha256()
        total = 0
        with urllib.request.urlopen(URL, timeout=60) as response, archive.open("wb") as output:
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > SIZE:
                    raise ValueError("Runtime size mismatch")
                digest.update(chunk)
                output.write(chunk)
        if total != SIZE or digest.hexdigest() != SHA256:
            raise ValueError("Runtime checksum mismatch")
        prepared = Path(temporary) / "llama.framework"
        prefix = "build-apple/llama.xcframework/ios-arm64/llama.framework/"
        with zipfile.ZipFile(archive) as source:
            for member in source.infolist():
                if not member.filename.startswith(prefix):
                    continue
                relative = PurePosixPath(member.filename[len(prefix):])
                if relative.is_absolute() or ".." in relative.parts or member.file_size > 128 * 1024 * 1024:
                    raise ValueError("Invalid runtime member")
                # The official iOS framework uses regular files, unlike its macOS slice.
                if (member.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError("Unexpected runtime symlink")
                target = prepared.joinpath(*relative.parts)
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with source.open(member) as input_file, target.open("wb") as output:
                        shutil.copyfileobj(input_file, output)
        if not (prepared / "llama").is_file() or not (prepared / "Info.plist").is_file():
            raise ValueError("Missing runtime framework")
        (prepared / "llama").chmod(0o755)
        if os.environ.get("CODE_SIGNING_ALLOWED") != "NO":
            identity = os.environ.get("EXPANDED_CODE_SIGN_IDENTITY") or "-"
            subprocess.run(["/usr/bin/codesign", "--force", "--sign", identity, "--timestamp=none", str(prepared)], check=True)
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(prepared, destination)


if __name__ == "__main__":
    main()
