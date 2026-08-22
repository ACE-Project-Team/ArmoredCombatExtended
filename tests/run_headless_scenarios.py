"""Headless ACE scenario runner scaffold.

This runner is deliberately fail-closed: without an explicit srcds command it validates the manifest
and reports which scenarios are selected, but it does not pretend to execute gameplay. CI can use the
dry-run path for contract coverage while local/headless automation supplies the server command.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]

sys.path.insert(0, str(REPO / "tests" / "python"))
from test_runtime_artifact_schema import validate_artifact


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
        "run_id": run_dir.name,
        "repo": str(REPO),
        "branch": git_output("branch", "--show-current") or "detached-HEAD",
        "ace_commit": git_output("rev-parse", "HEAD"),
        "started_at": int(time.time()),
        "scenarios": scenarios,
    }
    (run_dir / "manifest_resolved.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")


def scenarios_from_manifest(path: Path) -> list[dict]:
    return json.loads(path.read_text(encoding="utf-8"))["scenarios"]


def stop_process_tree(process: subprocess.Popen, force: bool = False) -> None:
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(process.pid), "/T", "/F"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    process_group = getattr(process, "ace_process_group", None)
    if process_group is None:
        try:
            process_group = os.getpgid(process.pid)
        except ProcessLookupError:
            process_group = None
    if process_group is not None:
        try:
            os.killpg(process_group, signal.SIGKILL if force else signal.SIGTERM)
        except ProcessLookupError:
            pass
        return
    if force and process.poll() is None:
        process.kill()
    else:
        process.terminate()


def validate_run_artifacts(run_dir: Path, scenarios: list[dict], run_context: dict | None = None) -> None:
    for scenario in scenarios:
        for artifact_name in scenario.get("artifacts", []):
            artifact_path = run_dir / artifact_name
            if not artifact_path.is_file():
                raise SystemExit(f"Headless run missing declared artifact: {artifact_name}")
            if artifact_path.suffix.lower() == ".json":
                artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
                validate_artifact(artifact)
                if run_context:
                    for key in ("run_id", "ace_commit", "branch"):
                        if artifact[key] != run_context[key]:
                            raise SystemExit(f"Headless artifact {artifact_name} is not bound to this run's {key}")
                if artifact["scenario_id"] != scenario["id"]:
                    raise SystemExit(f"Artifact scenario mismatch: {artifact_name}")
                event_types = [event["type"] for event in artifact["events"]]
                expected_events = scenario.get("expected_events", [])
                cursor = 0
                for event_type in event_types:
                    if cursor < len(expected_events) and event_type == expected_events[cursor]:
                        cursor += 1
                if cursor < len(expected_events):
                    raise SystemExit(
                        f"Headless artifact {artifact_name} is missing ordered events: {', '.join(expected_events[cursor:])}"
                    )
                if artifact["errors"]:
                    raise SystemExit(f"Headless artifact reports errors: {artifact_name}")


def validate_console(run_dir: Path) -> None:
    console = run_dir / "console.log"
    if console.is_file() and any(
        marker in console.read_text(encoding="utf-8", errors="replace")
        for marker in ("Lua Error", "[ERROR]")
    ):
        raise SystemExit("Headless run console contains a Lua/runtime error")


def run_server(command: list[str], run_dir: Path, timeout: int) -> int:
    boot = run_dir / "boot.txt"
    done = run_dir / "done.txt"
    log = run_dir / "console.log"
    environment = os.environ.copy()
    environment["ACE_HEADLESS_RUN_DIR"] = str(run_dir)
    environment["ACE_HEADLESS_MANIFEST"] = str(run_dir / "manifest_resolved.json")
    environment["ACE_HEADLESS_SCENARIO_TIMEOUTS"] = json.dumps({
        scenario["id"]: scenario["timeout_seconds"]
        for scenario in scenarios_from_manifest(run_dir / "manifest_resolved.json")
    }, sort_keys=True)
    completed = False

    with log.open("w", encoding="utf-8", errors="replace") as handle:
        process = subprocess.Popen(
            command,
            stdout=handle,
            stderr=subprocess.STDOUT,
            cwd=REPO,
            env=environment,
            start_new_session=(os.name != "nt"),
        )
        if os.name != "nt":
            process.ace_process_group = process.pid
        try:
            deadline = time.time() + timeout
            while time.time() < deadline:
                if done.exists():
                    time.sleep(1.0)
                    if process.poll() is None:
                        stop_process_tree(process)
                        process.wait(timeout=5)
                        completed = True
                    else:
                        completed = process.returncode == 0
                    break
                if process.poll() is not None:
                    break
                time.sleep(0.25)
            else:
                raise TimeoutError("headless scenario runner timed out before done sentinel")
        finally:
            stop_process_tree(process, force=True)
            if process.poll() is None:
                process.wait(timeout=10)

    if not boot.exists():
        raise SystemExit("Headless run did not write boot sentinel")
    if not done.exists():
        raise SystemExit("Headless run did not write done sentinel")
    resolved_manifest = json.loads((run_dir / "manifest_resolved.json").read_text(encoding="utf-8"))
    scenarios = resolved_manifest["scenarios"]
    validate_run_artifacts(run_dir, scenarios, resolved_manifest)
    errors = run_dir / "errors.txt"
    if errors.is_file() and errors.read_text(encoding="utf-8", errors="replace").strip():
        raise SystemExit("Headless run reported errors in errors.txt")
    validate_console(run_dir)
    if completed:
        return 0
    return process.returncode or 1


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

        timeout = sum(scenario["timeout_seconds"] for scenario in scenarios) + 30
        return run_server(args.srcds_command, run_dir, timeout)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
