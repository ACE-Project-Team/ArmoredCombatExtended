"""Generate a conservative, source-backed ACE runtime-surface ledger.

This is deliberately a discovery aid rather than a Lua parser. Every finding carries its source
file and line, and the generated manifest keeps explicit dispositions for paths that need runtime
confirmation. The ledger must never imply that a static match executed successfully.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import hashlib
import re
from pathlib import Path

from lua_source import code_without_comments_and_strings


@dataclass(frozen=True)
class Surface:
    path_id: str
    kind: str
    realm: str
    source: str
    line: int
    expression: str
    scenario_id: str
    disposition: str = "runtime-pending"


_FUNCTION = re.compile(r"\b(?:local\s+)?function\s+([A-Za-z_][\w:.]*)\s*\(")
_METHOD = re.compile(r"\b([A-Za-z_][\w]*)\s*:\s*([A-Za-z_]\w*)\s*(?:=|\()")
_ASSIGNED_FUNCTION = re.compile(r"\b([A-Za-z_][\w.]*)\s*=\s*function\s*\(")
_HOOK = re.compile(r"\bhook\s*\.\s*Add\s*\(")
_TIMER = re.compile(r"\btimer\s*\.\s*(Create|Simple)\s*\(")
_NET_RECEIVE = re.compile(r"\bnet\s*\.\s*Receive\s*\(")
_NET_START = re.compile(r"\bnet\s*\.\s*Start\s*\(")
_CONCOMMAND = re.compile(r"\bconcommand\s*\.\s*Add\s*\(")
_LOADER = re.compile(r"\b(include|AddCSLuaFile)\s*\(")
_REGISTRY = re.compile(r"\b(ACF|ACE)\s*\.\s*([A-Za-z_]\w*)\s*=\s*\{?")


def _line(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def _token(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_").lower() or "anonymous"


def _surface(kind: str, realm: str, relative: str, line: int, expression: str) -> Surface:
    scenario = {
        "hook": "boot_idle",
        "timer": "boot_idle",
        "net_receive": "network_permissions",
        "net_start": "network_permissions",
        "concommand": "network_permissions",
        "loader": "boot_idle",
        "registry": "public_integrations",
        "function": "generic_entity_lifecycle",
        "method": "generic_entity_lifecycle",
        "callback": "generic_entity_lifecycle",
    }.get(kind, "unmapped")
    stable = f"{kind}|{realm}|{relative}|{line}|{expression}"
    digest = hashlib.sha1(stable.encode("utf-8")).hexdigest()[:12]
    return Surface(f"surface_{digest}_{_token(expression)}", kind, realm, relative, line, expression, scenario)


def scan_file(repo: Path, path: Path) -> list[Surface]:
    source = path.read_text(encoding="utf-8", errors="replace")
    code = code_without_comments_and_strings(source)
    relative = path.relative_to(repo).as_posix()
    realm = "client" if "/client/" in f"/{relative}" or "/cl_" in f"/{relative}" else "server/shared"
    found: list[Surface] = []

    patterns = (
        ("function", _FUNCTION, lambda m: m.group(1)),
        ("callback", _ASSIGNED_FUNCTION, lambda m: m.group(1)),
        ("hook", _HOOK, lambda m: "hook.Add"),
        ("net_receive", _NET_RECEIVE, lambda m: "net.Receive"),
        ("concommand", _CONCOMMAND, lambda m: "concommand.Add"),
        ("registry", _REGISTRY, lambda m: f"{m.group(1)}.{m.group(2)}"),
    )
    for kind, pattern, expression in patterns:
        for match in pattern.finditer(code):
            found.append(_surface(kind, realm, relative, _line(code, match.start()), expression(match)))

    for match in _METHOD.finditer(code):
        found.append(_surface("method", realm, relative, _line(code, match.start()), f"{match.group(1)}:{match.group(2)}"))
    for match in _TIMER.finditer(code):
        found.append(_surface("timer", realm, relative, _line(code, match.start()), f"timer.{match.group(1)}"))
    for match in _NET_START.finditer(code):
        found.append(_surface("net_start", realm, relative, _line(code, match.start()), "net.Start"))
    for match in _LOADER.finditer(code):
        found.append(_surface("loader", realm, relative, _line(code, match.start()), f"{match.group(1)}(...)"))

    return found


def scan_repo(repo: Path) -> list[Surface]:
    surfaces: list[Surface] = []
    for path in sorted((repo / "lua").rglob("*.lua")):
        surfaces.extend(scan_file(repo, path))
    deduped = {surface.path_id: surface for surface in surfaces}
    return sorted(deduped.values(), key=lambda item: (item.source, item.line, item.path_id))


def build_ledger(repo: Path, prior: dict | None = None) -> dict:
    surfaces = scan_repo(repo)
    prior_rows = {row["path_id"]: row for row in (prior or {}).get("surfaces", [])}
    rows = []
    for surface in surfaces:
        old = prior_rows.get(surface.path_id, {})
        row = asdict(surface)
        row["disposition"] = old.get("disposition", surface.disposition)
        row["evidence"] = old.get("evidence", [])
        row["measurement"] = old.get("measurement", {
            "correctness": "pending",
            "timing": "pending",
            "attribution": "pending",
            "scaling": "pending",
            "soak": "pending",
        })
        rows.append(row)
    current_ids = {row["path_id"] for row in rows}
    tombstones = [row for row in (prior or {}).get("surfaces", []) if row["path_id"] not in current_ids]
    return {
        "schema": 1,
        "generator": "tests/python/ace_static/path_ledger.py",
        "source_root": str(repo),
        "source_commit": "runtime-required",
        "surfaces": rows,
        "tombstones": tombstones,
        "summary": {
            "surface_count": len(rows),
            "tombstone_count": len(tombstones),
            "runtime_pending_count": sum(row["disposition"] == "runtime-pending" for row in rows),
        },
    }


def validate_ledger(ledger: dict) -> None:
    if ledger.get("schema") != 1 or not isinstance(ledger.get("surfaces"), list):
        raise ValueError("path ledger must use schema 1 and contain surfaces")
    ids = [row.get("path_id") for row in ledger["surfaces"]]
    if None in ids or len(ids) != len(set(ids)):
        raise ValueError("path ledger contains missing or duplicate path IDs")
    for row in ledger["surfaces"]:
        required = {"path_id", "kind", "realm", "source", "line", "scenario_id", "disposition", "measurement"}
        if not required <= set(row):
            raise ValueError(f"incomplete ledger row: {row.get('path_id')}")
        if row["disposition"] not in {"runtime-pending", "covered", "excluded", "dead", "blocked"}:
            raise ValueError(f"invalid disposition for {row['path_id']}")
        if set(row["measurement"]) != {"correctness", "timing", "attribution", "scaling", "soak"}:
            raise ValueError(f"invalid measurement cells for {row['path_id']}")
