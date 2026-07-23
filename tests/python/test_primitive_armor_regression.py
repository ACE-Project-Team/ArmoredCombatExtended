"""Regression coverage for Primitive's persisted ACE armor snapshots."""

from pathlib import Path
import math
import re
import unittest


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "lua"
    / "autorun"
    / "server"
    / "sv_ace_primitive_compat.lua"
)


def is_finite_armor_snapshot(snapshot: dict[str, float]) -> bool:
    """Mirror the snapshot invariant: every persisted armor number is finite."""

    positive = ("Area", "Armour", "MaxArmour", "MaxHealth")
    non_negative = ("Health",)

    return all(math.isfinite(snapshot[field]) and snapshot[field] > 0 for field in positive) and all(
        math.isfinite(snapshot[field]) and snapshot[field] >= 0 for field in non_negative
    ) and math.isfinite(snapshot.get("Ductility", 0))


class PrimitiveArmorSnapshotTests(unittest.TestCase):
    def test_nan_snapshot_is_rejected(self):
        snapshot = {
            "Area": 100,
            "Armour": math.nan,
            "MaxArmour": 10,
            "Health": 100,
            "MaxHealth": 100,
            "Ductility": 0,
        }

        self.assertFalse(is_finite_armor_snapshot(snapshot))

    def test_finite_damaged_snapshot_is_preserved(self):
        snapshot = {
            "Area": 100,
            "Armour": 5,
            "MaxArmour": 10,
            "Health": 0,
            "MaxHealth": 100,
            "Ductility": -0.2,
        }

        self.assertTrue(is_finite_armor_snapshot(snapshot))

    def test_runtime_snapshot_and_restore_check_the_same_gate(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn("value == value", source)
        self.assertIn("value > -math.huge and value < math.huge", source)
        self.assertIn("if not IsFiniteNumber(acf.Armour) or acf.Armour <= 0 then return end", source)

        restore = re.search(
            r"local function RestoreSavedArmor\(ent, phys\)(?P<body>.*?)\nend",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(restore)
        self.assertIn("local saved = CopyArmorValues(ent.ACE_PrimitiveSavedArmor)", restore.group("body"))

    def test_fallback_drops_other_non_finite_inputs_before_recalculation(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn("local function ClearInvalidLiveArmorValues(acf)", source)
        self.assertIn("acf.Ductility = nil", source)
        self.assertIn("acf.Health = nil", source)
        self.assertIn("ClearInvalidLiveArmorValues(ent.ACF)", source)


if __name__ == "__main__":
    unittest.main()
