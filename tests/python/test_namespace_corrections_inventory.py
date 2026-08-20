import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "tools" / "namespace_corrections_inventory.py"


class NamespaceCorrectionsInventoryTests(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
