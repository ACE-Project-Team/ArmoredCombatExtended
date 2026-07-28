"""Performance scenario contract runner for ACE.

The initial gate is intentionally conservative. It verifies that performance scenarios are declared
with bounded runtimes and artifact names. Hard timing thresholds should be added only after stable
baseline data exists.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default="tests/fixtures/general_use_manifest.json")
    parser.add_argument("--ci-smoke", action="store_true")
    args = parser.parse_args()

    manifest = json.loads((REPO / args.manifest).read_text(encoding="utf-8"))
    scenarios = [scenario for scenario in manifest["scenarios"] if scenario["family"] == "performance"]

    if not scenarios:
        raise SystemExit("No performance scenarios declared")

    for scenario in scenarios:
        if scenario["timeout_seconds"] > 60:
            raise SystemExit(f"{scenario['id']} timeout exceeds the initial smoke budget")
        if "perf.json" not in scenario["artifacts"]:
            raise SystemExit(f"{scenario['id']} does not declare a perf artifact")

    print(f"Validated {len(scenarios)} performance scenario contract(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
