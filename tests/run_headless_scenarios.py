"""Headless ACE scenario runner scaffold.

This runner is deliberately fail-closed: without an explicit srcds command it validates the manifest
and reports which scenarios are selected, but it does not pretend to execute gameplay. CI can use the
dry-run path for contract coverage while local/headless automation supplies the server command.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time


REPO = Path(__file__).resolve().parents[1]


def git_output(*args: str) -> str:
    return subprocess.check_output(["git", "-C", str(REPO), *args], text=True).strip()


def load_manifest(path: Path) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("schema") != 1:
        raise SystemExit("Unsupported scenario manifest schema")
    if not manifest.get("scenarios"):
        raise SystemExit("Scenario manifest has no scenarios")
    return manifest


def selected_scenarios(manifest: dict, ci: bool) -> list[dict]:
    scenarios = [
        scenario
        for scenario in manifest["scenarios"]
        if scenario["realm"] == "headless" and (scenario.get("ci", False) or not ci)
    ]
    if not scenarios:
        raise SystemExit("No headless scenarios selected")
    return scenarios


def write_resolved_manifest(run_dir: Path, scenarios: list[dict]) -> None:
    payload = {
        "schema": 1,
        "repo": str(REPO),
        "branch": git_output("branch", "--show-current"),
        "ace_commit": git_output("rev-parse", "HEAD"),
        "started_at": int(time.time()),
        "scenarios": scenarios,
    }
    (run_dir / "manifest_resolved.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def run_server(command: list[str], run_dir: Path, timeout: int) -> int:
    boot = run_dir / "boot.txt"
    done = run_dir / "done.txt"
    log = run_dir / "console.log"

    with log.open("w", encoding="utf-8", errors="replace") as handle:
        process = subprocess.Popen(command, stdout=handle, stderr=subprocess.STDOUT, cwd=REPO)
        try:
            deadline = time.time() + timeout
            while time.time() < deadline:
                if done.exists():
                    return process.wait(timeout=5)
                if process.poll() is not None:
                    break
                time.sleep(0.25)
            raise TimeoutError("headless scenario runner timed out before done sentinel")
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)

    if not boot.exists():
        raise SystemExit("Headless run did not write boot sentinel")
    if not done.exists():
        raise SystemExit("Headless run did not write done sentinel")
    return process.returncode or 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", default="tests/fixtures/general_use_manifest.json")
    parser.add_argument("--ci", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--srcds-command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)

    manifest = load_manifest(REPO / args.manifest)
    scenarios = selected_scenarios(manifest, args.ci)

    with tempfile.TemporaryDirectory(prefix="ace-headless-") as tmp:
        run_dir = Path(tmp)
        write_resolved_manifest(run_dir, scenarios)

        if args.dry_run or not args.srcds_command:
            print(f"Selected {len(scenarios)} headless scenario(s); dry-run only")
            return 0

        timeout = max(scenario["timeout_seconds"] for scenario in scenarios) + 30
        return run_server(args.srcds_command, run_dir, timeout)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
