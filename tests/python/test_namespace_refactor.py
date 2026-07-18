"""Regression checks for the non-entity ACE namespace migration."""

from pathlib import Path
import re
import unittest

from lua_source import code_without_comments_and_strings


REPO = Path(__file__).resolve().parents[2]
LUA_ROOT = REPO / "lua"
ENTITY_ROOT = LUA_ROOT / "entities"
ACE_CONVARS = (
    "enable_dp",
    "kepush",
    "hepush",
    "recoilpush",
    "healthmod",
    "armormod",
    "ammomod",
    "gunfire",
    "debris_lifetime",
    "debris_children",
    "spalling",
    "spalling_multipler",
    "explosions_scaled_he_max",
    "explosions_scaled_ents_max",
    "wind",
    "legacyrecoil",
)


def non_entity_sources():
    for path in LUA_ROOT.rglob("*.lua"):
        if ENTITY_ROOT in path.parents:
            continue
        yield path


class NamespaceRefactorTests(unittest.TestCase):
    def test_non_entity_private_helpers_do_not_use_legacy_function_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"\b(?:local\s+)?function\s+ACE_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_non_entity_calls_do_not_use_legacy_function_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?<!:)\bACE_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_namespaced_public_functions_are_defined_on_ace(self):
        definitions = set()
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            definitions.update(
                re.findall(
                    r"(?m)^\s*function\s+ACE\.([A-Za-z_][A-Za-z0-9_]*)\s*\(",
                    source,
                )
            )

        self.assertTrue(definitions)
        self.assertIn("DefineExplosive", definitions)
        self.assertIn("MarkArmorDirty", definitions)

    def test_named_global_functions_are_namespaced_or_entity_methods(self):
        for path in LUA_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?m)^\s*function\s+(?!ACE\.|ENT:|local\s)[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_entity_callers_use_the_dotted_backend_namespace(self):
        self.assertTrue(any(ENTITY_ROOT.rglob("*.lua")))
        legacy_entity_calls = (
            "Activate", "BulletClient", "CalcArmor", "CalcBulletFlight", "CalcCurve",
            "CanLinkRack", "Check", "CheckClips", "CheckLegal", "Damage", "GetAllChildren",
            "GetAllPhysicalConstraints", "GetGunValue", "GetHitAngle", "GetLinkedWheels",
            "GetPhysicalParent", "GetRackValue", "HE", "HEKill", "KEShove", "Kinetic",
            "MuzzleVelocity", "PropDamage", "RackCanLoadCaliber", "RenderLight",
            "ScaledExplosion", "SendNotify",
        )
        for path in ENTITY_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            for name in legacy_entity_calls:
                with self.subTest(source=path.relative_to(REPO), name=name):
                    self.assertNotRegex(
                        source,
                        rf"(?<!:)\bACF_{re.escape(name)}\s*\(",
                    )

    def test_entity_ace_globals_are_namespaced(self):
        for path in ENTITY_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?m)^\s*function\s+(?:Make(?:ACF|ACE)_[A-Za-z_]|ACF_[A-Za-z_])",
                )
                self.assertNotRegex(
                    source,
                    r"\bACE_Make[A-Za-z_][A-Za-z0-9_]*\s*=",
                )

    def test_ace_convars_use_modern_names_without_acf_aliases(self):
        globals_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8"
        )
        for name in ACE_CONVARS:
            with self.subTest(name=name):
                self.assertRegex(
                    globals_source,
                    rf'CreateConVar\(\s*"ace_{re.escape(name)}"',
                )
        for path in non_entity_sources():
            source = path.read_text(encoding="utf-8", errors="replace")
            for name in ACE_CONVARS:
                with self.subTest(source=path.relative_to(REPO), name=name):
                    self.assertNotIn(f'"acf_{name}"', source)


if __name__ == "__main__":
    unittest.main()
