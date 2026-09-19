#!/usr/bin/env python3
"""Regenerate synthetic expectations with an explicitly supplied, pinned reference.

No network access, workbook inputs, CLI invocation, or reference-tree writes.
"""

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys


REFERENCE_SHA256 = "7bbbbca774f40623ee6fbd9c227a68e8bd675ae3fcdf6a0415cfd67a00513f90"
REFERENCE_COMMIT = "ba3db92dddd8b453348e5a78b5d716a10ee72145"
FIXTURE = Path(__file__).resolve().parents[1] / "tests/fixtures/normalization.json"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", required=True, type=Path,
                        help="Local excel_to_class_schedule_csvs.py at the pinned revision")
    parser.add_argument("--check", action="store_true",
                        help="Compare without writing; fail if expectations differ")
    args = parser.parse_args()
    source = args.reference.resolve()
    if hashlib.sha256(source.read_bytes()).hexdigest() != REFERENCE_SHA256:
        parser.error("Reference checksum mismatch; review the source revision first")

    # The reference uses dataclasses, which require the module in sys.modules.
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("schedule_fixture_reference", source)
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)

    original = FIXTURE.read_text(encoding="utf-8")
    fixture = json.loads(original)
    fixture["reference"] = {
        "repository": "https://github.com/n624-dev/denpa-schedule-csv",
        "commit": REFERENCE_COMMIT,
        "file": "excel_to_class_schedule_csvs.py",
        "sha256": REFERENCE_SHA256,
    }
    for case in fixture["cases"]:
        headers, rows = module.extract_table_from_sheet_rows(case["sheetRows"])
        records = module.build_normalized_records(
            [dict(zip(headers, row)) for row in rows], headers,
            default_year=case["defaultYear"],
        )
        case["expectedRecords"] = records
    rendered = json.dumps(fixture, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if rendered != original:
            raise SystemExit("Synthetic expectations differ from the pinned reference")
    else:
        FIXTURE.write_text(rendered, encoding="utf-8")
    print(f"Verified {len(fixture['cases'])} synthetic cases against the pinned reference")


if __name__ == "__main__":
    main()
