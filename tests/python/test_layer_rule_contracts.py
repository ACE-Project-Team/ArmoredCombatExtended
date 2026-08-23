"""Offline source-contract tests for the armor durability and layering bundle.

Locks the load-bearing GLua contracts of the change. Round files are enumerated from
disk and classified by their own source, so a new or missed kinetic round fails the
suite instead of silently skipping the layer rule (the HVAP gap a hardcoded list
could not catch).

The layer rule is armor-side, matching real firing tests where layered steel
underperforms one monolithic plate against solid shot: kinetic rounds flag
themselves after their first penetration, and later plates resist that shot at
ACE.KELayerArmorMul inside the damage resolution.
"""

from __future__ import annotations

from pathlib import Path
import unittest


LUA = Path(__file__).resolve().parents[2] / "lua"
ROUNDS = LUA / "ace" / "shared" / "rounds"

FLAG = "Bullet.KENotFirstPen = true"


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

    def test_every_kinetic_round_flags_its_first_penetration(self):
        kinetic = [(n, b) for n, b, heat in classified_rounds() if not heat]
        self.assertGreaterEqual(len(kinetic), 6)
        for name, body in kinetic:
            self.assertEqual(
                body.count(FLAG), 1,
                f"{name} has a kinetic continuation and must set KENotFirstPen exactly once",
            )

    def test_heat_family_keeps_its_own_layer_rule(self):
        heat = [(n, b) for n, b, is_heat in classified_rounds() if is_heat]
        self.assertGreaterEqual(len(heat), 5)
        for name, body in heat:
            self.assertNotIn(
                "KENotFirstPen", body,
                f"{name} is HEAT-family and must keep ACE.HEATPenLayerMul, not the KE armor rule",
            )

    def test_no_round_charges_the_withdrawn_energy_toll(self):
        for name, body, _ in classified_rounds():
            self.assertNotIn(
                "ACE.KEPenLayerMul", body,
                f"{name} charges the withdrawn energy toll, which inverted the physics",
            )

    def test_damage_chain_applies_the_armor_side_rule(self):
        impact = read(LUA / "ace" / "server" / "sv_acfdamage.lua")
        self.assertEqual(impact.count("Bullet.KENotFirstPen and ACE.KELayerArmorMul or 1"), 1)
        self.assertEqual(impact.count('Bullet["Type"], ArmorMul )'), 1)  # RoundImpact actually passes it
        base = read(LUA / "ace" / "server" / "sv_acfbase.lua")
        self.assertEqual(base.count("losArmor = losArmor * (ArmorMul or 1)"), 1)
        self.assertEqual(base.count("Type, ArmorMul)"), 4)  # PropDamage call in Damage, CalcDamage sig, PropDamage sig, CalcDamage call in PropDamage


class ArmorPricingCompensationContracts(unittest.TestCase):
    def test_points_model_undoes_mass_scaled_health(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_points_model.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm * (ACE.ArmorMod or 1) / armourMm"), 1)

    def test_tool_preview_undoes_mass_scaled_health(self):
        body = read(LUA / "weapons" / "gmod_tool" / "stools" / "acearmorprop.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm / armor"), 1)


if __name__ == "__main__":
    unittest.main()
