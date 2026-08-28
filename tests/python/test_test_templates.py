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

    def test_snapshot_guidance_rejects_incidental_full_table_snapshots(self):
        source = (REPO / "tests" / "README.md").read_text(encoding="utf-8")

        self.assertIn("Full table containing incidental fields", source)
        self.assertIn("limited to public or intentionally frozen fields", source)
        self.assertIn("updated only alongside a written behavior change", source)


if __name__ == "__main__":
    unittest.main()
