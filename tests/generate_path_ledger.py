"""Generate and validate the offline ACE runtime-surface ledger."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

TESTS = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS / "python"))

from ace_static.path_ledger import build_ledger, validate_ledger  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="tests/fixtures/path_surface_manifest.json")
    parser.add_argument("--prior")
    args = parser.parse_args(argv)
    repo = TESTS.parent
    prior = json.loads((repo / args.prior).read_text(encoding="utf-8")) if args.prior else None
    ledger = build_ledger(repo, prior)
    validate_ledger(ledger)
    output = repo / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(ledger, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {ledger['summary']['surface_count']} surfaces and {ledger['summary']['tombstone_count']} tombstones")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
