"""Offline source-contract tests for the armor durability and layering bundle.

Locks the load-bearing GLua contracts of the change. Round files are enumerated from
disk and classified by their own source, so a new or missed kinetic round fails the
suite instead of silently skipping the layer rule (the HVAP gap the first hardcoded
list could not catch).
"""

from __future__ import annotations

from pathlib import Path
import unittest


LUA = Path(__file__).resolve().parents[2] / "lua"
ROUNDS = LUA / "ace" / "shared" / "rounds"

TOLL = "RemainingKinetic * ACE.KEPenLayerMul * 2000"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def classified_rounds():
    """Yield (name, body, is_heat) for every round file with a kinetic continuation."""
    for path in sorted(ROUNDS.glob("round*.lua")):
        body = read(path)
        if "PostPenetration.RemainingKinetic" not in body:
            continue
        is_heat = "ACE.HEATPenLayerMul" in body
        yield path.name, body, is_heat


class KineticLayerRuleContracts(unittest.TestCase):
    def test_enumeration_sees_the_known_round_families(self):
        names = {name for name, _, _ in classified_rounds()}
        self.assertIn("roundap.lua", names)
        self.assertIn("roundhvap.lua", names)
        self.assertIn("roundheat.lua", names)

    def test_every_kinetic_continuation_pays_the_layer_toll(self):
        kinetic = [(n, b) for n, b, heat in classified_rounds() if not heat]
        self.assertGreaterEqual(len(kinetic), 6)
        for name, body in kinetic:
            self.assertEqual(
                body.count(TOLL), 1,
                f"{name} has a kinetic continuation and must charge ACE.KEPenLayerMul exactly once",
            )

    def test_heat_family_keeps_its_own_layer_rule(self):
        heat = [(n, b) for n, b, is_heat in classified_rounds() if is_heat]
        self.assertGreaterEqual(len(heat), 5)
        for name, body in heat:
            self.assertNotIn(
                "ACE.KEPenLayerMul", body,
                f"{name} is HEAT-family and must keep ACE.HEATPenLayerMul, not the KE rule",
            )
        self.assertTrue(
            any("ACE.HEATPenLayerMul" in body for _, body in heat),
            "the HEAT family must still consume ACE.HEATPenLayerMul",
        )


class ArmorPricingCompensationContracts(unittest.TestCase):
    def test_points_model_undoes_mass_scaled_health(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_points_model.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm * (ACE.ArmorMod or 1) / armourMm"), 1)

    def test_tool_preview_undoes_mass_scaled_health(self):
        body = read(LUA / "weapons" / "gmod_tool" / "stools" / "acearmorprop.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm / armor"), 1)


if __name__ == "__main__":
    unittest.main()
