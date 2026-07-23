"""Regression contract for Primitive's transient armor-tool hover state."""

from pathlib import Path
import math
import unittest


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "lua"
    / "weapons"
    / "gmod_tool"
    / "stools"
    / "acfarmorprop.lua"
)


def preview_armor(area: float, ductility: float, thickness: float) -> float:
    """Mirror GLua's IEEE zero-area edge in the preview's armor calculation."""

    mass = area * math.sqrt(1 + ductility) * thickness * 0.00078
    if area == 0 and mass == 0:
        return math.nan  # GLua/LuaJIT's 0 / 0 result
    return mass * 1000 / area / 0.78 / math.sqrt(1 + ductility)


class ArmorToolPrimitiveRetryTests(unittest.TestCase):
    def test_zero_area_preview_is_not_a_valid_cached_state(self):
        self.assertTrue(math.isnan(preview_armor(0.0, 0.0, 10.0)))

    def test_transient_failed_hover_retries_until_acf_is_ready(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn(
            "if ent == self.AimEntity and self.AimEntityArmorReady then return end",
            source,
        )
        self.assertIn("self.AimEntityArmorReady = true", source)
        self.assertIn("self.AimEntityArmorReady = not ent.IsPrimitive", source)
        self.assertIn('displays "nan"', source)


if __name__ == "__main__":
    unittest.main()
