"""Regression checks for the missile fuse visclip trace contract."""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
MISSILE = REPO / "lua" / "entities" / "ace_missile" / "init.lua"


class MissileVisclipTraceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = MISSILE.read_text(encoding="utf-8")
        cls.trace = source[source.index("if self.CanDetonate == true then") : source.index("local Exit = false")]

    def test_clipped_only_trace_retries_with_the_hit_entity_filtered(self):
        self.assertIn("if not ACF_CheckClips(tr.Entity, tr.HitPos) then break end", self.trace)
        self.assertIn("TraceData.filter[#TraceData.filter + 1] = tr.Entity", self.trace)

    def test_clipped_then_solid_trace_keeps_the_terminal_result(self):
        self.assertIn("tr = util.TraceLine(TraceData)", self.trace)
        self.assertIn("until VisclipCount >= 50", self.trace)
        self.assertEqual(self.trace.count("tr = util.TraceLine(TraceData)"), 1)

    def test_normal_hit_and_world_or_no_hit_are_not_filtered(self):
        self.assertIn("if not ACF_CheckClips(tr.Entity, tr.HitPos) then break end", self.trace)
        self.assertIn("filter = {self}", self.trace)

    def test_trace_span_matches_the_previous_quicktrace(self):
        self.assertIn("start = Pos + self.Flight * DeltaTime * -30", self.trace)
        self.assertIn("endpos = Pos + self.Flight * DeltaTime * 49", self.trace)

    def test_visclip_retry_has_the_shared_fifty_entity_bound(self):
        self.assertIn("VisclipCount = VisclipCount + 1", self.trace)
        self.assertIn("until VisclipCount >= 50", self.trace)


if __name__ == "__main__":
    unittest.main()
