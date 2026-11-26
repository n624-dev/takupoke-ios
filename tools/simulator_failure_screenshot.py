"""Capture one screenshot of an owned, fictional CI simulator before cleanup."""
import base64
import hashlib
from pathlib import Path
import re
import subprocess
import sys
import tempfile


DEVICE_ID = re.compile(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", re.IGNORECASE | re.ASCII)
MAX_IMAGE_BYTES = 2 * 1024 * 1024
PNG_START = b"\x89PNG\r\n\x1a\n"
PNG_END = b"\0\0\0\0IEND\xaeB`\x82"


def read_image(path):
    if path.is_symlink() or not path.is_file():
        return b""
    with path.open("rb") as stream:
        return stream.read(MAX_IMAGE_BYTES + 1)


def valid_png(data):
    return len(data) <= MAX_IMAGE_BYTES and data.startswith(PNG_START) and data.endswith(PNG_END)


def capture(simulator, scratch):
    if not DEVICE_ID.fullmatch(simulator):
        return
    try:
        with tempfile.TemporaryDirectory(prefix="failure-screen-", dir=scratch) as directory:
            path = Path(directory) / "screen.png"
            result = subprocess.run(["xcrun", "simctl", "io", simulator, "screenshot", str(path)],
                                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
            if result.returncode != 0:
                print(f"TAKUPOKE_SIMULATOR_FAILURE_SCREEN unavailable exit={result.returncode}", flush=True)
                return
            data = read_image(path)
            if not data:
                print("TAKUPOKE_SIMULATOR_FAILURE_SCREEN missing-image", flush=True)
                return
            if not valid_png(data):
                reason = "too-large" if len(data) > MAX_IMAGE_BYTES else "invalid-png"
                print(f"TAKUPOKE_SIMULATOR_FAILURE_SCREEN normalize reason={reason}", flush=True)
                normalized = path.with_name("bounded.png")
                conversion = subprocess.run(["sips", "-s", "format", "png", "-Z", "1024", str(path),
                                             "--out", str(normalized)], stdout=subprocess.DEVNULL,
                                            stderr=subprocess.DEVNULL, timeout=5)
                data = read_image(normalized) if conversion.returncode == 0 else b""
    except subprocess.TimeoutExpired:
        print("TAKUPOKE_SIMULATOR_FAILURE_SCREEN timeout", flush=True)
        return
    except OSError:
        print("TAKUPOKE_SIMULATOR_FAILURE_SCREEN unavailable", flush=True)
        return
    if not valid_png(data):
        print("TAKUPOKE_SIMULATOR_FAILURE_SCREEN invalid-or-too-large", flush=True)
        return

    name = "simulator-failure"
    digest = hashlib.sha256(data).hexdigest()
    encoded = base64.b64encode(data).decode("ascii")
    chunk_size = 6000
    print(f"TAKUPOKE_UI_IMAGE BEGIN {name} {digest} {len(data)}", flush=True)
    for index, offset in enumerate(range(0, len(encoded), chunk_size)):
        print(f"TAKUPOKE_UI_IMAGE DATA {name} {index} {encoded[offset:offset + chunk_size]}", flush=True)
    print(f"TAKUPOKE_UI_IMAGE END {name} {(len(encoded) + chunk_size - 1) // chunk_size}", flush=True)


if __name__ == "__main__":
    capture(sys.argv[1], Path(sys.argv[2]))
