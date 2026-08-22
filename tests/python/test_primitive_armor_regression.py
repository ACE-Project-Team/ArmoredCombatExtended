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
        self.assertIn("local acf = ACE.GetEntityState(ent, true)", restore.group("body"))

    def test_fallback_drops_other_non_finite_inputs_before_recalculation(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn("local function ClearInvalidLiveArmorValues(acf)", source)
        self.assertIn("acf.Ductility = nil", source)
        self.assertIn("acf.Health = nil", source)
        self.assertIn("local state = ACE.GetEntityState(ent)", source)
        self.assertIn("ClearInvalidLiveArmorValues(state)", source)

    def test_legacy_acfsettings_are_rebuilt_from_final_primitive_state(self):
        source = SOURCE.read_text(encoding="utf-8")

        self.assertIn("local function CopyLegacyArmorSettings(modifiers)", source)
        self.assertIn("local function RestoreLegacyArmorSettings(ent)", source)
        self.assertIn("math.Clamp(settings.Ductility, -80, 80) * 0.01", source)
        self.assertIn("acf.Area = nil", source)
        self.assertIn("acf.Health = nil", source)
        self.assertIn("ent.ACE_PrimitiveLegacyArmorSettings = CopyLegacyArmorSettings(source and source.EntityMods)", source)
        self.assertIn("if ent.ACE_PrimitiveLegacyArmorSettings then return end", source)

    def test_advdupe_finalizes_snapshots_after_paste(self):
        source = SOURCE.read_text(encoding="utf-8")
        hook = re.search(
            r'hook.Add\("AdvDupe_FinishPasting", "ACE_CapturePrimitiveArmor", function\(data\)(?P<body>.*?)\nend\)',
            source,
            re.DOTALL,
        )

        self.assertIsNotNone(hook)
        self.assertIn("FinalizePrimitiveArmor(ent)", hook.group("body"))
        self.assertNotIn("timer.Simple", hook.group("body"))

    def test_only_pastes_preserve_a_pre_rebuild_snapshot(self):
        source = SOURCE.read_text(encoding="utf-8")

        capture = re.search(
            r"local function CapturePendingPrimitiveArmor\(ent\)(?P<body>.*?)\nend",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(capture)
        self.assertIn("not ent.ACE_PrimitiveRestoreSavedArmor", capture.group("body"))


if __name__ == "__main__":
    unittest.main()
