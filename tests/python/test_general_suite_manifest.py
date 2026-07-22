"""Contract tests for the ACE general-use scenario manifest."""

from __future__ import annotations

import json
from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
MANIFEST = REPO / "tests" / "fixtures" / "general_use_manifest.json"

REQUIRED_FAMILIES = {
    "registered_entities",
    "rounds",
    "materials_armor",
    "tank_duel",
    "spall_layered",
    "heat",
    "propulsion_fuel_crew",
    "weapon_lifecycle",
    "contraption_lifecycle",
    "sensors_missiles",
    "dupes",
    "network_serialization",
    "readouts",
    "runtime_errors",
    "performance",
}


class GeneralUseManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        cls.scenarios = cls.manifest["scenarios"]

    def test_every_intended_use_category_has_owner(self):
        families = {scenario["family"] for scenario in self.scenarios}

        self.assertEqual(REQUIRED_FAMILIES, families)

    def test_scenarios_have_bounded_runtime_and_artifacts(self):
        ids = set()
        for scenario in self.scenarios:
            with self.subTest(scenario=scenario["id"]):
                self.assertNotIn(scenario["id"], ids)
                ids.add(scenario["id"])
                self.assertIsInstance(scenario["timeout_seconds"], int)
                self.assertGreater(scenario["timeout_seconds"], 0)
                self.assertLessEqual(scenario["timeout_seconds"], 60)
                self.assertTrue(scenario["artifacts"])
                self.assertTrue(scenario["expected_events"])
                self.assertIn(scenario["realm"], {"python+luajit", "native", "native+luajit", "luajit+native", "headless"})

    def test_headless_cases_are_not_silently_enabled_in_ci(self):
        headless = [scenario for scenario in self.scenarios if scenario["realm"] == "headless"]

        self.assertGreater(len(headless), 0)
        self.assertTrue(all(not scenario["ci"] or scenario["id"] == "unexpected_error_capture" for scenario in headless))


if __name__ == "__main__":
    unittest.main()
