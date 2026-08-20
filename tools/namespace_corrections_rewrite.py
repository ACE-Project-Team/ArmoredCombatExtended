"""Mechanically move flat public ACE_* identifiers into the ACE table.

This deliberately handles only the public flat ACE namespace. Local ACE_* helpers and
local ACE_* variables remain untouched; comments, strings, and object-qualified fields are
not rewritten. A later semantic pass handles ACF state, paths, and integration contracts.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
LOCAL_DECL = re.compile(r"\blocal\s+(?:function\s+)?(ACE_[A-Za-z0-9_]*)\b")


def skip_quoted(source: str, index: int) -> int:
    quote = source[index]
    index += 1
    while index < len(source):
        if source[index] == "\\":
            index += 2
        elif source[index] == quote:
            return index + 1
        else:
            index += 1
    return len(source)


def skip_long_bracket(source: str, index: int) -> int | None:
    match = re.match(r"\[(=*)\[", source[index:])
    if not match:
        return None
    closing = "]" + match.group(1) + "]"
    end = source.find(closing, index + match.end())
    return len(source) if end < 0 else end + len(closing)


def rewrite_source(source: str, include_acf: bool = False) -> tuple[str, int]:
    local_names = set(LOCAL_DECL.findall(source))
    output: list[str] = []
    index = 0
    replacements = 0

    while index < len(source):
        if source.startswith("--", index) and index + 2 < len(source) and source[index + 2] == "[":
            long_end = skip_long_bracket(source, index + 2)
            if long_end is not None:
                output.append(source[index:long_end])
                index = long_end
                continue
        if source.startswith("--", index):
            end = source.find("\n", index + 2)
            end = len(source) if end < 0 else end
            output.append(source[index:end])
            index = end
            continue
        if source.startswith("//", index):
            end = source.find("\n", index + 2)
            end = len(source) if end < 0 else end
            output.append(source[index:end])
            index = end
            continue
        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            end = len(source) if end < 0 else end + 2
            output.append(source[index:end])
            index = end
            continue
        if source[index] in "'\"":
            end = skip_quoted(source, index)
            output.append(source[index:end])
            index = end
            continue
        long_end = skip_long_bracket(source, index) if source[index] == "[" else None
        if long_end is not None:
            output.append(source[index:long_end])
            index = long_end
            continue

        match = IDENTIFIER.match(source, index)
        if not match:
            output.append(source[index])
            index += 1
            continue

        name = match.group(0)
        previous = source[:match.start()].rstrip()[-1:] or ""
        if include_acf and name == "ACF" and previous not in ".:":
            output.append("ACE")
            replacements += 1
        elif (
            include_acf
            and name.startswith("ACF_")
            and name not in local_names
            and previous not in ".:"
        ):
            output.append("ACE." + name[4:])
            replacements += 1
        elif (
            name.startswith("ACE_")
            and name not in local_names
            and previous not in ".:"
        ):
            output.append("ACE." + name[4:])
            replacements += 1
        else:
            output.append(name)
        index = match.end()

    return "".join(output), replacements


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--include-acf", action="store_true")
    args = parser.parse_args()
    total = 0
    changed = 0
    for path in sorted((args.repo / "lua").rglob("*.lua")):
        with path.open("r", encoding="utf-8", errors="replace", newline="") as handle:
            source = handle.read()
        rewritten, count = rewrite_source(source, include_acf=args.include_acf)
        total += count
        if count and rewritten != source:
            changed += 1
            if args.apply:
                with path.open("w", encoding="utf-8", newline="") as handle:
                    handle.write(rewritten)
    mode = "applied" if args.apply else "would rewrite"
    print(f"{mode} {total} public ACE_* references across {changed} Lua files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
