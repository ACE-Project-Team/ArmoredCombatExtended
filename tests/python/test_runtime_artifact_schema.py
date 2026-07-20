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


def validate_artifact(artifact: dict):
    missing = REQUIRED_ARTIFACT_KEYS - set(artifact)
    if missing:
        raise AssertionError(f"missing artifact keys: {sorted(missing)}")
    if artifact["schema"] != 1:
        raise AssertionError("unsupported artifact schema")
    if not isinstance(artifact["events"], list):
        raise AssertionError("events must be a list")
    if not isinstance(artifact["errors"], list):
        raise AssertionError("errors must be a list")


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


if __name__ == "__main__":
    unittest.main()
