"""Structural checks for the armor-health pricing compatibility boundary."""

from pathlib import Path
import unittest


LUA = Path(__file__).resolve().parents[2] / "lua"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


class ArmorPricingContracts(unittest.TestCase):
    def test_points_model_undoes_mass_scaled_health(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_points_model.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm * (ACE.ArmorMod or 1) / armourMm"), 1)

    def test_tool_preview_undoes_mass_scaled_health(self):
        body = read(LUA / "weapons" / "gmod_tool" / "stools" / "acearmorprop.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm / armor"), 1)


if __name__ == "__main__":
    unittest.main()
