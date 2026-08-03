"""Emit ACE static-safety warnings and a JSON report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


TESTS = Path(__file__).resolve().parent
PYTHON = TESTS / "python"
import sys

sys.path.insert(0, str(PYTHON))

from ace_static.annotations import findings_to_report, github_annotation  # noqa: E402
from ace_static.allowlist import apply_allowlist  # noqa: E402
from ace_static.namespace import find_mutable_filter_aliases  # noqa: E402
from ace_static.scanner import scan_repo  # noqa: E402


REPO = TESTS.parent
ALLOWLIST = REPO / "tests" / "fixtures" / "static_allowlist.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default="static_safety_report.json")
    args = parser.parse_args()

    try:
        findings = apply_allowlist(scan_repo(REPO), ALLOWLIST)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    sources = {
        path.relative_to(REPO).as_posix(): path.read_text(encoding="utf-8", errors="replace")
        for path in (REPO / "lua").rglob("*.lua")
    }
    filter_aliases = find_mutable_filter_aliases(sources)
    if filter_aliases:
        raise SystemExit(f"Caller-owned mutable filter aliases: {filter_aliases}")
    report = findings_to_report(findings)
    (REPO / args.report).write_text(json.dumps(report, indent=2), encoding="utf-8")

    for finding in findings:
        print(github_annotation(finding))

    print(f"ACE static-safety warnings: {len(findings)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
