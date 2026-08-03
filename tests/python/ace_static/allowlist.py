"""Validation and application of the static-safety warning allowlist."""

from __future__ import annotations

import json
from pathlib import Path

from ace_static.scanner import RULE_IDS


def apply_allowlist(findings, path: Path):
    allowlist = json.loads(path.read_text(encoding="utf-8"))
    if allowlist.get("schema") != 1 or set(allowlist.get("rules", {})) != RULE_IDS:
        raise ValueError("Malformed static safety allowlist")

    entries = allowlist["rules"]
    if not all(isinstance(value, list) for value in entries.values()):
        raise ValueError("Static safety allowlist entries must be lists")

    allowed = {
        (rule, item["path"], item["line"])
        for rule, items in entries.items()
        for item in items
        if isinstance(item, dict) and set(item) == {"path", "line"}
    }
    if sum(len(items) for items in entries.values()) != len(allowed):
        raise ValueError("Malformed static safety allowlist entry")

    stale = allowed - {
        (finding.rule_id, finding.path, finding.line)
        for finding in findings
    }
    if stale:
        raise ValueError(f"Stale static safety allowlist entries: {sorted(stale)}")

    return [
        finding
        for finding in findings
        if (finding.rule_id, finding.path, finding.line) not in allowed
    ]
