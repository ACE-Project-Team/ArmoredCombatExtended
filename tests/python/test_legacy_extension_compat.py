from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
GLOBALS = REPO / "lua" / "autorun" / "acf_globals.lua"


class LegacyExtensionCompatibilityTests(unittest.TestCase):
    def test_ace_weapons_plus_legacy_calculation_bridges_are_guarded(self):
        source = GLOBALS.read_text(encoding="utf-8")
        bridge_start = source.index("-- ACE Weapons+ still consumes")
        bridge = source[bridge_start:]

        self.assertIn("if ACECompatibilityView then", source[:bridge_start])
        for symbol, implementation in (
            ("ACF_GetPhysicalParent", "ACE_GetPhysicalParent"),
            ("ACF_Kinetic", "ACE_Kinetic"),
            ("ACF_MuzzleVelocity", "ACE_MuzzleVelocity"),
            ("ACF_HE", "ACE_HE"),
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(f"{symbol} = {symbol} or {implementation}", bridge)

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
