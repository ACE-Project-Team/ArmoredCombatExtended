import json
import unittest
from pathlib import Path


ROOT = Path(__file__).parents[2]
SUITE = ROOT / "tests" / "prototypes" / "acf_core_suite_applied.ace_test"
REGISTRY = ROOT / "tests" / "prototypes" / "ace_core_fixture_registry.json"


class RealCorePrototypeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        cls.lines = SUITE.read_text(encoding="utf-8").splitlines()

    def test_fixture_registry_contains_only_explicit_prototype_fixtures(self):
        self.assertEqual(self.registry["schema"], 2)
        self.assertEqual(self.registry["status"], "prototype")
        self.assertGreaterEqual(len(self.registry["fixtures"]), 10)
        for fixture in self.registry["fixtures"].values():
            self.assertIn(fixture["kind"], {"native_entity", "native_player", "native_vehicle"})

    def test_suite_fixture_names_resolve(self):
        names = []
        for line in self.lines:
            if line.startswith("uses "):
                names.append(line.removeprefix("uses ").split(" as ", 1)[0])
        self.assertTrue(names)
        self.assertTrue(set(names) <= set(self.registry["fixtures"]))

    def test_suite_covers_source_backed_core_symbols(self):
        suite = "\n".join(self.lines)
        for symbol in (
            "ACE.Check",
            "ACE.Activate",
            "ACE_CheckLegal",
        ):
            self.assertIn(symbol, suite)
        self.assertEqual(suite.count("requires native"), 12)
        for phrase in ("was reactivated", "is legal", "is not legal", "reason is", "cleanup automatic"):
            self.assertIn(phrase, suite)


if __name__ == "__main__":
    unittest.main()
