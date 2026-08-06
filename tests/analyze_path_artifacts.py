"""Validate and summarize already-collected ACE path artifacts without launching GMod."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

TESTS = Path(__file__).resolve().parent
sys.path.insert(0, str(TESTS / "python"))

from path_profile_artifacts import summarize  # noqa: E402


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("artifacts", nargs="+", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    artifacts = [json.loads(path.read_text(encoding="utf-8")) for path in args.artifacts]
    summary = summarize(artifacts)
    payload = {
        "schema": 1,
        "path_id": summary.path_id,
        "scenario_id": summary.scenario_id,
        "mode": summary.mode,
        "repetitions": summary.repetitions,
        "median_ms_per_operation": summary.median_ms_per_operation,
        "p95_ms": summary.p95_ms,
        "max_ms": summary.max_ms,
        "max_hitches_over_25ms": summary.max_hitches_over_25ms,
        "median_post_gc_delta_kb": summary.post_gc_delta_kb,
    }
    text = json.dumps(payload, indent=2) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
