from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
LUA = REPO / "lua"


class LegacyExtensionCompatibilityTests(unittest.TestCase):
    def test_global_compatibility_bridges_are_removed(self):
        for name in ("ace_legacy_tools.lua", "ace_legacy_vehicles.lua", "ace_legacy_convars.lua"):
            with self.subTest(name=name):
                self.assertFalse((LUA / "autorun" / name).exists())

        source = (LUA / "autorun" / "acf_globals.lua").read_text(encoding="utf-8")
        self.assertNotIn("LegacyCompatibility", source)
        self.assertNotIn("InstallLegacyGlobal", source)
        self.assertNotIn("__ACECompatibilityView", source)

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

    def test_ace_table_does_not_install_a_metatable_fallback(self):
        source = (LUA / "autorun" / "acf_globals.lua").read_text(encoding="utf-8")
        self.assertNotIn('rawget(_G, "ACE_"', source)
        self.assertNotIn("setmetatable(ACF", source)


if __name__ == "__main__":
    unittest.main()
