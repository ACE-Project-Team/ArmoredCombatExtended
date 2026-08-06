"""Contracts for accepted path-profile artifacts and offline aggregation."""

from __future__ import annotations

import unittest

from path_profile_artifacts import summarize, validate_artifact


def artifact(mode="timing", completed=100):
    return {
        "schema": 2, "run_id": "run-1", "path_id": "surface-1", "scenario_id": "combat_core", "mode": mode,
        "provenance": {
            "ace_commit": "abc", "branch": "dev", "dependency_commits": {}, "mounted_addons": [],
            "harness_revision": "h1", "process_id": "p1", "map": "gm_construct", "tick_interval": 0.015,
            "gprofiler_revision": "none",
        },
        "workload": {
            "fixture_id": "fixture", "fixture_hash": "hash", "seed": 1, "target_operations": completed,
            "completed_operations": completed, "duration_seconds": 1.0,
        },
        "correctness": {"timer_canary_passed": True},
        "timing": {
            "active_ms": 10.0, "p50_ms": 1.0, "p95_ms": 2.0, "p99_ms": 3.0, "p999_ms": 4.0,
            "max_ms": 5.0, "hitches": {"over_25ms": 0, "over_50ms": 0, "over_100ms": 0},
        },
        "memory": {"lua_heap_before_kb": 10, "lua_heap_peak_kb": 12, "lua_heap_after_gc_kb": 10},
        "teardown": {"passed": True, "deltas": {}},
        "attribution": {"profiler_active": mode == "attribution", "views": ["Functions"] if mode == "attribution" else []},
    }


class PathProfileArtifactTests(unittest.TestCase):
    def test_valid_timing_artifact(self):
        validate_artifact(artifact())

    def test_timing_rejects_profiler_overhead(self):
        value = artifact()
        value["attribution"]["profiler_active"] = True
        with self.assertRaises(ValueError):
            validate_artifact(value)

    def test_incomplete_workload_is_rejected(self):
        value = artifact(completed=99)
        value["workload"]["target_operations"] = 100
        with self.assertRaises(ValueError):
            validate_artifact(value)

    def test_summary_is_normalized_per_operation(self):
        first = artifact()
        second = artifact()
        second["run_id"] = "run-2"
        second["timing"]["active_ms"] = 20.0
        result = summarize([first, second])
        self.assertEqual(2, result.repetitions)
        self.assertAlmostEqual(0.15, result.median_ms_per_operation)


if __name__ == "__main__":
    unittest.main()

