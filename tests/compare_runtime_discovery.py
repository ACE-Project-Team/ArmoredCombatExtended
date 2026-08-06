"""Compare the static ACE path ledger with a server boot-discovery artifact."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re


def static_classes(ledger: dict, directory: str, suffix: str) -> set[str]:
    pattern = re.compile(rf"^{re.escape(directory)}/([^/]+)/{re.escape(suffix)}$")
    return {match.group(1) for row in ledger["surfaces"] if (match := pattern.match(row["source"]))}


def compare(ledger: dict, runtime: dict) -> dict:
    static_entities = static_classes(ledger, "lua/entities", "init.lua") | static_classes(ledger, "lua/entities", "shared.lua")
    static_sweps = static_classes(ledger, "lua/weapons", "shared.lua") | static_classes(ledger, "lua/weapons", "init.lua")
    runtime_entities = set(runtime.get("ace_entity_classes", []))
    runtime_sweps = set(runtime.get("ace_swep_classes", []))
    return {
        "static_entity_class_count": len(static_entities),
        "runtime_entity_class_count": len(runtime_entities),
        "entities_static_not_runtime": sorted(static_entities - runtime_entities),
        "entities_runtime_not_static": sorted(runtime_entities - static_entities),
        "static_swep_class_count": len(static_sweps),
        "runtime_swep_class_count": len(runtime_sweps),
        "sweps_static_not_runtime": sorted(static_sweps - runtime_sweps),
        "sweps_runtime_not_static": sorted(runtime_sweps - static_sweps),
        "runtime_hook_count": len(runtime.get("hooks", {})),
        "runtime_timer_count": len(runtime.get("timers", [])),
        "runtime_timer_inventory": "available" if runtime.get("timer_api_available") else "unsupported",
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ledger", type=Path)
    parser.add_argument("runtime", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = compare(json.loads(args.ledger.read_text(encoding="utf-8")), json.loads(args.runtime.read_text(encoding="utf-8")))
    text = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
