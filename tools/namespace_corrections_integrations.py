"""Build source-derived E2 and Starfall ACE adapter manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


E2_DECLARATION = re.compile(
    r"\be2function\s+\S+\s+(?:(?:[A-Za-z_]\w*)\:)?([A-Za-z_]\w*)\s*\("
)
STARFALL_LIBRARY = re.compile(r"\bfunction\s+acf_library\.([A-Za-z_]\w*)\s*\(")
STARFALL_METHOD = re.compile(r"\bfunction\s+ents_methods:([A-Za-z_]\w*)\s*\(")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_manifest(repo: Path) -> dict:
    e2_path = repo / "lua/entities/gmod_wire_expression2/core/custom/acf.lua"
    sf_path = repo / "lua/starfall/libs_sv/acf.lua"
    e2_text = e2_path.read_text(encoding="utf-8")
    sf_text = sf_path.read_text(encoding="utf-8")
    e2_names = sorted(set(E2_DECLARATION.findall(e2_text)))
    sf_library = sorted(set(STARFALL_LIBRARY.findall(sf_text)))
    sf_methods = sorted(set(STARFALL_METHOD.findall(sf_text)))
    return {
        "schema": 1,
        "sources": {
            "e2": {"file": e2_path.relative_to(repo).as_posix(), "sha256": sha256(e2_path)},
            "starfall": {"file": sf_path.relative_to(repo).as_posix(), "sha256": sha256(sf_path)},
        },
        "e2": {"declarations": len(E2_DECLARATION.findall(e2_text)), "names": e2_names},
        "starfall": {"library_functions": sf_library, "entity_methods": sf_methods},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    result = build_manifest(args.repo.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "e2_declarations": result["e2"]["declarations"],
        "e2_names": len(result["e2"]["names"]),
        "starfall_library_functions": len(result["starfall"]["library_functions"]),
        "starfall_entity_methods": len(result["starfall"]["entity_methods"]),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
