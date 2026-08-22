"""Human-readable failure text shared by migrated scenario tests."""

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class Scenario:
    id: str
    title: str


def scenario_failure(
    scenario: Scenario,
    step: str,
    expected: str,
    observed: str,
    context: Iterable[str] = (),
) -> str:
    """Return a short failure that explains the broken player-facing step."""
    lines = [
        f"[{scenario.id}] {scenario.title}",
        f"Step: {step}",
        f"Expected: {expected}",
        f"Observed: {observed}",
    ]
    details = list(context)
    if details:
        lines.append("Context: " + "; ".join(details))
    return "\n".join(lines)
