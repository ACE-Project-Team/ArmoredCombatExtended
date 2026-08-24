"""Offline contracts for ACE's expected soft-failure scenarios."""

from __future__ import annotations

import json
from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
MANIFEST = REPO / "tests" / "fixtures" / "general_use_manifest.json"
FIXTURES = REPO / "tests" / "fixtures" / "soft_failure_contracts.json"

EXPECTED_SCENARIOS = {
    "legacy_structure_compatibility_matrix",
    "partial_paste_payloads",
    "registry_schema_drift",
    "routing_and_link_rejection_matrix",
    "stale_link_and_master_cleanup",
    "orphan_and_split_routing",
    "network_payload_compatibility_matrix",
    "optional_dependency_fallbacks",
    "partial_initialization_and_factory_failure",
    "callback_and_timer_failure_boundaries",
    "malformed_round_and_guidance_inputs",
    "malformed_armor_and_physics_inputs",
    "dupe_link_restore_failure_matrix",
    "readout_and_overlay_failure_matrix",
    "error_capture_integrity",
}

REQUIRED_ROW_FIELDS = {
    "fixture",
    "phase",
    "operation",
    "expected",
    "observed",
    "unexpected",
    "cleanup_complete",
}


class SoftFailureContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        cls.fixture_contract = json.loads(FIXTURES.read_text(encoding="utf-8"))
        cls.scenarios = {scenario["id"]: scenario for scenario in cls.manifest["scenarios"]}

    def test_all_researched_scenarios_are_manifested(self):
        self.assertTrue(EXPECTED_SCENARIOS <= self.scenarios.keys())

    def test_soft_failure_scenarios_have_structured_expectations(self):
        for scenario_id in EXPECTED_SCENARIOS:
            with self.subTest(scenario=scenario_id):
                scenario = self.scenarios[scenario_id]
                self.assertTrue(scenario["failure_modes"])
                self.assertTrue(scenario["expected_outcomes"])
                self.assertIn("soft_failures.json", scenario["artifacts"])
                self.assertIn("cleanup_complete", scenario["expected_outcomes"])

    def test_fault_modes_and_outcomes_are_nonempty_strings(self):
        for scenario_id in EXPECTED_SCENARIOS:
            with self.subTest(scenario=scenario_id):
                scenario = self.scenarios[scenario_id]
                for field in ("failure_modes", "expected_outcomes"):
                    self.assertTrue(all(isinstance(value, str) and value for value in scenario[field]))

    def test_artifact_contract_requires_per_fault_cleanup_and_classification(self):
        self.assertEqual(self.fixture_contract["schema"], 1)
        self.assertEqual(set(self.fixture_contract["required_row_fields"]), REQUIRED_ROW_FIELDS)
        for name, description in self.fixture_contract["classifications"].items():
            with self.subTest(classification=name):
                self.assertTrue(name)
                self.assertTrue(description)

    def test_expected_error_rows_cannot_be_unexpected(self):
        artifact = {
            "schema": 1,
            "run_id": "contract-0001",
            "scenario_id": "legacy_structure_compatibility_matrix",
            "ace_commit": "unknown",
            "branch": "dev",
            "started_at": "2026-08-24T00:00:00Z",
            "finished_at": "2026-08-24T00:00:01Z",
            "events": [{"type": "compatibility"}],
            "errors": [],
            "soft_failures": [{
                "fixture": "legacy-material-id",
                "phase": "restore",
                "operation": "resolve_material",
                "expected": "fallback_applied",
                "observed": "fallback_applied",
                "unexpected": False,
                "cleanup_complete": True,
            }],
        }
        from test_runtime_artifact_schema import validate_artifact

        validate_artifact(artifact)

    def test_declaration_only_rows_are_not_marked_for_ci_execution(self):
        for scenario_id in EXPECTED_SCENARIOS:
            with self.subTest(scenario=scenario_id):
                self.assertFalse(self.scenarios[scenario_id]["ci"])


if __name__ == "__main__":
    unittest.main()
