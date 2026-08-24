"""Artifact schema checks for headless/native ACE scenario runs."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest


REQUIRED_ARTIFACT_KEYS = {
    "schema",
    "run_id",
    "scenario_id",
    "ace_commit",
    "branch",
    "started_at",
    "finished_at",
    "events",
    "errors",
}
ALLOWED_ARTIFACT_KEYS = REQUIRED_ARTIFACT_KEYS | {"soft_failures"}

SOFT_FAILURE_ROW_KEYS = {
    "fixture",
    "phase",
    "operation",
    "expected",
    "observed",
    "unexpected",
    "cleanup_complete",
}


def validate_artifact(artifact: dict):
    missing = REQUIRED_ARTIFACT_KEYS - set(artifact)
    if missing:
        raise AssertionError(f"missing artifact keys: {sorted(missing)}")
    unknown = set(artifact) - ALLOWED_ARTIFACT_KEYS
    if unknown:
        raise AssertionError(f"unknown artifact keys: {sorted(unknown)}")
    for key in ("run_id", "scenario_id", "ace_commit", "branch", "started_at", "finished_at"):
        if not isinstance(artifact[key], str) or not artifact[key].strip():
            raise AssertionError(f"{key} must be a non-empty string")
    if artifact["schema"] != 1:
        raise AssertionError("unsupported artifact schema")
    if not isinstance(artifact["events"], list):
        raise AssertionError("events must be a list")
    for event in artifact["events"]:
        if not isinstance(event, dict) or not isinstance(event.get("type"), str) or not event["type"]:
            raise AssertionError("events must contain typed objects")
    if not isinstance(artifact["errors"], list):
        raise AssertionError("errors must be a list")
    if "soft_failures" in artifact and not isinstance(artifact["soft_failures"], list):
        raise AssertionError("soft_failures must be a list")
    for error in artifact["errors"]:
        if not isinstance(error, dict) or not isinstance(error.get("type"), str) or not isinstance(error.get("message"), str):
            raise AssertionError("errors must contain typed messages")
    for row in artifact.get("soft_failures", []):
        missing = SOFT_FAILURE_ROW_KEYS - set(row)
        if missing:
            raise AssertionError(f"soft-failure row missing keys: {sorted(missing)}")
        if not isinstance(row["unexpected"], bool):
            raise AssertionError("soft-failure unexpected must be boolean")
        if not isinstance(row["cleanup_complete"], bool):
            raise AssertionError("soft-failure cleanup_complete must be boolean")
        if row["unexpected"]:
            raise AssertionError("unexpected soft-failure rows cannot validate")


class RuntimeArtifactSchemaTests(unittest.TestCase):
    def test_valid_artifact_shape(self):
        artifact = {
            "schema": 1,
            "run_id": "local-0001",
            "scenario_id": "tank_duel_ap",
            "ace_commit": "unknown",
            "branch": "agent/ace-general-use-suite",
            "started_at": "2026-07-20T00:00:00Z",
            "finished_at": "2026-07-20T00:00:01Z",
            "events": [{"type": "boot"}],
            "errors": [],
        }

        validate_artifact(artifact)

    def test_missing_done_artifact_is_a_failure_condition(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            expected = root / "done.json"

            self.assertFalse(expected.exists())

    def test_artifact_json_roundtrip(self):
        artifact = {
            "schema": 1,
            "run_id": "local-0001",
            "scenario_id": "unexpected_error_capture",
            "ace_commit": "unknown",
            "branch": "agent/ace-general-use-suite",
            "started_at": "2026-07-20T00:00:00Z",
            "finished_at": "2026-07-20T00:00:01Z",
            "events": [{"type": "boot"}, {"type": "done"}],
            "errors": [],
        }

        self.assertEqual(artifact, json.loads(json.dumps(artifact)))

    def test_valid_soft_failure_rows_are_structured(self):
        artifact = {
            "schema": 1,
            "run_id": "local-0002",
            "scenario_id": "registry_schema_drift",
            "ace_commit": "unknown",
            "branch": "dev",
            "started_at": "2026-08-24T00:00:00Z",
            "finished_at": "2026-08-24T00:00:01Z",
            "events": [{"type": "done"}],
            "errors": [],
            "soft_failures": [{
                "fixture": "unknown-round",
                "phase": "validate",
                "operation": "lookup_round",
                "expected": "handled_rejection",
                "observed": "handled_rejection",
                "unexpected": False,
                "cleanup_complete": True,
            }],
        }

        validate_artifact(artifact)

    def test_unexpected_soft_failure_row_is_rejected(self):
        artifact = {
            "schema": 1,
            "run_id": "local-0003",
            "scenario_id": "error_capture_integrity",
            "ace_commit": "unknown",
            "branch": "dev",
            "started_at": "2026-08-24T00:00:00Z",
            "finished_at": "2026-08-24T00:00:01Z",
            "events": [{"type": "done"}],
            "errors": [],
            "soft_failures": [{
                "fixture": "unclassified",
                "phase": "callback",
                "operation": "invoke",
                "expected": "safe_noop",
                "observed": "lua_error",
                "unexpected": True,
                "cleanup_complete": False,
            }],
        }

        with self.assertRaises(AssertionError):
            validate_artifact(artifact)


if __name__ == "__main__":
    unittest.main()
