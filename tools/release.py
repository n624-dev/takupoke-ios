"""Build and validate AltStore metadata using only Python's standard library."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "distribution/config.json"
NOTES = ROOT / "distribution/release-notes.txt"
ICON = ROOT / "Takupoke/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
ASSETS = ("takupoke.ipa", "altstore-source.json", "icon.png", "release.json")


def read_config():
    return json.loads(CONFIG.read_text(encoding="utf-8"))


def validate_notes(notes):
    if not isinstance(notes, str) or not notes.strip():
        raise ValueError("Release notes must not be empty")
    return notes.strip()


def versions(config, run_number, run_attempt):
    # CFBundleVersion: first component <= 4 digits, subsequent components <= 2.
    if not 1 <= run_number <= 9999 or not 1 <= run_attempt <= 99:
        raise ValueError("Run number / attempt exceeds the supported version range")
    prefix = config["versionPrefix"]
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", prefix):
        raise ValueError("versionPrefix must contain major.minor")
    return f"{prefix}.{run_number}", f"{run_number}.{run_attempt}"


def tag_for(version, build):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Invalid version")
    if not re.fullmatch(r"[1-9][0-9]{0,3}\.[1-9][0-9]?", build):
        raise ValueError("Invalid build number")
    return f"v{version}-build.{build}"


def sha256(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inspect_ipa(ipa, config, version, build, commit):
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("A full commit SHA is required")
    tag_for(version, build)
    with zipfile.ZipFile(ipa) as archive:
        paths = archive.namelist()
        if len(paths) != len(set(paths)):
            raise ValueError("Duplicate ZIP entries")
        if any(p.startswith("/") or ".." in p.split("/") for p in paths):
            raise ValueError("Unsafe ZIP path")
        infos = [p for p in paths if re.fullmatch(r"Payload/[^/]+\.app/Info.plist", p)]
        if len(infos) != 1:
            raise ValueError("IPA must contain exactly one application")
        if any(".appex/" in p or "embedded.mobileprovision" in p or "_CodeSignature/" in p for p in paths):
            raise ValueError("Extensions and signed bundles require an updated permission policy")
        info = plistlib.loads(archive.read(infos[0]))
        required = {
            "CFBundleIdentifier": config["bundleIdentifier"],
            "CFBundleShortVersionString": version,
            "CFBundleVersion": build,
            "CFBundlePackageType": "APPL",
            "MinimumOSVersion": config["minOSVersion"],
            "TakupokeCommit": commit,
        }
        for key, expected in required.items():
            if info.get(key) != expected:
                raise ValueError(f"IPA metadata mismatch: {key}")
        if info.get("CFBundleSupportedPlatforms") != ["iPhoneOS"]:
            raise ValueError("An iPhone device build is required")
        if any(key.endswith("UsageDescription") for key in info):
            raise ValueError("Declare new privacy permissions in the Source before release")
        root = infos[0].removesuffix("Info.plist")
        executable = info.get("CFBundleExecutable", "")
        if not executable or "/" in executable:
            raise ValueError("Invalid executable name")
        with archive.open(root + executable) as stream:
            executable_bytes = stream.read()
            magic = executable_bytes[:4]
        if magic not in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"):
            raise ValueError("Missing Mach-O executable")
        if any(marker in executable_bytes for marker in (
            b"TAKUPOKE-PDF-FULL-ZIP-1", b"TAKUPOKE-PDF-FULL-JSON-1",
            "更新確認の診断をコピー".encode(), "全文診断をコピー".encode(),
        )):
            raise ValueError("Internal diagnostics must not be included in public builds")
        for policy in ("terms", "privacy"):
            policy_path = root + f"LegalDocuments/{policy}.txt"
            if policy_path not in paths or not archive.read(policy_path).strip():
                raise ValueError("Bundled legal documents are missing")
        privacy = plistlib.loads(archive.read(root + "PrivacyInfo.xcprivacy"))
        if privacy.get("NSPrivacyTracking") is not False:
            raise ValueError("Unexpected tracking declaration")
        if root + "Assets.car" not in paths:
            raise ValueError("Compiled asset catalog is missing")
    return info


def make_source(config, version, build, size, date, notes):
    base = f"https://github.com/{config['repository']}"
    download = f"{base}/releases/download/{tag_for(version, build)}"
    item = {
        "version": version,
        "buildVersion": build,
        "date": date,
        "localizedDescription": validate_notes(notes),
        "downloadURL": f"{download}/takupoke.ipa",
        "size": size,
        "minOSVersion": config["minOSVersion"],
    }
    return {
        "name": config["sourceName"],
        "identifier": config["sourceIdentifier"],
        "sourceURL": f"{base}/releases/latest/download/altstore-source.json",
        "subtitle": "たくポケの開発版を配布します",
        "description": config["description"],
        "website": base,
        "iconURL": f"{download}/icon.png",
        "tintColor": config["tintColor"],
        "apps": [{
            "name": config["name"],
            "bundleIdentifier": config["bundleIdentifier"],
            "developerName": config["developerName"],
            "localizedDescription": config["description"],
            "iconURL": f"{download}/icon.png",
            "tintColor": config["tintColor"],
            "category": "utilities",
            "versions": [item],
            "appPermissions": {"entitlements": [], "privacy": {}},
        }],
        "news": [],
    }


def write_json(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def generate(ipa, output, version, build, commit, config=None):
    config = config or read_config()
    ipa, output = Path(ipa), Path(output)
    if ipa.resolve() != (output / "takupoke.ipa").resolve():
        raise ValueError("IPA must be output/takupoke.ipa")
    inspect_ipa(ipa, config, version, build, commit)
    notes = validate_notes(NOTES.read_text(encoding="utf-8"))
    date = datetime.now(timezone.utc).isoformat(timespec="seconds")
    source = make_source(config, version, build, ipa.stat().st_size, date, notes)
    write_json(output / "altstore-source.json", source)
    (output / "icon.png").write_bytes(ICON.read_bytes())
    metadata = {
        "repository": config["repository"],
        "tag": tag_for(version, build),
        "version": version,
        "build": build,
        "commit": commit,
        "date": date,
        "releaseNotes": notes,
        "sha256": {name: sha256(output / name) for name in ASSETS if name != "release.json"},
    }
    write_json(output / "release.json", metadata)
    validate(output, config)
    return metadata


def validate(output, config=None):
    config = config or read_config()
    output = Path(output)
    if {p.name for p in output.iterdir()} != set(ASSETS):
        raise ValueError("Unexpected or missing release files")
    metadata = json.loads((output / "release.json").read_text(encoding="utf-8"))
    if metadata["repository"] != config["repository"]:
        raise ValueError("Wrong release repository")
    version, build = metadata["version"], metadata["build"]
    if metadata["tag"] != tag_for(version, build):
        raise ValueError("Wrong release tag")
    expected_hashes = {name: sha256(output / name) for name in ASSETS if name != "release.json"}
    if metadata["sha256"] != expected_hashes:
        raise ValueError("Release file checksum mismatch")
    inspect_ipa(output / "takupoke.ipa", config, version, build, metadata["commit"])
    actual = json.loads((output / "altstore-source.json").read_text(encoding="utf-8"))
    expected = make_source(config, version, build, (output / "takupoke.ipa").stat().st_size,
                           metadata["date"], validate_notes(metadata.get("releaseNotes")))
    if actual != expected:
        raise ValueError("Source does not match IPA / release metadata")
    if (output / "icon.png").read_bytes() != ICON.read_bytes():
        raise ValueError("Release icon does not match the app icon")
    return metadata


def main():
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    version_parser = commands.add_parser("version")
    version_parser.add_argument("--github-output", type=Path, required=True)
    generate_parser = commands.add_parser("generate")
    for name in ("ipa", "output", "version", "build", "commit"):
        generate_parser.add_argument(f"--{name}", required=True)
    validate_parser = commands.add_parser("validate")
    validate_parser.add_argument("--output", required=True)
    args = parser.parse_args()
    if args.command == "version":
        version, build = versions(read_config(), int(os.environ["GITHUB_RUN_NUMBER"]), int(os.environ["GITHUB_RUN_ATTEMPT"]))
        with args.github_output.open("a", encoding="utf-8") as stream:
            stream.write(f"version={version}\nbuild={build}\n")
    elif args.command == "generate":
        generate(args.ipa, args.output, args.version, args.build, args.commit)
    else:
        validate(args.output)


if __name__ == "__main__":
    main()
