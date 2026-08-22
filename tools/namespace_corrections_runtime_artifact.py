"""Bind a current dedicated-server ACE probe result to source and console evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from namespace_corrections_surface import build_surface
from namespace_corrections_integrations import build_manifest as build_integration_manifest


EXPECTED_SERVER_FUNCTIONS = {
    "ACE.CalcArmor", "ACE.CheckLegal", "ACE.GetMaterialData", "ACE.GetWeaponUser",
    "ACE.MarkArmorDirty", "ACE.NotifyPointsInvalidated", "ACE.EnsurePointsState",
    "ACE.Missile_BulletLaunch", "ACE.Missile_ExpandBulletData", "ACE.AcquireBullet",
    "ACE.RegisterBullet", "ACE.BulletClient",
}
EXPECTED_SERVER_HOOKS = {
    "ACE_BulletDamage", "ACE_PlayerChangedZone", "ACE_ProtectionModeChanged",
    "AdvDupe_FinishPasting", "CleanUpMap", "EntityRemoved", "InitPostEntity", "Initialize",
    "OnEntityCreated", "PhysgunPickup", "PlayerAuthed", "PlayerDisconnected",
    "PlayerEnteredVehicle", "PlayerFrozeObject", "PlayerInitialSpawn", "PlayerNoClip",
    "PlayerSpawnedSENT", "PlayerSpawnedSWEP", "PlayerSpawnedVehicle", "PlayerUnfrozeObject",
    "Primitive_PostRebuildPhysics", "Primitive_PreRebuildPhysics", "ProperClippingClipAdded",
    "ProperClippingPhysicsClipped", "ProperClippingPhysicsReset", "Think", "Tick",
    "cfw.contraption.created", "cfw.contraption.entityAdded", "cfw.contraption.entityRemoved",
    "cfw.contraption.merged", "cfw.contraption.removed", "cfw.contraption.split",
    "cfw.family.added", "cfw.family.created", "cfw.family.subbed",
}
EXPECTED_SERVER_ENTITIES = {
    "acf_ammo", "acf_engine", "acf_gearbox", "acf_fueltank", "acf_gun", "acf_rack",
    "ace_ammo", "ace_engine", "ace_gearbox", "ace_fueltank", "ace_gun", "ace_rack",
    "ace_crewseat_driver", "ace_searchradar", "ace_missile",
}
EXPECTED_SERVER_SPAWNS = {
    "acf_engine": "3.2-B4", "acf_gearbox": "1Gear-T-S", "acf_fueltank": "Tank_4x4x2",
    "acf_gun": "100mmC", "acf_ammo": "Shell100mm", "acf_rack": "1xRK",
}
EXPECTED_SERVER_CONVARS = {
    "sbox_max_ace_gun", "sbox_max_ace_ammo", "sbox_max_ace_rack", "sbox_max_ace_crewseat",
    "sbox_max_ace_explosive", "ace_mines_max", "ace_legality_enginesrequirefuel",
    "ace_legalcheck", "ace_enable_dp", "ace_gunfire", "ace_spalling",
}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def manifest(repo: Path) -> tuple[str, int]:
    rows = []
    for root_name in ("lua", "tests", "tools"):
        root = repo / root_name
        if not root.exists():
            continue
        for path in sorted(p for p in root.rglob("*") if p.is_file()):
            if (
                "artifacts" in path.parts
                or ".git" in path.parts
                or "__pycache__" in path.parts
                or path.suffix in {".pyc", ".pyo"}
            ):
                continue
            rel = path.relative_to(repo).as_posix()
            rows.append(f"{rel}\t{sha256(path.read_bytes())}")
    text = "\n".join(rows).encode()
    return sha256(text), len(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--raw", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--console-log", type=Path, required=True)
    parser.add_argument("--console-output", type=Path, required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--map", default="gm_construct")
    parser.add_argument("--addon-mount", type=Path, default=Path(r"C:\Users\dabes\gmodds\server\garrysmod\addons\ArmoredCombatExtended"))
    args = parser.parse_args()

    for stale in (args.output, args.output.with_name(args.output.stem + "-raw.json"), args.console_output):
        if stale.exists():
            stale.unlink()

    raw = args.raw.read_bytes()
    result = json.loads(raw)
    checks = result.get("checks", [])
    gluatest = result.get("gluatest", {}) or {}
    run_id = result.get("run_id")
    if result.get("finished") is not True:
        raise SystemExit("runtime probe did not finish")
    if result.get("boot") is not True:
        raise SystemExit("runtime probe boot sentinel is not true")
    if result.get("realm") != "server":
        raise SystemExit("runtime probe realm sentinel is missing")
    if not isinstance(run_id, str) or not run_id:
        raise SystemExit("runtime probe has no run id")
    if result.get("output_file") != f"ace_namespace_runtime_probe_{run_id}.json":
        raise SystemExit("runtime probe output file is not bound to its run id")
    if not checks:
        raise SystemExit("runtime probe contains no checks")
    if any(check.get("ok") is not True for check in checks):
        raise SystemExit("runtime probe contains failed checks")
    if len(result.get("spawned", [])) != 6 or any(item.get("ok") is not True for item in result["spawned"]):
        raise SystemExit("runtime probe did not verify all six factory spawns")
    if not isinstance(gluatest, dict) or gluatest.get("groups", 0) <= 0 or gluatest.get("failures") != 0:
        raise SystemExit("GLuaTest reported failures")
    bullet_events = result.get("bullet_events", {})
    if bullet_events.get("creation") != 1:
        raise SystemExit("runtime probe did not verify one probe-gun bullet creation")
    if bullet_events.get("removed") != 1:
        raise SystemExit("runtime probe did not verify one probe-gun bullet removal")
    check_counts = Counter(check.get("name") for check in checks)
    surface = build_surface(args.repo)
    expected_names = {
        "ACE table", "ACE has no compatibility metatable", "ACE public function table is populated",
        *(f"registered hook {name}" for name in EXPECTED_SERVER_HOOKS),
        *(f"source ACE function {name}" for name in surface["functions"]["server"]),
        *(f"source registered hook {spec['event']}:{spec['identifier']}" for spec in surface["hooks"]["server"]),
        *(f"scripted entity {name}" for name in EXPECTED_SERVER_ENTITIES),
        "spawn tank owner prop", "spawn representative tank assembly", "spawn gunner seat for fire test",
        "tank entities use canonical ACE state",
        "link spawned gunner to gun", "link spawned gun to ammo", "linked ammo is loadable",
        "gun retained ammo link", "load linked ammo into gun", "fire linked gun shell",
        "bullet creation hook fired once", "create CFW tank contraption", "CFW tank contraption contains all parts",
        "tank owner has CFW contraption", "disconnect CFW tank links", "defuse CFW tank contraption",
        "exercise CFW tank lifecycle",
        "duplicator CopyEnts API", "duplicator Paste API", "copy ACE gun and ammo for dupe",
        "paste ACE gun and ammo", "pasted ACE gun is present", "pasted ACE ammo is present",
        "pasted gun uses canonical ACE state", "pasted ammo uses canonical ACE state",
        "pasted gun retains ammo link", "exercise real duplicator round-trip",
        *(f"server ACE convar {name}" for name in EXPECTED_SERVER_CONVARS),
        "Starfall ACE library registered",
        *(f"spawn {name} through factory" for name in EXPECTED_SERVER_SPAWNS),
        *(f"activate {name}" for name in EXPECTED_SERVER_SPAWNS),
        "tank part linked to CFW contraption",
    }
    integrations = build_integration_manifest(args.repo)
    expected_names.add("ACE integration manifest loaded")
    expected_counts = Counter(expected_names)
    expected_counts.update(
        f"E2 ACE function {name} registered" for name in integrations["e2"]["names"]
    )
    expected_counts.update({"tank part linked to CFW contraption": 5})
    expected_counts.update(EXPECTED_SERVER_FUNCTIONS)
    if check_counts != expected_counts:
        raise SystemExit("runtime probe check count/category contract changed")
    if len(checks) != sum(expected_counts.values()):
        raise SystemExit("runtime probe check count contract changed")
    spawned = {item.get("class"): item.get("id") for item in result["spawned"]}
    if spawned != EXPECTED_SERVER_SPAWNS:
        raise SystemExit("runtime probe factory spawn mapping changed")
    console = args.console_log.read_text(encoding="utf-8", errors="replace")
    marker = "[ACE | INFO]- loading ACE"
    run_marker = "[ACE_NAMESPACE_RUNTIME_PROBE] run_id=" + run_id
    run_position = console.rfind(run_marker)
    start = console.rfind(marker, 0, run_position + len(run_marker))
    if start < 0:
        raise SystemExit("ACE load marker not found in server console")
    excerpt = console[start:]
    if run_marker not in excerpt:
        raise SystemExit("runtime probe run id is not present in the matching console excerpt")

    manifest_hash, file_count = manifest(args.repo)
    if result.get("source_manifest_sha256") != manifest_hash:
        raise SystemExit("runtime probe source manifest does not match the current source snapshot")
    if Path(os.path.realpath(args.addon_mount)).resolve() != args.repo.resolve():
        raise SystemExit("server ACE addon mount does not resolve to the reviewed repository")
    diff = subprocess.check_output(["git", "-C", str(args.repo), "diff", "--binary", "HEAD"])
    errors = [
        line for line in excerpt.splitlines()
        if "attempt to" in line or "Lua Error" in line or "[ERROR]" in line or "Error!" in line or "Error in " in line
    ]
    ace_errors = [line for line in errors if "addons/armoredcombatextended" in line.lower() or "[ace" in line.lower()]
    if ace_errors:
        raise SystemExit("ACE runtime console contains errors")
    args.console_output.parent.mkdir(parents=True, exist_ok=True)
    args.console_output.write_text(excerpt, encoding="utf-8")
    raw_copy = args.output.with_name(args.output.stem + "-raw.json")
    raw_copy.write_bytes(raw)
    result["evidence"] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "git_head": git(args.repo, "rev-parse", "HEAD"),
        "worktree_diff_sha256": sha256(diff),
        "worktree_state_sha256": sha256(diff + manifest_hash.encode()),
        "source_manifest_sha256": manifest_hash,
        "source_manifest_algorithm": "sorted relative-path + per-file SHA-256 rows over lua/tests/tools",
        "source_manifest_file_count": file_count,
        "raw_probe_sha256": sha256(raw),
        "console_excerpt_sha256": sha256(excerpt.encode()),
        "console_marker": marker,
        "run_id": run_id,
        "run_marker": run_marker,
        "server_command": args.command,
        "server_executable": "C:\\Users\\dabes\\gmodds\\server\\srcds.exe",
        "map": args.map,
        "runtime_realm": "dedicated-server",
        "addon_mount": str(args.addon_mount),
        "addon_mount_resolved": str(Path(os.path.realpath(args.addon_mount)).resolve()),
        "console_error_lines": errors,
        "ace_console_error_lines": ace_errors,
        "external_console_error_lines": [line for line in errors if line not in ace_errors],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["evidence"], indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
