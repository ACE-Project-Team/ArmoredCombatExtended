"""Heuristic ACE static-safety scanner.

The scanner intentionally emits warnings for broad patterns. It is not a Lua parser and should not
be used to block existing gameplay code until a rule has been source-proven and explicitly promoted.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re

from lua_source import code_without_comments_and_strings


RULE_IDS = {
    "ACE_POSSIBLY_UNBOUNDED_LOOP",
    "ACE_RECURSION",
    "ACE_TIMER_CALLBACK_SUBSTITUTE",
    "ACE_TIMER_TEARDOWN",
    "ACE_TIMER_ENTITY_CAPTURE",
    "ACE_TIMER_SELF_RESCHEDULE",
    "ACE_TIMER_NAME_COLLISION",
}

LUA_ROOTS = ("lua",)
ENTITY_CAPTURE = re.compile(r"\b(self|ent|entity|Entity|Bullet|Contraption|Player|ply)\b")
FUNCTION_DEF = re.compile(
    r"\b(?:local\s+function|function)\s+([A-Za-z_][A-Za-z0-9_:.]*)\s*\("
)
TIMER_CALL = re.compile(r"\btimer\s*\.\s*(Simple|Create)\s*\(")


@dataclass(frozen=True)
class Finding:
    rule_id: str
    path: str
    line: int
    message: str
    symbol: str | None = None


def iter_lua_files(repo: Path):
    for root in LUA_ROOTS:
        lua_root = repo / root
        if not lua_root.exists():
            continue
        yield from lua_root.rglob("*.lua")


def line_for_offset(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def scan_repo(repo: Path) -> list[Finding]:
    findings: list[Finding] = []
    for path in iter_lua_files(repo):
        findings.extend(scan_file(repo, path))
    return findings


def scan_file(repo: Path, path: Path) -> list[Finding]:
    source = path.read_text(encoding="utf-8", errors="replace")
    code = code_without_comments_and_strings(source)
    relative = path.relative_to(repo).as_posix()

    findings: list[Finding] = []
    findings.extend(scan_unbounded_loops(relative, code))
    findings.extend(scan_recursion(relative, code))
    findings.extend(scan_timers(relative, code, source))
    return findings


def scan_unbounded_loops(path: str, code: str) -> list[Finding]:
    findings: list[Finding] = []

    for match in re.finditer(r"\bwhile\s+true\s+do\b", code):
        findings.append(
            Finding(
                "ACE_POSSIBLY_UNBOUNDED_LOOP",
                path,
                line_for_offset(code, match.start()),
                "while true loop needs a visible cap, break condition, or allowlist reason",
            )
        )

    for match in re.finditer(r"\brepeat\b(?:(?!\buntil\b).)*\buntil\s+false\b", code, re.DOTALL):
        findings.append(
            Finding(
                "ACE_POSSIBLY_UNBOUNDED_LOOP",
                path,
                line_for_offset(code, match.start()),
                "repeat/until false loop needs a visible cap, break condition, or allowlist reason",
            )
        )

    return findings


def scan_recursion(path: str, code: str) -> list[Finding]:
    findings: list[Finding] = []
    definitions = list(FUNCTION_DEF.finditer(code))

    for index, match in enumerate(definitions):
        symbol = match.group(1)
        name = symbol.split(":")[-1].split(".")[-1]
        body_start = match.end()
        body_end = definitions[index + 1].start() if index + 1 < len(definitions) else len(code)
        body = code[body_start:body_end]

        if re.search(rf"\b{re.escape(symbol)}\s*\(", body) or re.search(rf"\b{re.escape(name)}\s*\(", body):
            findings.append(
                Finding(
                    "ACE_RECURSION",
                    path,
                    line_for_offset(code, match.start()),
                    f"recursive function {symbol} needs a finite runtime termination contract",
                    symbol=symbol,
                )
            )

    return findings


def scan_timers(path: str, code: str, source: str) -> list[Finding]:
    findings: list[Finding] = []
    timer_names: dict[str, int] = {}

    for match in TIMER_CALL.finditer(code):
        kind = match.group(1)
        line = line_for_offset(code, match.start())
        window = code[match.start() : match.start() + 500]
        source_window = source[match.start() : match.start() + 500]

        findings.append(
            Finding(
                "ACE_TIMER_CALLBACK_SUBSTITUTE",
                path,
                line,
                f"timer.{kind} should be audited against lifecycle/event callbacks",
            )
        )

        name_match = re.search(r"\(\s*([\"'])(.*?)\1", source_window)
        if kind == "Create" and name_match:
            timer_name = name_match.group(2)
            if timer_name in timer_names:
                findings.append(
                    Finding(
                        "ACE_TIMER_NAME_COLLISION",
                        path,
                        line,
                        f"static timer name {timer_name!r} appears multiple times in this file",
                    )
                )
            timer_names[timer_name] = line

            if not re.search(rf"\btimer\s*\.\s*Remove\s*\(\s*[\"']{re.escape(timer_name)}[\"']", code):
                findings.append(
                    Finding(
                        "ACE_TIMER_TEARDOWN",
                        path,
                        line,
                        f"timer {timer_name!r} has no obvious timer.Remove teardown in the same file",
                    )
                )

        if "function" in window and ENTITY_CAPTURE.search(window) and "IsValid" not in window:
            findings.append(
                Finding(
                    "ACE_TIMER_ENTITY_CAPTURE",
                    path,
                    line,
                    "timer callback appears to capture entity-like state without an IsValid check in the callback window",
                )
            )

        if kind == "Simple" and "timer.Simple" in window[window.find("function") + 1 :]:
            findings.append(
                Finding(
                    "ACE_TIMER_SELF_RESCHEDULE",
                    path,
                    line,
                    "timer callback appears to reschedule timer.Simple work",
                )
            )

    return findings
