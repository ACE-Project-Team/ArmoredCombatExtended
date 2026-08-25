"""Regression tests for the fail-closed ACE scheduler surface inventory."""

from pathlib import Path
import re
import shutil
import tempfile
import unittest
from collections import Counter

from tools import ace_scheduler_manifest as manifest


REPO = Path(__file__).resolve().parents[2]


class SchedulerManifestTests(unittest.TestCase):
    def test_damage_effect_route_preserves_synchronous_damage_and_fallback(self):
        source = (REPO / "lua/ace/server/sv_acfdamage.lua").read_text(encoding="utf-8")
        damage_call = "ACE.HE( AvgPos , vector_origin , HEWeight , HEWeight , Inflictor , ent, ent, BlastPenRatio )"
        route = "if not (ACE and ACE.ScheduleDamageDetonationEffect and ACE.ScheduleDamageDetonationEffect(AvgPos, VisualRadius, 0.001)) then\n\t\t\ttimer.Simple(0.001, function()"
        self.assertIn(damage_call, source)
        self.assertIn(route, source)
        self.assertLess(source.index(damage_call), source.index(route))
        self.assertIn('util.Effect( "ACE_Scaled_Detonation", Flash )', source[source.index(route):])

    def test_flare_think_integration_routes_lifecycle_and_fallback(self):
        source = (REPO / "lua/entities/ace_flare/init.lua").read_text(encoding="utf-8")
        self.assertIn("if ACE.RegisterFlareThink then ACE.RegisterFlareThink(self) end", source)
        self.assertIn("if ACE.UnregisterFlareThink then ACE.UnregisterFlareThink(ent) end", source)
        self.assertIn("local scheduled = ACE.FlareThink and ACE.FlareThink(self)", source)
        self.assertIn("if scheduled ~= nil then return scheduled end", source)
        self.assertIn("self:StopParticles()", source)

    def test_current_inventory_is_explicit_and_evidenced(self):
        rows = manifest.scan(REPO)
        statuses = Counter(row["status"] for row in rows)
        self.assertGreater(len(rows), 0)
        self.assertEqual(statuses["pending"], 0)
        self.assertEqual({row["status"] for row in rows}, {"migrated", "engine-bound", "blocked"})
        self.assertTrue(all("evidence_state" in row for row in rows if row["status"] == "migrated"))
        keys = [(row["source"], row["line"], row["occurrence"]) for row in rows]
        self.assertEqual(len(keys), len(set(keys)), "two scheduling surfaces were collapsed")
        migrated = {(row["source"], row["line"], row["occurrence"]) for row in rows if row["status"] == "migrated"}
        self.assertEqual(migrated, set(manifest.EXPECTED_MIGRATED_PRIMITIVES))
        self.assertEqual(
            {row["reason"] for row in rows if row["status"] == "migrated"},
            set(manifest.MIGRATED_EVIDENCE),
        )

    def test_timer_member_audit_has_no_unclassified_methods(self):
        methods = set()
        for source_path in (REPO / "lua").rglob("*.lua"):
            for line in source_path.read_text(encoding="utf-8", errors="replace").splitlines():
                if line.lstrip().startswith("--"):
                    continue
                methods.update(re.findall(r"\btimer\s*\.\s*(\w+)", line))

        self.assertEqual(methods, {"Create", "Simple", "Remove", "Exists", "RepsLeft"})

    def test_reviewed_source_mutation_becomes_pending(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copytree(REPO / "lua", root / "lua")
            target = root / "lua/ace/server/sv_ace_renderqueue.lua"
            source = target.read_text(encoding="utf-8")
            target.write_text(source.replace("ACE.Scheduler.RegisterAdapter", "timer.Simple", 1), encoding="utf-8")

            rows = manifest.scan(root)
            self.assertTrue(any(row["status"] == "pending" for row in rows))

    def test_same_line_surfaces_are_not_collapsed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lua").mkdir()
            (root / "lua/manifest_probe.lua").write_text(
                "timer.Simple(0, callback); timer.Simple(0, callback)\n",
                encoding="utf-8",
            )

            rows = manifest.scan(root)
            self.assertEqual(len(rows), 2)
            self.assertEqual({row["occurrence"] for row in rows}, {1, 2})
            self.assertTrue(all(row["status"] == "pending" for row in rows))

        status, _ = manifest.disposition(
            "lua/ace/server/sv_ace_renderqueue.lua", 106, 1, "ACE.Scheduler.RegisterAdapter("
        )
        self.assertEqual(status, "migrated")
        status, _ = manifest.disposition(
            "lua/ace/server/sv_ace_renderqueue.lua", 106, 2, "ACE.Scheduler.RegisterAdapter("
        )
        self.assertEqual(status, "pending")

    def test_migrated_row_requires_its_reviewed_primitive(self):
        status, _ = manifest.disposition(
            "lua/ace/server/sv_ace_renderqueue.lua", 106, 1, "timer.Simple"
        )
        self.assertEqual(status, "pending")


if __name__ == "__main__":
    unittest.main()
