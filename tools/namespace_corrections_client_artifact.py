"""Bind a live-client probe result to the exact local source and console evidence."""

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


EXPECTED_CLIENT_FUNCTIONS = {
    "ACE.CalcArmor", "ACE.GetMaterialData", "ACE.RenderLight", "ACE.RemoveBulletClient", "ACE.EmitSound",
}
EXPECTED_CLIENT_HOOKS = {
    "Think:ACE_VignetteFade", "Think:ACE_Think_SpeedOfSound", "Think:ACE_ManageBulletEffects",
    "HUDPaint:ACE_VignetteDraw", "PostDrawOpaqueRenderables:ACE_RenderDamage",
    "InitPostEntity:ACE_RefreshScalables", "NetworkEntityCreated:ACE_RefreshScalables_FullUpdate",
    "SpawnMenuOpen:ACEPermissionsSpawnMenuOpen", "SpawnMenuOpen:ACE.SpawnMenuOpen.*",
}
EXPECTED_CLIENT_ENTITIES = {
    "acf_ammo", "acf_engine", "acf_gearbox", "acf_fueltank", "acf_gun", "acf_rack",
    "ace_ammo", "ace_engine", "ace_gearbox", "ace_fueltank", "ace_gun", "ace_rack",
    "ace_crewseat_driver", "ace_searchradar", "ace_missile",
}
EXPECTED_CLIENT_CONVARS = {
    "ace_enable_lighting", "ace_sens_irons", "ace_sens_scopes", "ace_tinnitus",
    "ace_sound_volume", "ace_mobility_rope_links", "ace_tool_category",
}
EXPECTED_CLIENT_TOOLS = {"acemenu", "acearmorprop", "acechaircam", "acecopy", "acesound"}
EXPECTED_CLIENT_EFFECTS = {
    "ace_ap_impact", "ace_ap_penetration", "ace_ap_ricochet", "ace_bulleteffect",
    "ace_cookoff_puff", "ace_heat_explosion", "ace_missilelaunch", "ace_muzzleflash",
    "ace_racklaunch", "ace_radar_noise", "ace_scaled_detonation", "ace_scaled_explosion",
    "ace_smoke",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(repo: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def source_manifest(repo: Path) -> tuple[str, int]:
    rows: list[str] = []
    count = 0
    for root_name in ("lua", "tests", "tools"):
        root = repo / root_name
        if not root.exists():
            continue
        for path in sorted(p for p in root.rglob("*") if p.is_file()):
            relative = path.relative_to(repo).as_posix()
            if (
                any(part in {".git", "artifacts", "__pycache__"} for part in path.parts)
                or path.suffix in {".pyc", ".pyo"}
            ):
                continue
            rows.append(f"{relative}\t{sha256_bytes(path.read_bytes())}")
            count += 1
    return sha256_bytes("\n".join(rows).encode()), count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--raw", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--console-log", type=Path, required=True)
    parser.add_argument("--console-output", type=Path, required=True)
    parser.add_argument("--console-marker", default="[ACE | INFO]- loading ACE")
    parser.add_argument("--client-command", required=True)
    parser.add_argument("--map", default="gm_construct")
    parser.add_argument("--acf-extras-temporarily-disabled", action="store_true")
    parser.add_argument("--addon-mount", type=Path, default=Path(r"C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\addons\ArmoredCombatExtended"))
    args = parser.parse_args()

    for stale in (args.output, args.output.with_name(args.output.stem + "-raw.json"), args.console_output):
        if stale.exists():
            stale.unlink()

    raw_bytes = args.raw.read_bytes()
    result = json.loads(raw_bytes)
    checks = result.get("checks", [])
    run_id = result.get("run_id")
    if result.get("finished") is not True:
        raise SystemExit("client probe did not finish")
    if result.get("boot") is not True:
        raise SystemExit("client probe boot sentinel is not true")
    if not isinstance(run_id, str) or not run_id:
        raise SystemExit("client probe has no run id")
    if result.get("output_file") != f"ace_namespace_client_probe_{run_id}.json":
        raise SystemExit("client probe output file is not bound to its run id")
    if result.get("realm") != "client":
        raise SystemExit("client probe realm sentinel is missing")
    surface = build_surface(args.repo)
    expected_checks = {
        "ACE table", "ACE has no compatibility metatable", "ACE client public function table is populated",
        *(f"{name}" for name in EXPECTED_CLIENT_FUNCTIONS),
        *(f"registered ACE client hook {name}" for name in EXPECTED_CLIENT_HOOKS),
        *(f"source ACE function {name}" for name in surface["functions"]["client"]),
        *(f"source registered hook {spec['event']}:{spec['identifier']}" for spec in surface["hooks"]["client"]),
        *(f"client scripted entity {name}" for name in EXPECTED_CLIENT_ENTITIES),
        *(f"client ACE convar {name}" for name in EXPECTED_CLIENT_CONVARS),
        *(f"client ACE tool {name}" for name in EXPECTED_CLIENT_TOOLS),
        *(f"client ACE tool {name} has interaction callback" for name in EXPECTED_CLIENT_TOOLS),
        *(f"client ACE tool {name} has panel builder" for name in EXPECTED_CLIENT_TOOLS),
        *(f"client ACE effect {name}" for name in EXPECTED_CLIENT_EFFECTS),
        *(f"client ACE effect {name} has lifecycle" for name in EXPECTED_CLIENT_EFFECTS),
        "client ACE missile menu configuration is callable",
    }
    if Counter(check.get("name") for check in checks) != Counter(expected_checks):
        raise SystemExit("client probe check category contract changed")
    if len(checks) != len(expected_checks):
        raise SystemExit("client probe check count contract changed")
    if any(check.get("ok") is not True for check in checks):
        raise SystemExit("client probe contains failed checks")
    console_text = args.console_log.read_text(encoding="utf-8", errors="replace")
    run_marker = "[ACE_NAMESPACE_CLIENT_PROBE] run_id=" + run_id
    run_position = console_text.rfind(run_marker)
    marker_index = console_text.rfind(args.console_marker, 0, run_position + len(run_marker))
    if marker_index < 0:
        raise SystemExit(f"console marker not found: {args.console_marker!r}")
    excerpt = console_text[marker_index:]
    if run_marker not in excerpt:
        raise SystemExit("client probe run id is not present in the matching console excerpt")

    manifest_hash, manifest_files = source_manifest(args.repo)
    if result.get("source_manifest_sha256") != manifest_hash:
        raise SystemExit("client probe source manifest does not match the current source snapshot")
    if Path(os.path.realpath(args.addon_mount)).resolve() != args.repo.resolve():
        raise SystemExit("client ACE addon mount does not resolve to the reviewed repository")
    diff_bytes = subprocess.check_output(["git", "-C", str(args.repo), "diff", "--binary", "HEAD"])
    error_lines = [
        line for line in excerpt.splitlines()
        if (
            "attempt to" in line
            or "Lua Error" in line
            or "[ERROR]" in line
            or "Error!" in line
            or "Error in " in line
            or "KeyValues Error" in line
        )
    ]
    ace_error_lines = [
        line for line in error_lines
        if "addons/armoredcombatextended" in line.lower() or "[ace" in line.lower()
    ]
    if ace_error_lines:
        raise SystemExit("ACE client console contains errors")
    args.console_output.parent.mkdir(parents=True, exist_ok=True)
    args.console_output.write_text(excerpt, encoding="utf-8")
    result["evidence"] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "git_head": git(args.repo, "rev-parse", "HEAD"),
        "worktree_diff_sha256": sha256_bytes(diff_bytes),
        "worktree_state_sha256": sha256_bytes(diff_bytes + manifest_hash.encode()),
        "source_manifest_sha256": manifest_hash,
        "source_manifest_algorithm": "sorted relative-path + per-file SHA-256 rows over lua/tests/tools",
        "source_manifest_file_count": manifest_files,
        "raw_probe_sha256": sha256_bytes(raw_bytes),
        "console_excerpt_sha256": sha256_bytes(excerpt.encode()),
        "console_marker": args.console_marker,
        "run_id": run_id,
        "run_marker": run_marker,
        "client_command": args.client_command,
        "map": args.map,
        "runtime_realm": "client",
        "addon_mount": str(args.addon_mount),
        "addon_mount_resolved": str(Path(os.path.realpath(args.addon_mount)).resolve()),
        "acf_extras_temporarily_disabled": args.acf_extras_temporarily_disabled,
        "check_count": len(checks),
        "passing_checks": sum(1 for check in checks if check.get("ok") is True),
        "console_error_lines": error_lines,
        "ace_console_error_lines": ace_error_lines,
        "external_console_error_lines": [line for line in error_lines if line not in ace_error_lines],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    raw_copy = args.output.with_name(args.output.stem + "-raw.json")
    raw_copy.write_bytes(raw_bytes)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result["evidence"], indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
