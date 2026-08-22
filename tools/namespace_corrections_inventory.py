"""Generate the source-derived baseline for the ACE namespace conversion."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


FUNCTION_RE = re.compile(
    r"(?m)^\s*(?P<local>local\s+)?function\s+(?P<name>[A-Za-z_]\w*(?:[.:][A-Za-z_]\w*)*)\s*\("
)
ASSIGNMENT_RE = re.compile(
    r"(?m)^\s*(?P<local>local\s+)?(?P<name>[A-Za-z_]\w*(?:[.:][A-Za-z_]\w*)*)\s*=\s*function\s*\("
)
ANONYMOUS_FUNCTION_RE = re.compile(r"\bfunction\s*\(")
HOOK_RE = re.compile(
    r"\b(?P<receiver>hook)\s*[.:]\s*"
    r"(?P<operation>Add|Remove|Run|Call)\s*\(\s*"
    r"(?P<event>\"[^\"]*\"|'[^']*'|[^,\)\s]+)"
    r"(?:\s*,\s*(?P<identifier>\"[^\"]*\"|'[^']*'|[^,\)\s]+))?"
)


def mask_lua_comments(text: str, *, mask_strings: bool = False) -> str:
    """Mask comments, and optionally string literals, while preserving line numbers."""
    chars = list(text)

    def long_bracket_end(start: int) -> int | None:
        opener = re.match(r"\[(=*)\[", text[start:])
        if not opener:
            return None
        closer = "]" + opener.group(1) + "]"
        end = text.find(closer, start + len(opener.group(0)))
        return len(chars) if end < 0 else end + len(closer)

    def blank(start: int, end: int) -> None:
        for index in range(start, end):
            if chars[index] != "\n":
                chars[index] = " "

    i = 0
    quote = None
    while i < len(chars):
        if quote:
            current = text[i]
            if mask_strings and chars[i] != "\n":
                chars[i] = " "
            if current == "\\":
                i += 2
                continue
            if current == quote:
                quote = None
            i += 1
            continue
        if chars[i] in "\"'":
            quote = chars[i]
            if mask_strings:
                chars[i] = " "
            i += 1
            continue
        if chars[i] == "[":
            end = long_bracket_end(i)
            if end is not None:
                if mask_strings:
                    blank(i, end)
                i = end
                continue
        if text.startswith("//", i) or text.startswith("/*", i):
            end_marker = "\n" if text.startswith("//", i) else "*/"
            end = text.find(end_marker, i + 2)
            end = len(chars) if end < 0 else end + len(end_marker)
            blank(i, end)
            i = end
            continue
        if chars[i:i + 2] == ["-", "-"]:
            long_start = i + 2
            end = long_bracket_end(long_start)
            if end is not None:
                blank(i, end)
                i = end
                continue
            end = text.find("\n", i)
            if end < 0:
                end = len(chars)
            blank(i, end)
            i = end
            continue
        i += 1
    return "".join(chars)
TABLE_RE = re.compile(r"(?<![A-Za-z0-9_.])(?P<table>ACF|ACE)\s*[.:]\s*(?P<member>[A-Za-z_]\w*)")
LEGACY_RE = re.compile(r"\b(?:ACF|acf)(?:_[A-Za-z0-9_]+|\.[A-Za-z0-9_]+)?")
ACE_FLAT_RE = re.compile(r"\bACE_[A-Za-z0-9_]+")


def source_files(root: Path):
    paths = []
    for source_root in (root / "lua", root / "tests"):
        if source_root.exists():
            paths.extend(source_root.rglob("*.lua"))
    for path in sorted(paths):
        if any(part in {".git", "artifacts"} for part in path.parts):
            continue
        yield path


def classify_function(name: str, is_local: bool) -> str:
    if name.startswith("ACF_"):
        return "legacy-acf-local" if is_local else "legacy-acf-global"
    if name.startswith("ACE_"):
        return "ace-private-local" if is_local else "ace-flat-global"
    return "local" if is_local else "global"


def classify_disposition(name: str, scope: str) -> str:
    if name.startswith("ACE."):
        return "ACE.table"
    if scope == "ace-private-local":
        return "local ACE_*"
    if scope in {"ace-flat-global", "legacy-acf-global", "legacy-acf-local"}:
        return "review-required"
    return "review-required"


def classify_realm(relative: str) -> str:
    parts = Path(relative).parts
    if "server" in parts or relative.startswith("lua/entities/") and "cl_init.lua" not in relative:
        return "server-or-shared"
    if "client" in parts or relative.startswith("lua/effects/"):
        return "client-or-shared"
    return "shared-or-unknown"


def inventory(root: Path) -> dict:
    files = []
    functions = []
    anonymous_functions = []
    hooks = []
    table_refs = []
    legacy_refs = []
    ace_flat_refs = []

    for path in source_files(root):
        relative = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8", errors="replace")
        code = mask_lua_comments(text, mask_strings=True)
        hook_code = mask_lua_comments(text)
        legacy_code = mask_lua_comments(text, mask_strings=False)
        files.append(relative)

        for match in FUNCTION_RE.finditer(code):
            scope = classify_function(match.group("name"), bool(match.group("local")))
            functions.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "name": match.group("name"),
                "scope": scope,
                "disposition": classify_disposition(match.group("name"), scope),
                "kind": "function",
                "realm": classify_realm(relative),
            })

        for match in ASSIGNMENT_RE.finditer(code):
            scope = classify_function(match.group("name"), bool(match.group("local")))
            functions.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "name": match.group("name"),
                "scope": scope,
                "disposition": classify_disposition(match.group("name"), scope),
                "kind": "function-assignment",
                "realm": classify_realm(relative),
            })

        assignment_spans = [
            (match.start(), match.end()) for match in ASSIGNMENT_RE.finditer(code)
        ]
        for match in ANONYMOUS_FUNCTION_RE.finditer(code):
            if any(start <= match.start() < end for start, end in assignment_spans):
                continue
            anonymous_functions.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "name": None,
                "scope": "anonymous",
                "disposition": "review-required",
                "kind": "anonymous-function",
                "realm": classify_realm(relative),
            })

        for match in HOOK_RE.finditer(hook_code):
            if code[match.start()] == " ":
                continue
            event = match.group("event")
            identifier = match.group("identifier")
            hooks.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "operation": match.group("operation"),
                "event": event[1:-1] if len(event) >= 2 and event[0] in "\"'" else event,
                "identifier": (
                    identifier[1:-1]
                    if identifier and len(identifier) >= 2 and identifier[0] in "\"'"
                    else identifier
                ),
                "realm": classify_realm(relative),
            })

        for match in TABLE_RE.finditer(code):
            table_refs.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "table": match.group("table"),
                "member": match.group("member"),
            })

        for match in LEGACY_RE.finditer(legacy_code):
            legacy_refs.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "token": match.group(0),
            })

        for match in ACE_FLAT_RE.finditer(legacy_code):
            ace_flat_refs.append({
                "file": relative,
                "line": text.count("\n", 0, match.start()) + 1,
                "token": match.group(0),
            })

    files.sort()
    functions.sort(key=lambda item: (item["file"], item["line"], item["name"], item["kind"]))
    anonymous_functions.sort(key=lambda item: (item["file"], item["line"], item["kind"]))
    hooks.sort(key=lambda item: (item["file"], item["line"], item["operation"], item["event"]))
    table_refs.sort(key=lambda item: (item["file"], item["line"], item["table"], item["member"]))
    legacy_refs.sort(key=lambda item: (item["file"], item["line"], item["token"]))
    ace_flat_refs.sort(key=lambda item: (item["file"], item["line"], item["token"]))

    return {
        "base": ".",
        "files": files,
        "functions": functions,
        "anonymous_functions": anonymous_functions,
        "all_functions": sorted(
            functions + anonymous_functions,
            key=lambda item: (item["file"], item["line"], item["kind"], item["name"] or ""),
        ),
        "hooks": hooks,
        "table_refs": table_refs,
        "legacy_refs": legacy_refs,
        "ace_flat_refs": ace_flat_refs,
        "counts": {
            "lua_files": len(files),
            "functions": len(functions),
            "all_functions": len(functions) + len(anonymous_functions),
            "anonymous_functions": len(anonymous_functions),
            "hooks": len(hooks),
            "ace_flat_globals": sum(item["scope"] == "ace-flat-global" for item in functions),
            "acf_globals": sum(item["scope"] == "legacy-acf-global" for item in functions),
            "ace_private_locals": sum(item["scope"] == "ace-private-local" for item in functions),
            "acf_table_refs": sum(item["table"] == "ACF" for item in table_refs),
            "ace_table_refs": sum(item["table"] == "ACE" for item in table_refs),
            "legacy_tokens": len(legacy_refs),
            "ace_flat_refs": len(ace_flat_refs),
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
    parser.add_argument(
        "--csv-dir",
        type=Path,
        help="Also write exhaustive functions.csv and hooks.csv files to this directory.",
    )
    args = parser.parse_args()
    result = inventory(args.repo.resolve())
    output = args.output if args.output.is_absolute() else args.repo / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.csv_dir:
        csv_dir = args.csv_dir if args.csv_dir.is_absolute() else args.repo / args.csv_dir
        csv_dir.mkdir(parents=True, exist_ok=True)
        with (csv_dir / "functions.csv").open("w", newline="", encoding="utf-8") as stream:
            rows = result["all_functions"]
            writer = csv.DictWriter(
                stream,
                fieldnames=["file", "line", "name", "scope", "disposition", "kind", "realm"],
                extrasaction="ignore",
            )
            writer.writeheader()
            writer.writerows(rows)
        with (csv_dir / "hooks.csv").open("w", newline="", encoding="utf-8") as stream:
            rows = result["hooks"]
            writer = csv.DictWriter(
                stream,
                fieldnames=["file", "line", "operation", "event", "identifier", "realm"],
            )
            writer.writeheader()
            writer.writerows(rows)
    print(json.dumps(result["counts"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
