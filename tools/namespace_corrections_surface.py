"""Build the source-derived runtime surface consumed by the live ACE probes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from namespace_corrections_inventory import inventory


def build_surface(repo: Path) -> dict:
    data = inventory(repo.resolve())
    functions = {"server": set(), "client": set()}
    for row in data["functions"]:
        if (
            not row["file"].startswith("lua/")
            or row["file"].startswith("lua/entities/")
            or row["file"] == "lua/ace/client/cl_acemenu_gui.lua"
            or not row["name"].startswith("ACE.")
        ):
            continue
        if row["realm"] == "server-or-shared":
            functions["server"].add(row["name"])
        if row["realm"] == "client-or-shared":
            functions["client"].add(row["name"])

    hooks = {"server": set(), "client": set()}
    for row in data["hooks"]:
        if (
            not row["file"].startswith("lua/")
            or row["file"].startswith("lua/entities/")
            or row["file"] == "lua/autorun/client/cl_ace_surveymessage.lua"
            or row["operation"] != "Add"
            or not row["identifier"]
            or row["identifier"] in {"event", "name"}
        ):
            continue
        value = (row["event"], row["identifier"])
        if row["realm"] == "server-or-shared":
            hooks["server"].add(value)
        if row["realm"] == "client-or-shared":
            hooks["client"].add(value)

    return {
        "algorithm": "bootstrap-installed production ACE.* functions and literal hook.Add registrations; entity-local definitions remain in the exhaustive inventory",
        "functions": {realm: sorted(values) for realm, values in functions.items()},
        "hooks": {
            realm: [{"event": event, "identifier": identifier} for event, identifier in sorted(values)]
            for realm, values in hooks.items()
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build_surface(args.repo)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "server_functions": len(result["functions"]["server"]),
        "client_functions": len(result["functions"]["client"]),
        "server_hooks": len(result["hooks"]["server"]),
        "client_hooks": len(result["hooks"]["client"]),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
