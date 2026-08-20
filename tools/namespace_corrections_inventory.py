"""Generate the source-derived baseline for the ACE namespace conversion."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


FUNCTION_RE = re.compile(
    r"(?m)^\s*(?P<local>local\s+)?function\s+(?P<name>[A-Za-z_]\w*(?:[.:][A-Za-z_]\w*)*)\s*\("
)
ASSIGNMENT_RE = re.compile(
    r"(?m)^\s*(?P<local>local\s+)?(?P<name>(?:ACF|ACE)_[A-Za-z_]\w*)\s*=\s*function\s*\("
)
TABLE_RE = re.compile(r"(?<![A-Za-z0-9_])(?P<table>ACF|ACE)\s*[.:]\s*(?P<member>[A-Za-z_]\w*)")
LEGACY_RE = re.compile(r"\b(?:ACF|acf)(?:_[A-Za-z0-9_]+|\.[A-Za-z0-9_]+)?")


def source_files(root: Path):
    for path in sorted((root / "lua").rglob("*.lua")):
        if any(part in {".git", "artifacts"} for part in path.parts):
            continue
        yield path


def classify_function(name: str, is_local: bool) -> str:
    if name.startswith("ACF_"):
        return "legacy-acf-local" if is_local else "legacy-acf-global"
    if name.startswith("ACE_"):
        return "ace-private-local" if is_local else "ace-flat-global"
    return "local" if is_local else "global"


def inventory(root: Path) -> dict:
    files = []
    functions = []
    table_refs = []
    legacy_refs = []

    for path in source_files(root):
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        files.append(relative)

        for match in FUNCTION_RE.finditer(text):
            functions.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "name": match.group("name"),
                "scope": classify_function(match.group("name"), bool(match.group("local"))),
                "kind": "function",
            })

        for match in ASSIGNMENT_RE.finditer(text):
            functions.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "name": match.group("name"),
                "scope": classify_function(match.group("name"), bool(match.group("local"))),
                "kind": "function-assignment",
            })

        for match in TABLE_RE.finditer(text):
            table_refs.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "table": match.group("table"),
                "member": match.group("member"),
            })

        for match in LEGACY_RE.finditer(text):
            legacy_refs.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "token": match.group(0),
            })

    files.sort()
    functions.sort(key=lambda item: (item["file"], item["line"], item["name"], item["kind"]))
    table_refs.sort(key=lambda item: (item["file"], item["line"], item["table"], item["member"]))
    legacy_refs.sort(key=lambda item: (item["file"], item["line"], item["token"]))

    return {
        "base": str(root),
        "files": files,
        "functions": functions,
        "table_refs": table_refs,
        "legacy_refs": legacy_refs,
        "counts": {
            "lua_files": len(files),
            "functions": len(functions),
            "ace_flat_globals": sum(item["scope"] == "ace-flat-global" for item in functions),
            "acf_globals": sum(item["scope"] == "legacy-acf-global" for item in functions),
            "ace_private_locals": sum(item["scope"] == "ace-private-local" for item in functions),
            "acf_table_refs": sum(item["table"] == "ACF" for item in table_refs),
            "ace_table_refs": sum(item["table"] == "ACE" for item in table_refs),
            "legacy_tokens": len(legacy_refs),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("artifacts/namespace-corrections/inventory.json"),
    )
    args = parser.parse_args()
    result = inventory(args.repo.resolve())
    output = args.output if args.output.is_absolute() else args.repo / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result["counts"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
