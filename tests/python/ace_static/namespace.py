"""Repository-wide contracts for mutable ACE namespace roots."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re

from lua_source import code_without_comments_and_strings


@dataclass(frozen=True)
class NamespaceCollision:
    name: str
    function_path: str
    function_line: int
    indexed_path: str
    indexed_line: int


@dataclass(frozen=True)
class MutableFilterAlias:
    path: str
    line: int
    alias: str


FUNCTION_DEFINITION = re.compile(
    r"\bfunction\s+ACE\.([A-Za-z_][A-Za-z0-9_]*)\s*\(|"
    r"\bACE\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\b"
)
INDEXED_ACCESS = re.compile(r"\bACE\.([A-Za-z_][A-Za-z0-9_]*)\s*\[")


def _line(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def find_namespace_collisions(sources: dict[str, str]) -> list[NamespaceCollision]:
    functions: dict[str, tuple[str, int]] = {}
    indexed: dict[str, tuple[str, int]] = {}

    for path, raw_source in sources.items():
        source = code_without_comments_and_strings(raw_source)
        for match in FUNCTION_DEFINITION.finditer(source):
            name = match.group(1) or match.group(2)
            functions.setdefault(name, (path, _line(source, match.start())))
        for match in INDEXED_ACCESS.finditer(source):
            name = match.group(1)
            indexed.setdefault(name, (path, _line(source, match.start())))

    collisions = []
    for name in sorted(functions.keys() & indexed.keys()):
        function_path, function_line = functions[name]
        indexed_path, indexed_line = indexed[name]
        collisions.append(
            NamespaceCollision(
                name,
                function_path,
                function_line,
                indexed_path,
                indexed_line,
            )
        )
    return collisions


def find_repo_namespace_collisions(repo: Path) -> list[NamespaceCollision]:
    sources = {
        path.relative_to(repo).as_posix(): path.read_text(encoding="utf-8", errors="replace")
        for path in (repo / "lua").rglob("*.lua")
    }
    return find_namespace_collisions(sources)


def find_mutable_filter_aliases(sources: dict[str, str]) -> list[MutableFilterAlias]:
    """Find the common caller-filter alias followed by a mutating table operation."""
    findings: list[MutableFilterAlias] = []
    alias_re = re.compile(r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*Filter\b")
    mutation_template = r"\btable\.(?:Add|insert)\s*\(\s*{alias}\b"

    for path, raw_source in sources.items():
        source = code_without_comments_and_strings(raw_source)
        for alias in alias_re.finditer(source):
            tail = source[alias.end() :]
            if re.search(mutation_template.format(alias=re.escape(alias.group(1))), tail):
                findings.append(
                    MutableFilterAlias(path, _line(source, alias.start()), alias.group(1))
                )
    return findings
