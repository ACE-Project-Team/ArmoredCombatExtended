import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
PROTOTYPE = REPO / "tests" / "prototypes" / "acf_core_suite_applied.ace_test"


class InterpretedTestPrototypeTests(unittest.TestCase):
    def test_prototype_uses_only_maintainer_facing_operations(self):
        source = PROTOTYPE.read_text(encoding="utf-8")

        for token in ("new Test", "uses ", "do ", "expect ", "cleanup automatic"):
            with self.subTest(token=token):
                self.assertIn(token, source)

        for implementation_detail in ("beforeEach", "ents.Create", "hook.Add", "stub(", "expect("):
            with self.subTest(implementation_detail=implementation_detail):
                self.assertNotIn(implementation_detail, source)

    def test_prototype_covers_the_core_function_groups(self):
        source = PROTOTYPE.read_text(encoding="utf-8")

        for symbol in (
            "ACE.Check",
            "ACE.Activate",
            "ACE_CheckLegal",
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, source)

    def test_prototype_includes_comparisons_and_native_presence_checks(self):
        source = PROTOTYPE.read_text(encoding="utf-8")

        self.assertIn("is not legal", source)
        self.assertIn("requires native", source)
        self.assertIn("Prop.ACF exists", source)
        self.assertIn("Prop was activated", source)


if __name__ == "__main__":
    unittest.main()
