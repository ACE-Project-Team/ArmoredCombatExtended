import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]


class TestTemplateContracts(unittest.TestCase):
    def test_core_template_exposes_readable_comparisons(self):
        source = (REPO / "tests" / "templates" / "gluatest_core_function.lua").read_text(
            encoding="utf-8"
        )

        for helper in ("greaterThan", "lessThan", "changesWhen"):
            with self.subTest(helper=helper):
                self.assertIn(f"local function {helper}", source)

        self.assertIn(".to.beGreaterThan", source)
        self.assertIn(".to.beLessThan", source)
        self.assertIn(".notTo.equal", source)

    def test_native_fixture_contract_tracks_and_cleans_real_entities(self):
        source = (REPO / "tests" / "templates" / "native_fixtures.lua").read_text(
            encoding="utf-8"
        )

        self.assertIn("ents.Create", source)
        self.assertIn("State.Entities", source)
        self.assertIn("State.Contraptions", source)
        self.assertIn("entity:Remove()", source)
        self.assertIn("contraption:Remove()", source)

    def test_full_mod_fixture_is_registry_driven_and_artifact_backed(self):
        source = (REPO / "lua" / "ace" / "test_dsl_runtime.lua").read_text(encoding="utf-8")
        mounted_fixture = (REPO / "lua" / "ace" / "test_fixtures.lua").read_text(encoding="utf-8")
        fixture = (REPO / "tests" / "templates" / "native_fixtures.lua").read_text(
            encoding="utf-8"
        )

        for marker in (
            "Fixtures.EntityClasses()",
            "Fixtures.SpawnAll(State)",
            "Fixtures.RegisteredDupeClasses()",
            "ACE.FullModFixture",
            "ace_full_mod_fixture.json",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, source + mounted_fixture + fixture)

        for marker in ("scripted_ents.GetStored", "duplicator.FindEntityClass", "Fixtures.Cleanup"):
            with self.subTest(marker=marker):
                self.assertIn(marker, mounted_fixture + fixture)

    def test_snapshot_guidance_rejects_incidental_full_table_snapshots(self):
        source = (REPO / "tests" / "README.md").read_text(encoding="utf-8")

        self.assertIn("Full table containing incidental fields", source)
        self.assertIn("limited to public or intentionally frozen fields", source)
        self.assertIn("updated only alongside a written behavior change", source)


if __name__ == "__main__":
    unittest.main()
