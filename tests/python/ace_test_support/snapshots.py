"""Small, explicit snapshot contracts for ACE test artifacts.

Snapshots are projections of public fields, not copies of arbitrary runtime tables.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from math import isclose
from typing import Any, Mapping


@dataclass(frozen=True)
class SnapshotSpec:
    name: str
    fields: tuple[str, ...]
    tolerances: Mapping[str, float] = field(default_factory=dict)
    precision: int = 6


def _normalize(value: Any, precision: int) -> Any:
    if isinstance(value, float):
        return round(value, precision)
    if isinstance(value, Mapping):
        return {
            key: _normalize(value[key], precision)
            for key in sorted(value)
        }
    if isinstance(value, (list, tuple)):
        return [_normalize(item, precision) for item in value]
    return value


def project_snapshot(observed: Mapping[str, Any], spec: SnapshotSpec) -> dict[str, Any]:
    """Return only the named, normalized public fields for a snapshot."""
    missing = [field for field in spec.fields if field not in observed]
    if missing:
        raise KeyError(f"{spec.name}: missing snapshot fields: {', '.join(missing)}")

    return {
        field: _normalize(observed[field], spec.precision)
        for field in spec.fields
    }


def compare_snapshot(
    expected: Mapping[str, Any],
    observed: Mapping[str, Any],
    spec: SnapshotSpec,
) -> list[str]:
    """Return human-readable differences; an empty list means the snapshot passes."""
    expected_view = project_snapshot(expected, spec)
    observed_view = project_snapshot(observed, spec)
    differences = []

    for field in spec.fields:
        expected_value = expected_view[field]
        observed_value = observed_view[field]
        tolerance = spec.tolerances.get(field)

        if tolerance is not None and isinstance(expected_value, (int, float)) and isinstance(observed_value, (int, float)):
            if isclose(expected_value, observed_value, abs_tol=tolerance, rel_tol=0.0):
                continue

        if expected_value != observed_value:
            suffix = f" ± {tolerance}" if tolerance is not None else ""
            differences.append(
                f"{field}: expected {expected_value!r}{suffix}, observed {observed_value!r}"
            )

    return differences


def snapshot_failure(spec: SnapshotSpec, differences: list[str]) -> str:
    """Format a focused failure without dumping unrelated runtime state."""
    lines = [f"Snapshot failed: {spec.name}"]
    lines.extend(f"- {difference}" for difference in differences)
    return "\n".join(lines)
