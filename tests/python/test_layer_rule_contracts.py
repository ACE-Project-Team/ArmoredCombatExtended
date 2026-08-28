"""Structural checks for the area/ductility armor-health contract."""

from pathlib import Path
import unittest


LUA = Path(__file__).resolve().parents[2] / "lua"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


class ArmorPricingContracts(unittest.TestCase):
    def test_points_model_prices_live_health_without_mass_multiplier_compensation(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_points_model.lua")
        self.assertNotIn("ACE.HealthRefmm", body)

    def test_tool_preview_uses_the_live_area_health_contract(self):
        body = read(LUA / "weapons" / "gmod_tool" / "stools" / "acearmorprop.lua")
        self.assertNotIn("ACE.HealthRefmm", body)

    def test_calc_health_does_not_scale_with_thickness(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_functions.lua")
        self.assertIn("return ( Area / ACE.Threshold ) * ( 1 + Ductility )", body)
        self.assertNotIn("Armour / ACE.HealthRefmm", body)


if __name__ == "__main__":
    unittest.main()
