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
        self.assertTrue(all("HitVec:GetNormalized()" in expression for expression in end_positions))
        self.assertTrue(all("SpallRes.HitNormal" not in expression for expression in end_positions))

    def test_all_recursive_retries_preserve_incoming_direction(self):
        recursive_calls = re.findall(r"ACF_SpallTrace\((.*?)\)", self.body)

        self.assertEqual(len(recursive_calls), 3)
        self.assertTrue(all(re.match(r"\s*HitVec\s*,", call) for call in recursive_calls))
        self.assertNotIn("ACF_SpallTrace( SpallRes.HitPos", self.body)

    def test_trace_has_no_shared_penetration_assignment_before_copy(self):
        self.assertEqual(self.body.count("SpallEnergy = table.Copy(SpallEnergy)"), 1)
        self.assertGreaterEqual(self.body.count("SpallEnergy.Penetration ="), 2)

    def test_original_fragment_callers_remain_compatible(self):
        callers = re.findall(r"ACF_SpallTrace\(HitVec, Index", self.source)

        self.assertGreaterEqual(len(callers), 2)


if __name__ == "__main__":
    unittest.main()
