import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "tools" / "namespace_corrections_inventory.py"
LEDGER_SCRIPT = REPO / "tools" / "namespace_corrections_ledgers.py"


class NamespaceCorrectionsInventoryTests(unittest.TestCase):
    def test_runtime_entity_consumers_use_ace_state_boundary(self):
        allowed = {
            REPO / "lua" / "ace" / "shared" / "sh_ace_entity_state.lua",
            REPO / "lua" / "autorun" / "server" / "sv_ace_primitive_compat.lua",
            REPO / "lua" / "ace" / "test_dsl_runtime.lua",
        }
        direct_legacy = []
        for path in (REPO / "lua").rglob("*.lua"):
            if "tests" in path.parts or path in allowed:
                continue
            text = path.read_text(encoding="utf-8")
            if re.search(r"\.ACF\b", text):
                direct_legacy.append(path.relative_to(REPO).as_posix())
        self.assertEqual(direct_legacy, [])

        state_source = (REPO / "lua" / "ace" / "shared" / "sh_ace_entity_state.lua").read_text(
            encoding="utf-8"
        )
        self.assertIn("function ACE.GetEntityState", state_source)
        self.assertIn("function ACE.SetEntityState", state_source)

    def test_inventory_is_deterministic_and_classifies_known_symbols(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "inventory.json"
            result = subprocess.run(
                [sys.executable, str(SCRIPT), "--repo", str(REPO), "--output", str(output)],
                check=True,
                capture_output=True,
                text=True,
            )
            self.assertTrue(result.stdout.strip())
            data = json.loads(output.read_text(encoding="utf-8"))
            self.assertGreater(data["counts"]["lua_files"], 0)
            self.assertGreater(data["counts"]["functions"], 0)
            self.assertGreater(data["counts"]["anonymous_functions"], 0)
            self.assertGreater(data["counts"]["hooks"], 0)
            self.assertGreater(data["counts"]["ace_flat_refs"], 0)
            self.assertEqual(
                data["counts"]["all_functions"],
                len(data["functions"]) + len(data["anonymous_functions"]),
            )
            names = {(item["name"], item["scope"]) for item in data["functions"]}
            self.assertIn(("ACE.CalcArmor", "global"), names)
            self.assertIn(("ACE_CalcSubsystem", "ace-private-local"), names)

    def test_output_is_sorted_by_source_order(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "inventory.json"
            subprocess.run(
                [sys.executable, str(SCRIPT), "--repo", str(REPO), "--output", str(output)],
                check=True,
            )
            data = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(data["files"], sorted(data["files"]))
            self.assertEqual(
                data["functions"],
                sorted(data["functions"], key=lambda item: (item["file"], item["line"], item["name"])),
            )
            self.assertEqual(
                data["hooks"],
                sorted(data["hooks"], key=lambda item: (item["file"], item["line"], item["operation"], item["event"])),
            )

    def test_scanner_ignores_comments_and_finds_embedded_hooks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lua").mkdir()
            (root / "tests").mkdir()
            (root / "lua" / "fixture.lua").write_text(
                "-- function ACE_NotReal() end\n"
                "local callback = hook.Add(\"EmbeddedEvent\", \"id\", function() end)\n"
                "function Named() local nested = function() end end\n"
                "local entity_state = Entity.ACF.State\n"
                "// function ACE_NotRealEither() end\n"
                "/* hook.Add(\"FakeEvent\", \"id\", function() end) ACE.NotReal */\n"
                "--[=[ function ACE_LongComment() end hook.Run(\"FakeLong\") ]=]\n"
                "local long_string = [=[ function ACE_LongString() end ACF_LongString hook.Call(\"FakeString\") ]=]\n"
                "local quoted = \"function ACE_Quoted() end hook.Run('FakeQuoted') ACE.Fake\"\n",
                encoding="utf-8",
            )
            (root / "tests" / "fixture.lua").write_text(
                "local function test_fixture() return function() end end\n",
                encoding="utf-8",
            )
            output = root / "inventory.json"
            subprocess.run(
                [sys.executable, str(SCRIPT), "--repo", str(root), "--output", str(output)],
                check=True,
            )
            data = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(data["counts"]["hooks"], 1)
            self.assertEqual(data["hooks"][0]["event"], "EmbeddedEvent")
            self.assertEqual(data["counts"]["ace_flat_globals"], 0)
            self.assertEqual(data["counts"]["ace_table_refs"], 0)
            self.assertGreaterEqual(data["counts"]["anonymous_functions"], 2)
            self.assertIn(
                "ACE_LongString",
                {item["token"] for item in data["ace_flat_refs"]},
            )
            self.assertIn(
                "ACF_LongString",
                {item["token"] for item in data["legacy_refs"]},
            )
            self.assertIn("tests/fixture.lua", data["files"])

    def test_ledgers_are_source_derived_and_exclude_generated_bytecode(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inventory = root / "inventory.json"
            output = root / "ledgers"
            subprocess.run(
                [sys.executable, str(SCRIPT), "--repo", str(REPO), "--output", str(inventory)],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                [
                    sys.executable,
                    str(LEDGER_SCRIPT),
                    "--repo",
                    str(REPO),
                    "--inventory",
                    str(inventory),
                    "--output",
                    str(output),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            path_ledger = (output / "path-ledger.csv").read_text(encoding="utf-8")
            entity_ledger = (output / "entity-ledger.csv").read_text(encoding="utf-8")
            test_ledger = (output / "test-ledger.csv").read_text(encoding="utf-8")
            self.assertIn("legacy_token_count", path_ledger.splitlines()[0])
            self.assertIn("decision", entity_ledger.splitlines()[0])
            self.assertNotIn("__pycache__", test_ledger)
            self.assertNotIn(".pyc", test_ledger)


if __name__ == "__main__":
    unittest.main()
