"""GitHub annotation formatting for ACE static warning reports."""

from __future__ import annotations

from ace_static.scanner import Finding


def github_annotation(finding: Finding, level: str = "warning") -> str:
    message = finding.message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")
    path = finding.path.replace("\\", "/")

    return f"::{level} file={path},line={finding.line},title={finding.rule_id}::{message}"


def findings_to_report(findings: list[Finding]) -> dict:
    return {
        "schema": 1,
        "findings": [
            {
                "rule_id": finding.rule_id,
                "path": finding.path,
                "line": finding.line,
                "message": finding.message,
                "symbol": finding.symbol,
                "severity": "warning",
            }
            for finding in findings
        ],
    }
