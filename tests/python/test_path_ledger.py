"""Offline contracts for exhaustive ACE path discovery and ledger integrity."""

from __future__ import annotations

from pathlib import Path
import unittest

from ace_static.path_ledger import build_ledger, scan_file, validate_ledger


REPO = Path(__file__).resolve().parents[2]


class PathLedgerTests(unittest.TestCase):
    def test_extractor_covers_dynamic_and_realm_specific_forms(self):
        source = """
        include("server/foo.lua")
        AddCSLuaFile("client/foo.lua")
        hook.Add("Think", "id", function() end)
        timer.Create("owned", 1, 0, function() end)
        net.Receive("hello", function() end)
        net.Start("hello")
        concommand.Add("ace_test", function() end)
        function ENT:Initialize() end
        ENT.TriggerInput = function() end
        ACE.Guidance = {}
        """
        path = REPO / "tests" / "fixture_path_forms.lua"
        path.write_text(source, encoding="utf-8")
        try:
            surfaces = scan_file(REPO, path)
        finally:
            path.unlink()
        kinds = {surface.kind for surface in surfaces}
        self.assertTrue({"loader", "hook", "timer", "net_receive", "net_start", "concommand", "method", "callback", "registry"} <= kinds)

    def test_comments_and_strings_do_not_create_surfaces(self):
        path = REPO / "tests" / "fixture_path_forms.lua"
        path.write_text('-- hook.Add("fake")\nlocal x = "timer.Create(fake)"\n', encoding="utf-8")
        try:
            self.assertEqual([], scan_file(REPO, path))
        finally:
            path.unlink()

    def test_ledger_preserves_prior_dispositions_and_tombstones(self):
        prior = {"surfaces": [{"path_id": "gone", "disposition": "excluded", "evidence": ["reviewed"]}]}
        ledger = build_ledger(REPO, prior)
        validate_ledger(ledger)
        self.assertEqual("gone", ledger["tombstones"][0]["path_id"])

    def test_every_row_has_orthogonal_measurement_cells(self):
        ledger = build_ledger(REPO)
        validate_ledger(ledger)
        self.assertGreater(ledger["summary"]["surface_count"], 0)
        for row in ledger["surfaces"]:
            self.assertEqual({"correctness", "timing", "attribution", "scaling", "soak"}, set(row["measurement"]))


if __name__ == "__main__":
    unittest.main()

