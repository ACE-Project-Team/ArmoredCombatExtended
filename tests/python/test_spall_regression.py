"""Offline regression tests for ACE's directional, layered spall traces.

The source checks protect the exact GLua contract.  The small oracle below models only the
load-bearing state transitions in ACF_SpallTrace: each fragment starts with the same energy,
its own trace consumes energy across layers, and retries keep the incoming direction.
It intentionally does not pretend to replace a native GMod damage test.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re
import unittest


SOURCE = (
    Path(__file__).resolve().parents[2]
    / "lua"
    / "acf"
    / "server"
    / "sv_acfdamage.lua"
)
RUBBER_SOURCE = SOURCE.parents[1] / "shared" / "armor" / "rubber.lua"
BALLISTICS_SOURCE = SOURCE.with_name("sv_acfballistics.lua")
MISSILE_SOURCE = SOURCE.parents[2] / "autorun" / "server" / "sv_acf_missiles.lua"


@dataclass(frozen=True)
class Layer:
    """A deterministic layer in the reduced spall-energy oracle."""

    name: str
    penetration_cost: float
    normal_x: float


def trace_fragment(
    initial_penetration: float,
    layers: list[Layer],
    direction_x: float,
    use_surface_normal: bool = False,
) -> tuple[float, list[float]]:
    """Trace one fragment while preserving its direction and private energy budget."""

    penetration = initial_penetration
    directions: list[float] = []

    for layer in layers:
        directions.append(layer.normal_x if use_surface_normal else direction_x)
        penetration = max(penetration - layer.penetration_cost, 0.0)

    return penetration, directions


def trace_fragments(
    initial_penetration: float,
    layers: list[Layer],
    fragment_count: int,
    isolated_energy: bool,
) -> list[tuple[float, list[float]]]:
    """Compare per-fragment state with the historical shared-table behavior."""

    shared_penetration = initial_penetration
    results = []

    for _ in range(fragment_count):
        start = initial_penetration if isolated_energy else shared_penetration
        result = trace_fragment(start, layers, direction_x=1.0)
        results.append(result)
        if not isolated_energy:
            shared_penetration = result[0]

    return results


def apply_resolver_loss(penetration: float, kinetic: float, loss: float) -> tuple[float, float]:
    """Apply ACE's HitRes.Loss contract once to one fragment's private energy."""

    remaining = min(max(1.0 - loss, 0.0), 1.0)
    return penetration * remaining, kinetic * remaining


def rubber_spall_cost(thickness: float) -> float:
    """Model the material's spall RHAe input before the standard resolver."""

    return thickness**0.93 * 0.15


def trace_rubber_layers(initial_penetration: float, thicknesses: list[float]) -> float:
    """Deterministic strong-penetration path through ordinary rubber spall armor."""

    penetration = initial_penetration
    for thickness in thicknesses:
        penetration = max(penetration - rubber_spall_cost(thickness), 0.0)
    return penetration


class SpallOracleTests(unittest.TestCase):
    def test_single_fragment_preserves_energy_accounting_across_layers(self):
        layers = [Layer("front steel", 12, -1), Layer("rubber", 8, -1)]

        remaining, directions = trace_fragment(100, layers, direction_x=1)

        self.assertEqual(remaining, 80)
        self.assertEqual(directions, [1, 1])

    def test_each_fragment_starts_from_original_energy(self):
        layers = [Layer("front steel", 12, -1), Layer("rubber", 8, -1)]

        results = trace_fragments(100, layers, fragment_count=32, isolated_energy=True)

        self.assertEqual({remaining for remaining, _ in results}, {80})
        self.assertTrue(all(directions == [1, 1] for _, directions in results))

    def test_shared_energy_regression_is_detectable(self):
        layers = [Layer("front steel", 12, -1), Layer("rubber", 8, -1)]

        results = trace_fragments(100, layers, fragment_count=32, isolated_energy=False)

        self.assertEqual(results[0][0], 80)
        self.assertEqual(results[1][0], 60)
        self.assertEqual(results[-1][0], 0)

    def test_user_story_apfsds_front_armor_then_45mm_rubber(self):
        layers = [Layer("120 mm APFSDS target plate", 18, -1), Layer("45 mm rubber", 9, -1)]

        results = trace_fragments(100, layers, fragment_count=128, isolated_energy=True)

        self.assertEqual(len(results), 128)
        self.assertEqual({remaining for remaining, _ in results}, {73})
        self.assertTrue(all(directions == [1, 1] for _, directions in results))

    def test_user_story_rubber_sandwich_keeps_each_fragment_independent(self):
        layers = [
            Layer("front RHA", 12, -1),
            Layer("20 mm rubber", 8, -1),
            Layer("inner RHA", 12, -1),
            Layer("25 mm rubber", 8, -1),
        ]

        results = trace_fragments(100, layers, fragment_count=128, isolated_energy=True)

        self.assertEqual({remaining for remaining, _ in results}, {60})

    def test_user_story_repeated_128_fragment_bursts_are_stable(self):
        layers = [Layer("front RHA", 15, -1), Layer("rubber", 10, -1)]

        for burst in range(10):
            with self.subTest(burst=burst):
                results = trace_fragments(100, layers, fragment_count=128, isolated_energy=True)
                self.assertEqual({remaining for remaining, _ in results}, {75})

    def test_user_story_empty_gap_does_not_consume_energy_or_change_direction(self):
        layers = [Layer("front RHA", 10, -1), Layer("empty gap", 0, -1), Layer("rubber", 5, -1)]

        remaining, directions = trace_fragment(100, layers, direction_x=1)

        self.assertEqual(remaining, 85)
        self.assertEqual(directions, [1, 1, 1])

    def test_surface_normal_control_case_reproduces_historical_bounce(self):
        layers = [Layer("armor exit", 0, -1)]

        _, fixed_directions = trace_fragment(100, layers, direction_x=1)
        _, historical_directions = trace_fragment(100, layers, direction_x=1, use_surface_normal=True)

        self.assertEqual(fixed_directions, [1])
        self.assertEqual(historical_directions, [-1])

    def test_layer_matrix_does_not_change_fragment_independence(self):
        materials = [
            Layer("RHA", 12, -1),
            Layer("cast", 10, -1),
            Layer("rubber", 8, -1),
            Layer("ceramic", 6, -1),
            Layer("textolite", 4, -1),
        ]

        for split in range(len(materials) + 1):
            with self.subTest(split=split):
                layers = materials[:split]
                results = trace_fragments(100, layers, fragment_count=16, isolated_energy=True)
                expected = max(100 - sum(layer.penetration_cost for layer in layers), 0)
                self.assertEqual({remaining for remaining, _ in results}, {expected})

    def test_zero_layer_trace_is_a_noop(self):
        results = trace_fragments(100, [], fragment_count=8, isolated_energy=True)

        self.assertEqual(results, [(100, [])] * 8)

    def test_zero_energy_cannot_become_positive(self):
        layers = [Layer("rubber", 0, -1), Layer("rubber", 10, -1)]

        results = trace_fragments(0, layers, fragment_count=8, isolated_energy=True)

        self.assertEqual({remaining for remaining, _ in results}, {0})

    def test_resolver_loss_reduces_both_energy_fields_once(self):
        penetration, kinetic = apply_resolver_loss(100, 80, 0.25)

        self.assertEqual((penetration, kinetic), (75, 60))

    def test_resolver_loss_is_not_applied_twice_for_one_impact(self):
        penetration, kinetic = apply_resolver_loss(100, 80, 0.25)

        self.assertEqual((penetration, kinetic), (75, 60))
        self.assertNotEqual(penetration, 56.25)
        self.assertNotEqual(kinetic, 45)

    def test_rubber_spall_is_thickness_scaled_and_not_a_flat_kill_switch(self):
        fifteen = trace_rubber_layers(20, [15])
        forty_five = trace_rubber_layers(20, [45])

        self.assertGreater(fifteen, 0)
        self.assertGreater(forty_five, 0)
        self.assertLess(forty_five, fifteen)

    def test_layered_rubber_consumes_the_same_fragment_budget_sequentially(self):
        one_layer = trace_rubber_layers(20, [45])
        two_layers = trace_rubber_layers(20, [45, 45])

        self.assertGreater(one_layer, 0)
        self.assertGreater(two_layers, 0)
        self.assertLess(two_layers, one_layer)

    def test_rubber_does_not_revert_to_the_old_spall_special_resilience(self):
        self.assertAlmostEqual(rubber_spall_cost(15), 1.861, places=2)
        self.assertAlmostEqual(rubber_spall_cost(45), 5.173, places=2)
        self.assertGreater(trace_rubber_layers(20, [15]), 18)


class SpallSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")
        match = re.search(
            r"function ACF_SpallTrace\(.*?\n(?P<body>.*?)\nend\n\n--Calculates the vector",
            cls.source,
            re.DOTALL,
        )
        if not match:
            raise AssertionError("ACF_SpallTrace body could not be located")
        cls.body = match.group("body")
        cls.rubber_source = RUBBER_SOURCE.read_text(encoding="utf-8")

    def test_trace_owns_a_copy_before_mutating_penetration(self):
        copy_pos = self.body.index("SpallEnergy = table.Copy(SpallEnergy)")
        mutation_pos = self.body.index("SpallEnergy.Penetration =")

        self.assertLess(copy_pos, mutation_pos)

    def test_both_continuation_paths_use_incoming_direction(self):
        end_positions = re.findall(
            r"ACE\.Spall\[Index\]\.endpos\s*=\s*(.+)",
            self.body,
        )

        self.assertEqual(len(end_positions), 2)
        self.assertTrue(all("SpallDirection" in expression for expression in end_positions))
        self.assertTrue(all("SpallRes.HitNormal" not in expression for expression in end_positions))

    def test_all_recursive_retries_preserve_incoming_direction(self):
        recursive_calls = re.findall(r"ACF_SpallTrace\((.*?)\)", self.body)

        self.assertEqual(len(recursive_calls), 2)
        self.assertTrue(all(re.match(r"\s*SpallDirection\s*,", call) for call in recursive_calls))
        self.assertNotIn("ACF_SpallTrace( SpallRes.HitPos", self.body)

    def test_fragment_direction_comes_from_current_trace_with_legacy_fallback(self):
        self.assertIn("local SpallDirection = HitVec:GetNormalized()", self.body)
        self.assertIn("SpallDirection = (SpallTrace.endpos - SpallTrace.start):GetNormalized()", self.body)

    def test_trace_has_no_shared_penetration_assignment_before_copy(self):
        self.assertEqual(self.body.count("SpallEnergy = table.Copy(SpallEnergy)"), 1)
        self.assertGreaterEqual(self.body.count("SpallEnergy.Penetration ="), 2)

    def test_resolver_loss_is_applied_once_before_the_single_retry(self):
        self.assertEqual(self.body.count("local PostPenetration = ACF_GetPostPenetration"), 1)
        self.assertEqual(self.body.count("SpallEnergy.Kinetic = PostPenetration.RemainingKinetic"), 1)
        self.assertEqual(self.body.count("SpallEnergy.Penetration = PostPenetration.RemainingPenetration"), 1)
        self.assertEqual(self.body.count("-- Retry"), 1)

    def test_kill_path_does_not_spawn_a_second_retry(self):
        kill_block = re.search(r"if HitRes\.Kill then(?P<body>.*?)end\n\n\t\t-- Applies a decal", self.body, re.DOTALL)

        self.assertIsNotNone(kill_block)
        self.assertNotIn("ACF_SpallTrace", kill_block.group("body"))
        self.assertIn("Debris = ACF_APKill", kill_block.group("body"))

    def test_killed_plate_can_continue_when_residual_energy_remains(self):
        self.assertIn("local PostPenetration = ACF_GetPostPenetration", self.body)
        self.assertIn("PostPenetration.Continue", self.body)

    def test_killed_plate_still_stops_when_resolver_consumes_all_energy(self):
        continuation = re.search(r"if PostPenetration\.Continue then", self.body)
        self.assertIsNotNone(continuation)

    def test_rubber_uses_default_spall_resolution_with_material_effectiveness(self):
        self.assertIn("Material.spallresist = 0.15", self.rubber_source)
        self.assertIn('if Type == "Spall" then\n\t\t\teffectiveness = Material.spallresist', self.rubber_source)
        valid_types = re.search(r"local validTypes = \{(?P<body>.*?)\n\t\t\}", self.rubber_source, re.DOTALL)

        self.assertIsNotNone(valid_types)
        self.assertNotIn('["Spall"]', valid_types.group("body"))
        self.assertNotIn("specialresiliance = Material.spallresist", self.rubber_source)

    def test_rubber_preserves_non_spall_overmatch_behavior(self):
        self.assertIn("local breachCaliber = Type == \"Spall\" and caliber or caliber * 10", self.rubber_source)

    def test_original_fragment_callers_remain_compatible(self):
        callers = re.findall(r"ACF_SpallTrace\(HitVec, Index", self.source)

        self.assertGreaterEqual(len(callers), 2)

    def test_post_penetration_contract_is_shared_by_round_impact(self):
        self.assertIn("function ACF_GetPostPenetration( HitRes, Energy )", self.source)
        self.assertIn("HitRes.PostPenetration = ACF_GetPostPenetration( HitRes, Energy )", self.source)

    def test_ricochet_is_finalized_before_killing_the_target(self):
        ricochet = self.source.index("HitRes.Ricochet = true")
        kill = self.source.index("local Debris = ACF_APKill", ricochet)
        self.assertLess(ricochet, kill)

    def test_ricochet_keeps_incoming_energy_for_the_shared_contract(self):
        ricochet = re.search(
            r"if ricoProb < math\.Rand\(0,1\).*?\n\tend\n\n\t-- Record the selected outcome",
            self.source,
            re.DOTALL,
        )
        self.assertIsNotNone(ricochet)
        self.assertNotIn("Energy.Kinetic =", ricochet.group(0))
        self.assertIn("HitRes.Loss\t= 1 - Ricochet", ricochet.group(0))

    def test_selected_ricochet_is_not_reclassified_by_target_validity_or_cap(self):
        selected = re.search(
            r"-- Record the selected outcome.*?if Ricochet > 0 and Bullet\.Ricochets < 5",
            self.source,
            re.DOTALL,
        )
        self.assertIsNotNone(selected)
        self.assertIn("HitRes.RicochetSelected = true", selected.group(0))

    def test_killing_ricochet_uses_shared_remaining_kinetic(self):
        kill = re.search(
            r"if HitRes\.Kill and IsValid\(Target\) then\s+local KillPower = HitRes\.RicochetSelected and HitRes\.PostPenetration\.RemainingKinetic or Energy\.Kinetic\s+local Debris = ACF_APKill",
            self.source,
            re.DOTALL,
        )
        self.assertIsNotNone(kill)

    def test_heat_spall_uses_shared_spent_energy_with_its_existing_multiplier(self):
        heat = (SOURCE.parents[1] / "shared" / "rounds" / "roundheat.lua").read_text(encoding="utf-8")
        self.assertIn("HitRes.PostPenetration.IncomingKinetic * 0.75", heat)

    def test_damage_queries_use_path_specific_bounded_candidate_snapshots(self):
        self.assertIn("function ACF_HEFind( Hitpos, Radius )", self.source)
        self.assertIn("function ACF_HEFindCritical(Hitpos, RadiusSq)", self.source)
        self.assertIn("function ACF_InsertNearestDamageCandidate(", self.source)
        self.assertIn("ents.FindInSphere(Hitpos, Radius)", self.source)
        self.assertIn("ACE.DamageQueryLimits.HECandidates", self.source)
        self.assertIn("ACE.DamageQueryLimits.HELOSTraces", self.source)
        self.assertIn("ACE.DamageQueryStats.CandidateQueries", self.source)
        self.assertIn("ACE.DamageQueryStats.CandidatesAccepted", self.source)
        self.assertIn("function ACF_GetDamageQueryStats()", self.source)
        self.assertIn("function ACF_ResetDamageQueryStats()", self.source)
        self.assertIn("for _, Entity in ipairs(ACE.critEnts) do", self.source)
        self.assertIn("for _, Entity in ipairs(ents.FindInSphere(Hitpos, Radius)) do", self.source)
        self.assertNotIn("function ACF_GetDamageCandidates( Origin, Radius, Predicate, Limit )", self.source)
        self.assertNotIn("for _, ent in pairs( ACE.critEnts ) do", self.source)

    def test_he_damage_math_is_separate_from_candidate_and_trace_selection(self):
        self.assertIn("function ACF_HECalculateTargetDamage(", self.source)
        self.assertIn("DamageData = ACF_HECalculateTargetDamage(", self.source)
        self.assertIn('local RetryLOSBudget = { Limit = ACE.DamageQueryLimits.HELOSTraces', self.source)
        self.assertIn("local FragmentVelocity = math.max(BaseFragVel", self.source)
        self.assertIn("FragmentHit = 1", self.source)

    def test_hesh_and_he_filters_are_copied_before_mutation(self):
        self.assertIn("local OccFilter\t= ACF_CopyDamageFilter(NoOcc)", self.source)
        self.assertIn("local EntsToHit\t= ACF_CopyDamageFilter(Filter)", self.source)
        self.assertIn("local Temp_Filter = ACF_CopyDamageFilter(Filter)", self.source)
        self.assertIn("function ACF_AddDamageFilter( Filter, Entity )", self.source)

    def test_fragment_and_hesh_los_budgets_are_explicit(self):
        self.assertIn("Fragments = 128", self.source)
        self.assertIn("HESHIterations = 128", self.source)
        self.assertIn("ExplosionLOSTraces = 512", self.source)
        self.assertIn("FragmentsQueued = 0", self.source)
        self.assertIn("ExplosionCandidates = 0", self.source)
        self.assertIn('StatKey = "ExplosionLOSTraces"', self.source)
        self.assertIn("function ACF_ConsumeDamageQueryBudget( Budget )", self.source)
        self.assertIn("math.min(math.floor(Caliber * ACF.KEtoSpall", self.source)
        self.assertIn("math.min(math.floor(Caliber * math.sqrt(EquivalentFillerKg)", self.source)

    def test_scaled_explosion_iterates_a_snapshot_before_live_registry_removal(self):
        self.assertIn("for _, Found in ipairs(ACE.Explosives) do", self.source)
        self.assertIn("ACE.RemoveExplosive(Found)", self.source)
        self.assertIn("ACF_InsertNearestDamageCandidate(PendingExplosives", self.source)
        self.assertIn("ACF_InsertNearestDamageCandidate(NewExplosives", self.source)
        self.assertNotIn("CExplosives[#CExplosives + 1] = Found", self.source)
        self.assertNotIn("table.remove( CExplosives,i )", self.source)

    def test_round_handlers_use_the_shared_post_penetration_decision(self):
        rounds = list((SOURCE.parents[1] / "shared" / "rounds").glob("round*.lua"))
        handlers = []
        for path in rounds:
            source = path.read_text(encoding="utf-8")
            if "ACF_RoundImpact" in source and "if HitRes.PostPenetration.Continue then" in source:
                handlers.append(path.name)

        expected = {
            "roundap.lua", "roundapds.lua", "roundapfsds.lua", "roundaphe.lua",
            "roundfl.lua", "roundglgm.lua", "roundheat.lua", "roundheatfs.lua",
            "roundhvap.lua", "roundtheat.lua", "roundtheatfs.lua",
        }
        self.assertEqual(set(handlers), expected)

    def test_ballistics_scheduler_uses_pooled_state_and_active_iteration(self):
        source = BALLISTICS_SOURCE.read_text(encoding="utf-8")
        self.assertIn("function ACF_AcquireBullet(BulletData)", source)
        self.assertIn("local BulletPool = {}", source)
        self.assertIn("function ACF_RegisterBullet(Index, Bullet)", source)
        self.assertIn("local ActiveBullets = {}", source)
        self.assertIn("while Slot <= ActiveCount do", source)
        self.assertIn("Bullet.ActiveFrame ~= Frame", source)
        self.assertIn("BulletData.ActiveFrame = CurrentBallisticsFrame", source)
        self.assertIn("if ActiveBullets[Slot] == Index then", source)
        self.assertIn("function ACE.GetBallisticsStats()", source)
        self.assertIn("function ACE.ResetBallisticsStats()", source)
        self.assertIn("hook.Run(\"ACFOnBulletRemoved\", Index, Bullet)", source)
        self.assertLess(
            source.index('hook.Run("ACFOnBulletRemoved", Index, Bullet)'),
            source.index("table.insert(BulletPool, Bullet)", source.index('hook.Run("ACFOnBulletRemoved", Index, Bullet)')),
        )
        self.assertNotIn("for Index,Bullet in pairs(ACF.Bullet) do", source)
        self.assertNotIn("ACF.Bullet[ACF.CurBulletIndex] = table.Copy(BulletData)", source)

    def test_ballistics_work_and_debug_limits_are_explicit(self):
        source = BALLISTICS_SOURCE.read_text(encoding="utf-8")
        missile = MISSILE_SOURCE.read_text(encoding="utf-8")
        self.assertIn("VisibilityRetries = 50", source)
        self.assertIn("Impacts = 100", source)
        self.assertIn("visCount < ACE.BallisticsLimits.VisibilityRetries", source)
        self.assertIn("Bullet.ImpactCount > ACE.BallisticsLimits.Impacts", source)
        self.assertIn("local DebugConVar = GetConVar(\"acf_ballistics_debug\")", source)
        self.assertIn("if BallisticsDebug() then", source)
        self.assertIn("ACF_AcquireBullet(BulletData)", missile)
        self.assertIn("ACF_RegisterBullet(ACF.CurBulletIndex, BulletData)", missile)

    def test_explosive_registry_removal_keeps_its_index_map_consistent(self):
        contraption = (SOURCE.parent / "sv_contraption.lua").read_text(encoding="utf-8")
        self.assertIn("function ACE.RemoveExplosive(Entity)", contraption)
        self.assertIn("ACE.RemoveExplosive(explosive)", contraption)
        self.assertIn("ACE.Explosives        = {}", contraption)
        self.assertIn("ACE.ExplosiveIndex    = {}", contraption)
        self.assertNotIn("table.remove(ACE.Explosives", contraption)


class TheatDamageContractTests(unittest.TestCase):
    SOURCE = (
        Path(__file__).resolve().parents[2]
        / "lua"
        / "acf"
        / "server"
        / "sv_acfdamage.lua"
    )

    @classmethod
    def setUpClass(cls):
        cls.source = cls.SOURCE.read_text(encoding="utf-8")

    def test_tandem_impact_normal_has_a_safe_fallback(self):
        self.assertIn("function ACF_GetHitAngle( HitNormal , HitVector )", self.source)
        self.assertIn("HitNormal:LengthSqr() < 0.0001", self.source)
        self.assertIn("return 0", self.source)


if __name__ == "__main__":
    unittest.main()
