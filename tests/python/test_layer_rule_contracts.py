"""Offline source-contract tests for ACE armor durability and kinetic gating."""

from pathlib import Path
import unittest


LUA = Path(__file__).resolve().parents[2] / "lua"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


class KineticDamageGateContracts(unittest.TestCase):
    def test_layer_reduction_is_not_present(self):
        sources = [
            LUA / "autorun" / "acf_globals.lua",
            LUA / "ace" / "server" / "sv_acfbase.lua",
            LUA / "ace" / "server" / "sv_acfdamage.lua",
        ]
        sources.extend(sorted((LUA / "ace" / "shared" / "rounds").glob("round*.lua")))
        body = "\n".join(read(path) for path in sources)
        self.assertNotIn("KELayerArmorMul", body)
        self.assertNotIn("KENotFirstPen", body)
        self.assertNotIn("ArmorMul )", body)

    def test_kinetic_types_are_central_and_non_kinetic_types_are_not_classified(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_functions.lua")
        for round_type in ("AP", "APDS", "APFSDS", "APHE", "CAP", "FL", "HP", "HVAP"):
            self.assertIn(f"\n\t{round_type} = true", body)
        for round_type in ("HE", "HEAT", "HESH", "Spall"):
            self.assertNotIn(f"\n\t{round_type} = true", body)

    def test_gate_is_shared_and_blocks_before_prop_mutation(self):
        base = read(LUA / "ace" / "server" / "sv_acfbase.lua")
        self.assertIn("KineticThresholdFailed", base)
        self.assertIn("if HitRes.KineticThresholdFailed then", base)
        self.assertLess(base.index("KineticThresholdFailed = true"), base.index("Entity:TakeDamage"))
        self.assertIn("ACE.KineticDamageThreshold", base)
        self.assertIn("local energyRatio = maxPenetration / requiredPenetration", base)

    def test_round_impact_restores_the_shared_post_penetration_shape(self):
        damage = read(LUA / "ace" / "server" / "sv_acfdamage.lua")
        self.assertLess(damage.index("local HitRes\t= ACE.Damage"), damage.index("HitRes.PostPenetration = ACE.GetPostPenetration"))


class ArmorPricingCompensationContracts(unittest.TestCase):
    def test_points_model_undoes_mass_scaled_health(self):
        body = read(LUA / "ace" / "shared" / "sh_ace_points_model.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm * (ACE.ArmorMod or 1) / armourMm"), 1)

    def test_tool_preview_undoes_mass_scaled_health(self):
        body = read(LUA / "weapons" / "gmod_tool" / "stools" / "acearmorprop.lua")
        self.assertEqual(body.count("hp = hp * ACE.HealthRefmm / armor"), 1)


if __name__ == "__main__":
    unittest.main()
