from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
TEST = REPO / "lua" / "tests" / "ace" / "ballistics_scheduler.lua"


class SchedulerSuiteManifestTests(unittest.TestCase):
    def test_behavioral_scheduler_group_is_present(self):
        source = TEST.read_text(encoding="utf-8")
        self.assertIn('groupName = "ACE ballistics scheduler behavior"', source)
        self.assertIn('registers, removes, and advances each active bullet once per frame', source)
        self.assertIn('does not advance self-managed bullets', source)


if __name__ == "__main__":
    unittest.main()
