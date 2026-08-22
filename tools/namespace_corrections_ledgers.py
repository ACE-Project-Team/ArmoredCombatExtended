"""Generate explicit, reviewable migration ledgers from the namespace inventory."""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
from pathlib import Path


def write_csv(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def is_source_file(path: Path) -> bool:
    return path.is_file() and not any(
        part in {".git", "artifacts", "__pycache__"} for part in path.parts
    ) and path.suffix not in {".pyc", ".pyo"}


def function_classification(row: dict) -> tuple[str, str]:
    """Assign an explicit owner category without pretending unresolved APIs are migrated."""
    path = row["file"]
    if row["disposition"] in {"ACE.table", "local ACE_*"}:
        return row["disposition"], "inventory-confirmed"
    if path.startswith(("lua/starfall/", "lua/entities/gmod_wire_expression2/", "lua/cfw/")):
        return "external consumer", "review-required"
    if path.startswith(("lua/entities/", "lua/weapons/", "lua/effects/", "lua/autorun/")):
        return "GMod framework callback", "review-required" if row["scope"] != "local" else "inventory-confirmed"
    if row["scope"] in {"ace-flat-global", "legacy-acf-global", "legacy-acf-local"}:
        return "canonical API candidate", "review-required"
    return "canonical helper candidate", "review-required"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--inventory", type=Path, default=Path("artifacts/namespace-corrections/inventory.json"))
    parser.add_argument("--output", type=Path, default=Path("docs/namespace-corrections"))
    args = parser.parse_args()
    repo = args.repo.resolve()
    inventory_path = args.inventory if args.inventory.is_absolute() else repo / args.inventory
    output = args.output if args.output.is_absolute() else repo / args.output
    data = json.loads(inventory_path.read_text(encoding="utf-8"))

    function_rows = []
    for row in data["all_functions"]:
        category, status = function_classification(row)
        function_rows.append({**row, "category": category, "status": status})
    write_csv(output / "function-ledger.csv", ["file", "line", "name", "scope", "disposition", "category", "kind", "realm", "status"], function_rows)
    legacy_by_file: dict[str, int] = {}
    for row in data["legacy_refs"]:
        legacy_by_file[row["file"]] = legacy_by_file.get(row["file"], 0) + 1
    paths = []
    for path in data["files"]:
        legacy_count = legacy_by_file.get(path, 0)
        rename_candidate = Path(path).name.lower().startswith("acf_") or "/acf" in path.lower()
        paths.append({
            "old_path": path,
            "new_path": f"{path[:-len(Path(path).name)]}ace_{Path(path).name[4:]}" if rename_candidate and Path(path).name.lower().startswith("acf_") else path,
            "loader": "GMod addon loader",
            "realm": "static-path-classification",
            "legacy_token_count": legacy_count,
            "path_decision": "rename-candidate" if rename_candidate else "retain-candidate",
            "status": "review-required" if rename_candidate or legacy_count else "inventory-confirmed",
        })
    write_csv(output / "path-ledger.csv", ["old_path", "new_path", "loader", "realm", "legacy_token_count", "path_decision", "status"], paths)

    entity_rows = []
    entities = repo / "lua" / "entities"
    for path in sorted(p for p in entities.iterdir() if p.is_dir()):
        entity_files = [p for p in path.rglob("*.lua") if is_source_file(p)]
        state_refs = sum(
            len(re.findall(r"\.ACF\b", text))
            for text in (p.read_text(encoding="utf-8", errors="replace") for p in entity_files)
        )
        rename_candidate = path.name.lower().startswith("acf_")
        entity_rows.append({
            "old_class": path.name,
            "new_class": "ace_" + path.name[4:] if rename_candidate else path.name,
            "state": "Entity.ACF references: " + str(state_refs),
            "dupe": "unverified",
            "decision": "rename-candidate" if rename_candidate else "retain-candidate",
            "status": "review-required" if rename_candidate or state_refs else "inventory-confirmed",
        })
    write_csv(output / "entity-ledger.csv", ["old_class", "new_class", "state", "dupe", "decision", "status"], entity_rows)

    integration_roots = [
        ("starfall", "starfall"),
        ("e2", "entities/gmod_wire_expression2"),
        ("wire", "wire"),
        ("cfw", "cfw"),
        ("tools", "weapons/gmod_tool/stools"),
    ]
    integration_rows = []
    for label, root_name in integration_roots:
        root = repo / "lua" / root_name
        if root.exists():
            files = sorted(p.relative_to(repo).as_posix() for p in root.rglob("*.lua"))
            legacy_count = sum(legacy_by_file.get(path, 0) for path in files)
            integration_rows.append({
                "integration": label,
                "files": len(files),
                "legacy_token_count": legacy_count,
                "contract": "legacy-boundary-review" if legacy_count else "no-legacy-token-found",
                "status": "review-required" if legacy_count else "inventory-confirmed",
            })
        else:
            integration_rows.append({"integration": label, "files": 0, "legacy_token_count": 0, "contract": "not-present", "status": "inventory-confirmed"})
    write_csv(output / "integration-ledger.csv", ["integration", "files", "legacy_token_count", "contract", "status"], integration_rows)

    test_rows = []
    for path in sorted(p.relative_to(repo).as_posix() for p in (repo / "tests").rglob("*") if is_source_file(p)):
        if path.endswith(".py") and "/python/" in path:
            runner = "python -m unittest discover -s tests/python -p 'test_*.py'"
        elif path.endswith("_selftest.lua"):
            runner = "python tests/run_luajit_tests.py ."
        elif "/client/" in path:
            runner = "live client probe"
        elif "/headless/" in path:
            runner = "live dedicated-server probe"
        elif "/gluatest" in path:
            runner = "native GLuaTest suite"
        else:
            runner = "fixture-specific runner required"
        test_rows.append({
            "old_assertion": path,
            "new_assertion": path,
            "fixture": runner,
            "status": "runner-defined" if "required" not in runner else "review-required",
        })
    write_csv(output / "test-ledger.csv", ["old_assertion", "new_assertion", "fixture", "status"], test_rows)

    head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
    write_csv(output / "rollback-ledger.csv", ["commit", "dependency", "failure_trigger", "reversal_command", "known_good_reference", "status"], [{
        "commit": head,
        "dependency": "upstream/dev",
        "failure_trigger": "Any parity or namespace contract failure",
        "reversal_command": "git revert <repair-commit>",
        "known_good_reference": "runtime-probe.json and client-probe.json",
        "status": "review-required",
    }])
    print(f"generated ledgers under {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
