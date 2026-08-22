import json
import re
import unittest
from pathlib import Path

from ace_test_support import Scenario, scenario_failure


REPO = Path(__file__).resolve().parents[2]
CATALOG = REPO / "tests" / "fixtures" / "scenario_catalog.json"
ID_PATTERN = re.compile(r"^ace\.(offline|native|headless)\.[a-z0-9_]+\.[a-z0-9_]+$")
REQUIRED_FIELDS = {
    "id", "title", "reason", "layer", "runner", "dependencies",
    "expected_outcome", "check_type", "timeout_seconds", "tags", "status",
}
ROOT_FIELDS = {"schema", "scenarios"}
SCENARIO_FIELDS = REQUIRED_FIELDS | {"implemented_by", "source_manifest", "source_id"}
RUNNERS_BY_LAYER = {
    "offline": {"python", "luajit"},
    "native": {"gluatest"},
    "headless": {"headless"},
}
CHECK_TYPES = {
    "smoke", "static", "registry", "behavior", "compatibility",
    "lifecycle", "regression", "system", "performance",
}
REALM_BY_LAYER = {"native": "native", "headless": "headless"}
AUTHORITATIVE_MANIFEST = "tests/fixtures/general_use_manifest.json"


class ScenarioCatalogTests(unittest.TestCase):
    def test_catalog_is_human_readable_and_points_to_real_implemented_tests(self):
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        self.validate_catalog(catalog)

    def validate_catalog(self, catalog):
        self.assertEqual(ROOT_FIELDS, set(catalog))
        self.assertIs(type(catalog["schema"]), int)
        self.assertEqual(1, catalog["schema"])
        scenarios = catalog["scenarios"]
        self.assertIs(type(scenarios), list)
        self.assertTrue(scenarios)
        ids = []

        for scenario in scenarios:
            self.assertIs(type(scenario), dict)
            self.assertTrue(set(scenario) <= SCENARIO_FIELDS)
            self.assertTrue(REQUIRED_FIELDS <= set(scenario))
            for field in ("id", "title", "reason", "expected_outcome", "check_type", "layer", "runner", "status"):
                self.assertIs(type(scenario[field]), str)
            ids.append(scenario["id"])
            self.assertRegex(scenario["id"], ID_PATTERN)
            self.assertIn(scenario["check_type"], CHECK_TYPES)
            self.assertIn(scenario["layer"], RUNNERS_BY_LAYER)
            self.assertIn(scenario["runner"], RUNNERS_BY_LAYER[scenario["layer"]])
            self.assertEqual(scenario["id"].split(".")[1], scenario["layer"])
            self.assertIsInstance(scenario["dependencies"], list)
            self.assertTrue(all(type(item) is str and item for item in scenario["dependencies"]))
            self.assertIsInstance(scenario["tags"], list)
            self.assertTrue(all(type(item) is str and item for item in scenario["tags"]))
            self.assertIs(type(scenario["timeout_seconds"]), int)
            self.assertTrue(scenario["title"].strip())
            self.assertTrue(scenario["reason"].strip())
            self.assertTrue(scenario["expected_outcome"].strip())
            self.assertGreater(scenario["timeout_seconds"], 0)
            self.assertIn(scenario["status"], {"implemented", "planned"})
            if scenario["status"] == "implemented":
                self.assertIn("implemented_by", scenario)
                self.assertIs(type(scenario["implemented_by"]), str)
                implementation = REPO / scenario["implemented_by"]
                self.assertTrue(implementation.is_file())
                self.assertIn(scenario["id"], implementation.read_text(encoding="utf-8"))
            else:
                self.assertNotIn("implemented_by", scenario)
            if scenario["layer"] == "offline":
                self.assertNotIn("source_manifest", scenario)
                self.assertNotIn("source_id", scenario)
            if scenario["layer"] in {"native", "headless"}:
                self.assertIn("source_manifest", scenario)
                self.assertIn("source_id", scenario)
                self.assertEqual(AUTHORITATIVE_MANIFEST, scenario["source_manifest"])
                self.assertIs(type(scenario["source_manifest"]), str)
                self.assertIs(type(scenario["source_id"]), str)
                source = json.loads((REPO / scenario["source_manifest"]).read_text(encoding="utf-8"))
                linked = [item for item in source["scenarios"] if item["id"] == scenario["source_id"]]
                self.assertEqual(1, len(linked))
                self.assertEqual(REALM_BY_LAYER[scenario["layer"]], linked[0]["realm"])
                self.assertEqual(scenario["timeout_seconds"], linked[0]["timeout_seconds"])

        self.assertEqual(len(ids), len(set(ids)))

    def test_catalog_rejects_wrong_root_and_field_types(self):
        catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
        for bad_catalog in (
            {"schema": 1},
            {**catalog, "schema": True},
            {**catalog, "unexpected": []},
            {**catalog, "scenarios": [{**catalog["scenarios"][0], "tags": [1]}]},
            {**catalog, "scenarios": [{key: value for key, value in catalog["scenarios"][0].items() if key != "id"}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][0], "title": 7}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][0], "timeout_seconds": True}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][0], "unexpected": "field"}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][3], "runner": "python"}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][3], "source_manifest": "README.md"}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][0], "check_type": "unknown"}]},
            {**catalog, "scenarios": [{key: value for key, value in catalog["scenarios"][0].items() if key != "check_type"}]},
            {**catalog, "scenarios": [{**catalog["scenarios"][0], "check_type": 7}]},
        ):
            with self.subTest(bad_catalog=bad_catalog):
                with self.assertRaises(AssertionError):
                    self.validate_catalog(bad_catalog)

    def test_failure_text_names_the_action_that_broke(self):
        message = scenario_failure(
            Scenario("ace.native.entity.survives_lifecycle", "ACE entities survive a normal lifecycle"),
            "remove entity",
            "the entity is removed without an error",
            "timer callback raised an error",
            ["class=ace_test_entity"],
        )
        self.assertIn("[ace.native.entity.survives_lifecycle]", message)
        self.assertIn("Step: remove entity", message)
        self.assertIn("Expected:", message)
        self.assertIn("Observed:", message)
        self.assertIn("Context: class=ace_test_entity", message)


if __name__ == "__main__":
    unittest.main()
