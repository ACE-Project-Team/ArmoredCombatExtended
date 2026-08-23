from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
GLOBALS = REPO / "lua" / "autorun" / "acf_globals.lua"


class LegacyExtensionCompatibilityTests(unittest.TestCase):
    def test_legacy_tool_map_is_explicit_and_canonical_tools_are_untouched(self):
        source = (REPO / "lua" / "autorun" / "ace_legacy_tools.lua").read_text(
            encoding="utf-8"
        )

        for old, canonical in (
            ("acfarmorprop", "acearmorprop"),
            ("acfchaircam", "acechaircam"),
            ("acfcopy", "acecopy"),
            ("acfmenu", "acemenu"),
            ("acfsound", "acesound"),
        ):
            with self.subTest(old=old):
                self.assertIn(f"{old} = \"{canonical}\"", source)
        self.assertNotIn('string.StartWith(toolmode, "ace")', source)
        self.assertNotIn('tool.AddToMenu = false', source)

    def test_legacy_tool_aliases_do_not_replace_canonical_menu_entries(self):
        source = (REPO / "lua" / "autorun" / "ace_legacy_tools.lua").read_text(
            encoding="utf-8"
        )

        self.assertIn('legacyTool.AddToMenu = false', source)

    def test_legacy_menu_localization_matches_canonical_information(self):
        source = (REPO / "resource" / "localization" / "en" / "armoredcombatextended.properties").read_text(
            encoding="utf-8"
        )
        for suffix in ("name", "desc", "left", "right", "stage1.link", "stage1.unlink", "stage1.multiselect", "stage1.reload", "creationfailed"):
            with self.subTest(suffix=suffix):
                canonical = f"tool.acemenu.{suffix}="
                legacy = f"tool.acfmenu.{suffix}="
                self.assertIn(canonical, source)
                self.assertIn(legacy, source)

    def test_ace_weapons_plus_legacy_calculation_bridges_are_guarded(self):
        source = GLOBALS.read_text(encoding="utf-8")
        self.assertIn("if ACECompatibilityView then", source)
        for symbol, implementation in (
            ("ACF_GetPhysicalParent", "ACE_GetPhysicalParent"),
            ("ACF_Kinetic", "ACE_Kinetic"),
            ("ACF_MuzzleVelocity", "ACE_MuzzleVelocity"),
            ("ACF_HE", "ACE_HE"),
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(f"{symbol} = {implementation}", source)

    def test_legacy_scaled_explosion_effect_name_is_available(self):
        alias = REPO / "lua" / "effects" / "acf_scaled_explosion" / "init.lua"
        self.assertEqual(
            alias.read_text(encoding="utf-8").strip(),
            '-- Legacy effect name used by ACF-compatible weapon extensions, including ACE Weapons+.\n'
            '-- The effect implementation remains owned by ACE\'s namespaced effect.\n'
            'include("effects/ace_scaled_explosion/init.lua")',
        )


if __name__ == "__main__":
    unittest.main()
