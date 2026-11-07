"""Align CLI and GUI Xcode selection before preparing a disposable macOS job."""
import os
from pathlib import Path
import re
import subprocess


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true" or os.environ.get("RUNNER_OS") != "macOS":
        raise SystemExit("Xcode system selection is restricted to macOS Actions")
    selected = Path(os.environ.get("DEVELOPER_DIR", ""))
    if (not selected.is_absolute() or selected.name != "Developer"
            or selected.parent.name != "Contents"
            or not re.fullmatch(r"Xcode_[0-9]+(?:\.[0-9]+){1,2}\.app", selected.parent.parent.name)
            or not selected.is_dir()):
        raise SystemExit("Require an explicit installed Xcode developer directory")
    expected = selected.resolve(strict=True)
    global_environment = dict(os.environ)
    global_environment.pop("DEVELOPER_DIR", None)

    def global_path():
        result = subprocess.run(["xcode-select", "--print-path"], env=global_environment,
                                capture_output=True, text=True, timeout=10)
        if result.returncode != 0:
            return None
        path = Path(result.stdout.strip())
        return path.resolve(strict=True) if path.is_absolute() and path.is_dir() else None

    try:
        before = global_path()
        subprocess.run(["sudo", "-n", "xcode-select", "--switch", str(selected)],
                       check=True, capture_output=True, text=True, timeout=30)
        if global_path() != expected:
            raise SystemExit("System Xcode does not match the selected developer directory")
    except (OSError, subprocess.SubprocessError):
        raise SystemExit("Failed to select and verify the system Xcode") from None
    previous = before.parent.parent.name if before is not None else "unknown"
    if not re.fullmatch(r"Xcode_[A-Za-z0-9_.]+\.app", previous):
        previous = "unknown"
    print("TAKUPOKE_XCODE_SELECTION previous=" + previous + " selected="
          + selected.parent.parent.name + " confirmed=true", flush=True)


if __name__ == "__main__":
    main()
