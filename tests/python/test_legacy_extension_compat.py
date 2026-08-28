from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
LUA = REPO / "lua"


class LegacyExtensionCompatibilityTests(unittest.TestCase):
    def test_external_weapon_compatibility_bridge_is_guarded(self):
        for name in ("ace_legacy_tools.lua", "ace_legacy_convars.lua"):
            with self.subTest(name=name):
                self.assertFalse((LUA / "autorun" / name).exists())

        source = (LUA / "autorun" / "acf_globals.lua").read_text(encoding="utf-8")
        self.assertIn("__ACECompatibilityView", source)
        for name in (
            "ACF_GetPhysicalParent", "ACF_Kinetic", "ACF_MuzzleVelocity", "ACF_HE",
        ):
            with self.subTest(name=name):
                self.assertIn(name, source)

    def test_canonical_hook_events_are_used(self):
        sources = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (LUA / "ace").rglob("*.lua")
        )
        self.assertNotIn("RunLegacyHook", sources)
        for event in (
            "ACEOnDamage", "ACEOnBulletCreation", "ACEOnBulletRemoved",
            "ACEOnBulletPenetrated", "ACEOnBulletRicochet", "ACEOnBulletHit",
        ):
            self.assertIn(event, sources)

    def test_ace_table_installs_only_the_guarded_acf_fallback(self):
        source = (LUA / "autorun" / "acf_globals.lua").read_text(encoding="utf-8")
        self.assertNotIn('rawget(_G, "ACE_"', source)
        self.assertIn("setmetatable(ACF", source)
        self.assertIn('file.Exists("autorun/acf_loader.lua", "LUA")', source)


if __name__ == "__main__":
    unittest.main()
