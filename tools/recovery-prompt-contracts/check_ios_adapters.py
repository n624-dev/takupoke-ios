#!/usr/bin/env python3
"""Check actual iOS instruction resources; no model or school-data access."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHA = "c24039ae4317a433a14f01697d77813424a3a1c20a70327189964b2fc60bb188"
SIZE = 2939
ASSETS = (
    "tools/recovery-prompt-contracts/prompts/field-extraction-v4.txt",
    "Takupoke/RecoveryPromptResources/field-extraction-v4.txt",
    "Vendor/CoreAIRecoveryRuntime/Sources/CoreAIRecoveryRuntime/Resources/field-extraction-v4.txt",
)


def verify(path):
    data = path.read_bytes()
    if len(data) != SIZE or hashlib.sha256(data).hexdigest() != SHA:
        raise ValueError("Unapproved fieldExtraction instruction: " + str(path))
    data.decode("utf-8", errors="strict")
    return {"path": str(path), "bytes": len(data), "sha256": SHA}


def check(root=ROOT, app=None):
    root = Path(root)
    verified = [verify(root / path) for path in ASSETS]
    app_loader = (root / "Takupoke/RecoveryPromptCatalog.swift").read_bytes()
    runtime_loader = (root / "Vendor/CoreAIRecoveryRuntime/Sources/CoreAIRecoveryRuntime/RecoveryPromptCatalog.swift").read_bytes()
    if app_loader != runtime_loader:
        raise ValueError("App and separately built CoreAI loaders differ")
    if app is not None:
        app = Path(app)
        if not (app / "Takupoke").is_file():
            raise ValueError("Missing compiled iPhone app")
        verified.append(verify(app / "field-extraction-v4.txt"))
        bundles = list(app.glob("CoreAIRecoveryRuntime_CoreAIRecoveryRuntime.bundle"))
        if len(bundles) != 1:
            raise ValueError("Missing installed CoreAI SwiftPM resource bundle")
        verified.append(verify(bundles[0] / "field-extraction-v4.txt"))
        framework = app / "Frameworks/CoreAIRecoveryRuntime.framework/CoreAIRecoveryRuntime"
        if not framework.is_file():
            raise ValueError("Missing independently compiled CoreAI runtime")
    return {"promptVersion": 4, "resources": verified, "nativeInferenceCalls": 0,
            "scope": "Exact packaged instruction bytes; no model-quality claim"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    print(json.dumps(check(app=args.app), ensure_ascii=False))
