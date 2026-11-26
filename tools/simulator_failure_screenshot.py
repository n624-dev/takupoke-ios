"""Capture one screenshot of an owned, fictional CI simulator before cleanup."""
import base64
import binascii
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


def has_native_image(log):
    prefix = "TAKUPOKE_UI_IMAGE "
    header = re.compile(r"BEGIN simulator-failure ([0-9a-f]{64}) ([1-9][0-9]{0,6})")
    data_line = re.compile(r"DATA simulator-failure ([0-9]{1,3}) ([A-Za-z0-9+/=]{1,6000})")
    trailer = re.compile(r"END simulator-failure ([1-9][0-9]{0,2})")
    expected = None
    chunks = []
    maximum_chunks = 1 + MAX_IMAGE_BYTES * 4 // (3 * 6000)
    with log.open(encoding="utf-8", errors="replace") as stream:
        for line in stream:
            if not line.startswith(prefix):
                continue
            frame = line[len(prefix):].strip()
            if match := header.fullmatch(frame):
                expected, chunks = match.groups(), []
            elif expected is not None and (match := data_line.fullmatch(frame)):
                if int(match[1]) != len(chunks) or len(chunks) >= maximum_chunks:
                    expected = None
                else:
                    chunks.append(match[2])
            elif expected is not None and (match := trailer.fullmatch(frame)):
                if int(match[1]) == len(chunks):
                    try:
                        data = base64.b64decode("".join(chunks), validate=True)
                    except binascii.Error:
                        return False
                    if len(data) == int(expected[1]) and valid_png(data) and hashlib.sha256(data).hexdigest() == expected[0]:
                        return True
                expected = None
    return False


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
    if sys.argv[1] == "--verify-log":
        try:
            sys.exit(0 if has_native_image(Path(sys.argv[2])) else 1)
        except OSError:
            sys.exit(1)
    else:
        capture(sys.argv[1], Path(sys.argv[2]))
