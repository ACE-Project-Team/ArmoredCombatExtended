"""Strict offline validation and summary helpers for ACE path-profile artifacts."""

from __future__ import annotations

from dataclasses import dataclass
import math
import statistics
from typing import Any


REQUIRED = {
    "schema", "run_id", "path_id", "scenario_id", "mode", "provenance", "workload",
    "correctness", "timing", "memory", "teardown", "attribution",
}
PROVENANCE = {
    "ace_commit", "branch", "dependency_commits", "mounted_addons", "harness_revision",
    "process_id", "map", "tick_interval", "gprofiler_revision",
}
MODES = {"correctness", "timing", "attribution", "scaling", "soak"}
MEASUREMENT_FIELDS = {"p50_ms", "p95_ms", "p99_ms", "p999_ms", "max_ms", "hitches"}


def _finite(value: Any) -> bool:
    return isinstance(value, (int, float)) and math.isfinite(value)


def validate_artifact(artifact: dict) -> None:
    missing = REQUIRED - set(artifact)
    if missing:
        raise ValueError(f"missing artifact keys: {sorted(missing)}")
    if artifact["schema"] != 2:
        raise ValueError("unsupported path-profile artifact schema")
    if artifact["mode"] not in MODES:
        raise ValueError(f"unsupported profile mode: {artifact['mode']}")
    if not PROVENANCE <= set(artifact["provenance"]):
        raise ValueError("incomplete artifact provenance")
    workload = artifact["workload"]
    for key in ("fixture_id", "fixture_hash", "seed", "target_operations", "completed_operations", "duration_seconds"):
        if key not in workload:
            raise ValueError(f"missing workload field: {key}")
    if workload["target_operations"] != workload["completed_operations"]:
        raise ValueError("incomplete operation count")
    if not _finite(workload["duration_seconds"]) or workload["duration_seconds"] <= 0:
        raise ValueError("invalid workload duration")
    timing = artifact["timing"]
    if not MEASUREMENT_FIELDS <= set(timing):
        raise ValueError("incomplete timing measurements")
    if any(not _finite(timing[key]) for key in MEASUREMENT_FIELDS - {"hitches"}):
        raise ValueError("non-finite timing measurement")
    if not isinstance(timing["hitches"], dict) or any(not isinstance(value, int) or value < 0 for value in timing["hitches"].values()):
        raise ValueError("invalid hitch counts")
    memory = artifact["memory"]
    if not {"lua_heap_before_kb", "lua_heap_peak_kb", "lua_heap_after_gc_kb"} <= set(memory):
        raise ValueError("incomplete Lua heap measurements")
    if any(not _finite(memory[key]) or memory[key] < 0 for key in memory if key.startswith("lua_heap_")):
        raise ValueError("invalid Lua heap measurement")
    teardown = artifact["teardown"]
    if teardown.get("passed") is not True:
        raise ValueError("cleanup invariant did not pass")
    if any(value != 0 for key, value in teardown.get("deltas", {}).items() if key not in {"allowed_transient"}):
        raise ValueError("non-zero teardown delta")
    attribution = artifact["attribution"]
    if artifact["mode"] in {"correctness", "timing", "scaling", "soak"} and attribution.get("profiler_active"):
        raise ValueError("profiler must be inactive for non-attribution mode")
    if artifact["mode"] == "attribution" and not attribution.get("views"):
        raise ValueError("attribution mode requires profiler views")
    if artifact["mode"] in {"correctness", "timing", "scaling", "soak"} and not artifact["correctness"].get("timer_canary_passed"):
        raise ValueError("timer canary did not pass")


@dataclass(frozen=True)
class Summary:
    path_id: str
    scenario_id: str
    mode: str
    repetitions: int
    median_ms_per_operation: float
    p95_ms: float
    max_ms: float
    max_hitches_over_25ms: int
    post_gc_delta_kb: float


def summarize(artifacts: list[dict]) -> Summary:
    if not artifacts:
        raise ValueError("cannot summarize an empty artifact set")
    for artifact in artifacts:
        validate_artifact(artifact)
    first = artifacts[0]
    signatures = {(item["path_id"], item["scenario_id"], item["mode"]) for item in artifacts}
    if len(signatures) != 1:
        raise ValueError("cannot combine different path/scenario/mode artifacts")
    per_operation = [item["timing"]["active_ms"] / item["workload"]["completed_operations"] for item in artifacts]
    post_gc = [item["memory"]["lua_heap_after_gc_kb"] - item["memory"]["lua_heap_before_kb"] for item in artifacts]
    return Summary(
        first["path_id"], first["scenario_id"], first["mode"], len(artifacts),
        statistics.median(per_operation), statistics.median(item["timing"]["p95_ms"] for item in artifacts),
        max(item["timing"]["max_ms"] for item in artifacts),
        max(item["timing"]["hitches"].get("over_25ms", 0) for item in artifacts),
        statistics.median(post_gc),
    )
