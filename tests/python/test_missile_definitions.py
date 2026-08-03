"""Regression tests for the repository's missile-definition audit."""

import importlib.util
from pathlib import Path
import unittest

from lua_source import find_call_table, iter_named_calls


REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location(
    "ace_definition_audit", Path(__file__).with_name("missile_definition_audit.py")
)
AUDIT = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(AUDIT)


class MissileDefinitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        missile_dir = REPO / AUDIT.MISSILES_DIR
        cls.files = sorted(missile_dir.glob("*.lua"))
        cls.missiles = [
            missile
            for path in cls.files
            for missile in AUDIT.parse_missile_file(path)
        ]
        cls.source_definitions = []
        for path in cls.files:
            source = path.read_text(encoding="utf-8")
            for name, _, after_argument in iter_named_calls(source, "ACE.DefineGun"):
                cls.source_definitions.append(
                    {
                        "name": name,
                        "file": path.name,
                        "body": find_call_table(source, after_argument),
                    }
                )

    def test_missile_definition_directory_is_present(self):
        self.assertTrue(self.files, "no missile definition files were found")
        self.assertTrue(self.missiles, "no missile definitions were parsed")

    def test_every_source_missile_is_parsed(self):
        source_names = [definition["name"] for definition in self.source_definitions]
        parsed_names = [missile["name"] for missile in self.missiles]
        self.assertEqual(
            len(source_names),
            len(set(source_names)),
            "duplicate source missile definitions were found",
        )
        self.assertEqual(source_names, parsed_names)

    def test_every_missile_has_an_explicit_real_caliber_source(self):
        for definition in self.source_definitions:
            with self.subTest(missile=definition["name"], file=definition["file"]):
                has_comment = bool(
                    definition["body"]
                    and AUDIT.extract_comment_real_caliber_cm(definition["body"])
                )
                self.assertTrue(
                    definition["name"] in AUDIT.REAL_CALIBERS or has_comment,
                    "missing authoritative real-caliber annotation",
                )

    def test_minimum_projectile_length_is_well_formed(self):
        for missile in self.missiles:
            with self.subTest(missile=missile["name"]):
                self.assertGreater(missile["maxlength"], 0)
                self.assertGreaterEqual(missile["minproj_current"], 0)
                self.assertLessEqual(
                    missile["minproj_current"], missile["maxlength"]
                )

    def test_real_caliber_annotations_match_code(self):
        for missile in self.missiles:
            with self.subTest(missile=missile["name"]):
                self.assertFalse(
                    missile["body_mismatch"],
                    "real-caliber annotation disagrees with the parsed caliber",
                )

    def test_current_minimum_projectile_rule_is_not_legacy_sized(self):
        # Every missile should use the current 0.5x default or an explicitly smaller fixed rule.
        for missile in self.missiles:
            with self.subTest(missile=missile["name"]):
                if missile["minproj_source"].startswith("ratio:"):
                    self.assertEqual("ratio:0.5", missile["minproj_source"])
                    self.assertAlmostEqual(
                        missile["body_caliber"] * AUDIT.DEFAULT_MISSILE_MINPROJ_RATIO,
                        missile["minproj_current"],
                    )
                else:
                    self.assertEqual("fixed", missile["minproj_source"])
                self.assertLess(missile["minproj_current"], missile["minproj_legacy"])


if __name__ == "__main__":
    unittest.main()
