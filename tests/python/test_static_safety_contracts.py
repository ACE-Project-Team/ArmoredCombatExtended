"""Warning-only static safety checks for broad ACE control-flow risks."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest

from ace_static.annotations import findings_to_report, github_annotation
from ace_static.scanner import RULE_IDS, scan_file, scan_repo


REPO = Path(__file__).resolve().parents[2]
ALLOWLIST = REPO / "tests" / "fixtures" / "static_allowlist.json"


class StaticSafetyContractTests(unittest.TestCase):
    def test_allowlist_declares_every_rule(self):
        allowlist = json.loads(ALLOWLIST.read_text(encoding="utf-8"))

        self.assertEqual(allowlist["schema"], 1)
        self.assertEqual(RULE_IDS, set(allowlist["rules"]))

    def test_scanner_emits_expected_warning_families_on_synthetic_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            lua = repo / "lua" / "acf" / "server"
            lua.mkdir(parents=True)
            source = lua / "synthetic.lua"
            source.write_text(
                """
                function ACF_SpallTrace()
                    ACF_SpallTrace()
                end

                while true do
                    break
                end

                timer.Create("ACEStaticName", 1, 0, function()
                    self:DoWork()
                end)

                timer.Simple(1, function()
                    timer.Simple(1, function() end)
                end)
                """,
                encoding="utf-8",
            )

            findings = scan_file(repo, source)
            rules = {finding.rule_id for finding in findings}

        self.assertIn("ACE_RECURSION", rules)
        self.assertIn("ACE_POSSIBLY_UNBOUNDED_LOOP", rules)
        self.assertIn("ACE_TIMER_CALLBACK_SUBSTITUTE", rules)
        self.assertIn("ACE_TIMER_TEARDOWN", rules)
        self.assertIn("ACE_TIMER_ENTITY_CAPTURE", rules)
        self.assertIn("ACE_TIMER_SELF_RESCHEDULE", rules)

    def test_repository_scan_is_warning_only_and_reportable(self):
        findings = scan_repo(REPO)
        report = findings_to_report(findings)

        self.assertEqual(report["schema"], 1)
        self.assertTrue(all(item["severity"] == "warning" for item in report["findings"]))
        self.assertTrue(all(item["rule_id"] in RULE_IDS for item in report["findings"]))

    def test_annotations_are_valid_github_warning_lines(self):
        findings = scan_repo(REPO)
        if not findings:
            self.skipTest("Current source has no heuristic static-safety findings")

        annotation = github_annotation(findings[0])

        self.assertTrue(annotation.startswith("::warning file="))
        self.assertIn(f"title={findings[0].rule_id}", annotation)


if __name__ == "__main__":
    unittest.main()
