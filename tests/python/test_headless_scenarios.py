import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
from run_headless_scenarios import discover_local_srcds, stop_process_tree, validate_console, validate_run_artifacts


class HeadlessScenarioRunnerTests(unittest.TestCase):
    def artifact(self, scenario_id="tank_duel_ap", events=None, errors=None):
        return {
            "schema": 1,
            "run_id": "test-run",
            "scenario_id": scenario_id,
            "ace_commit": "test",
            "branch": "test",
            "started_at": "start",
            "finished_at": "finish",
            "events": [{"type": event} for event in (events or ["fire", "impact", "damage", "terminate"])],
            "errors": errors or [],
        }

    def scenario(self):
        return [{"id": "tank_duel_ap", "artifacts": ["tank_duel_ap.json"], "expected_events": ["fire", "impact", "damage", "terminate"]}]

    def test_artifact_schema_and_expected_events_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "tank_duel_ap.json").write_text(json.dumps(self.artifact()), encoding="utf-8")
            validate_run_artifacts(root, self.scenario())

            (root / "tank_duel_ap.json").write_text(json.dumps(self.artifact(events=["fire"])), encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "missing .*events"):
                validate_run_artifacts(root, self.scenario())

    def test_malformed_or_error_artifacts_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "tank_duel_ap.json"
            path.write_text("{}", encoding="utf-8")
            with self.assertRaises(AssertionError):
                validate_run_artifacts(root, self.scenario())
            path.write_text(json.dumps(self.artifact(errors=[{"type": "runtime", "message": "boom"}])), encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "reports errors"):
                validate_run_artifacts(root, self.scenario())
            malformed = self.artifact(errors=[])
            malformed["events"] = ["not an event object"]
            path.write_text(json.dumps(malformed), encoding="utf-8")
            with self.assertRaisesRegex(AssertionError, "events"):
                validate_run_artifacts(root, self.scenario())

    def test_artifact_must_match_resolved_run_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = self.artifact()
            artifact["run_id"] = "wrong-run"
            (root / "tank_duel_ap.json").write_text(json.dumps(artifact), encoding="utf-8")
            context = {"run_id": "expected-run", "ace_commit": "test", "branch": "test"}
            with self.assertRaisesRegex(SystemExit, "not bound"):
                validate_run_artifacts(root, self.scenario(), context)

    def test_console_lua_errors_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "console.log").write_text("Lua Error: boom", encoding="utf-8")
            with self.assertRaisesRegex(SystemExit, "console"):
                validate_console(root)

    def test_process_group_cleanup_stops_the_adapter(self):
        command = [sys.executable, "-c", "import time; time.sleep(30)"]
        process = subprocess.Popen(command, start_new_session=(os.name != "nt"))
        try:
            stop_process_tree(process, force=True)
            process.wait(timeout=5)
            self.assertIsNotNone(process.returncode)
        finally:
            if process.poll() is None:
                process.kill()

    def test_local_srcds_discovery_prefers_configured_path_and_supports_both_binaries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            configured = root / "configured"
            configured.mkdir()
            executable = configured / "srcds_win64.exe"
            executable.write_bytes(b"test")
            discovered = discover_local_srcds({"SRCDS_PATH": str(configured)}, root / "empty-home")
            self.assertEqual(discovered, executable.resolve())

    def test_local_srcds_discovery_uses_generic_gmodds_default(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            executable = home / "gmodds" / "server" / "srcds.exe"
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b"test")
            discovered = discover_local_srcds({}, home)
            self.assertEqual(discovered, executable.resolve())


if __name__ == "__main__":
    unittest.main()
