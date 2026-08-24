"""Keep the native GLuaTest suite visible to CI and reviewers."""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
NATIVE_ROOT = REPO / "lua" / "tests" / "ace"
CANARY = NATIVE_ROOT / "000_discovery_canary.lua"
GUARD = REPO / "tests" / "gluatest_overrides" / "lua" / "autorun" / "ace_gluatest_guard.lua"


class NativeSuiteManifestTests(unittest.TestCase):
    def test_native_suite_contains_a_discovery_canary(self):
        self.assertTrue(CANARY.is_file())
        self.assertIn("groupName", CANARY.read_text(encoding="utf-8"))
        self.assertIn("discovers and executes", CANARY.read_text(encoding="utf-8"))

    def test_native_suite_contains_multiple_groups(self):
        suites = {path.name for path in NATIVE_ROOT.glob("*.lua")}
        required = {
                "000_discovery_canary.lua",
                "armor_spall_corpus.lua",
                "dupe_spawn.lua",
                "entity_registration.lua",
                "general_use_contracts.lua",
                "invalidation_hooks.lua",
                "registries.lua",
                "spall_rubber.lua",
                "soft_failure_contracts.lua",
        }
        self.assertTrue(required <= suites)

    def test_native_job_has_an_external_discovery_guard(self):
        guard = GUARD.read_text(encoding="utf-8")
        self.assertIn("GLuaTest_Finished", guard)
        self.assertIn("gluatest_failures.json", guard)
        self.assertIn("ACE GLuaTest discovery canary", guard)


if __name__ == "__main__":
    unittest.main()
