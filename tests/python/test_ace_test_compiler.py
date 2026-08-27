import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))
from ace_test_compiler import compile_suite, parse


ROOT = Path(__file__).parents[2]
SOURCE = ROOT / "tests" / "prototypes" / "acf_core_suite_applied.ace_test"
REGISTRY = ROOT / "tests" / "prototypes" / "ace_core_fixture_registry.json"
ACTIONS = ROOT / "tests" / "prototypes" / "ace_test_action_registry.json"


class AceTestCompilerTests(unittest.TestCase):
    def test_compiles_every_maintainer_test_to_one_native_group(self):
        registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
        actions = json.loads(ACTIONS.read_text(encoding="utf-8"))
        tests = parse(SOURCE, registry, actions)
        self.assertEqual(len(tests), 15)
        self.assertTrue(all("native" in test["requires"] for test in tests))
        self.assertTrue(all(test["cleanup"] for test in tests))
        self.assertEqual(len({test["scenarioId"] for test in tests}), 15)

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "generated.lua"
            self.assertEqual(compile_suite(SOURCE, REGISTRY, output, ACTIONS), 15)
            generated = output.read_text(encoding="utf-8")
            self.assertIn('include("ace/test_dsl_runtime.lua")', generated)
            self.assertIn("ACE.CheckLegal", generated)
            self.assertIn('["path"] = "ACE.Check"', generated)
            self.assertIn("spec.fixturesRegistry = Suite.fixtures", generated)
            self.assertIn("ACE interpreted core validation", generated)
            self.assertIn("valid_prop", generated)
            self.assertIn("ACE_GLuaTestExpectedCases", generated)
            for test in tests:
                case_name = f'[{test["scenarioId"]}] {test["name"]}'
                self.assertIn(case_name, generated)

    def test_unknown_fixture_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown.ace_test"
            source.write_text(
                'new Test "unknown fixture"\nscenario ace.test.unknown_fixture\nuses does_not_exist as Subject\ncleanup automatic\n',
                encoding="utf-8",
            )
            registry = {"fixtures": {}}
            with self.assertRaisesRegex(ValueError, "unknown fixture"):
                parse(source, registry)

    def test_unknown_action_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown.ace_test"
            source.write_text(
                'new Test "unknown action"\nscenario ace.test.unknown_action\nuses valid_prop as Subject\ndo ACE.NoSuchFunction on Subject as Result\ncleanup automatic\n',
                encoding="utf-8",
            )
            registry = {"fixtures": {"valid_prop": {"kind": "native_entity"}}}
            with self.assertRaisesRegex(ValueError, "unknown native action"):
                parse(source, registry, {"actions": {}})

    def test_unknown_action_argument_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown_argument.ace_test"
            source.write_text(
                'new Test "unknown argument"\n'
                'scenario ace.test.unknown_argument\n'
                'uses valid_prop as Subject\n'
                'do ACE.Check on Typo as Result\n'
                'cleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "unknown action argument"):
                parse(
                    source,
                    {"fixtures": {"valid_prop": {"kind": "native_entity"}}},
                    {"actions": {"ACE.Check": {"kind": "global"}}},
                )

    def test_fixture_and_result_names_cannot_collide(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "collision.ace_test"
            source.write_text(
                'new Test "collision"\n'
                'scenario ace.test.collision\n'
                'uses valid_prop as Subject\n'
                'do ACE.Check on Subject as Subject\n'
                'cleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "collides"):
                parse(
                    source,
                    {"fixtures": {"valid_prop": {"kind": "native_entity"}}},
                    {"actions": {"ACE.Check": {"kind": "global"}}},
                )

    def test_reason_requires_a_registered_action_result_field(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown_reason.ace_test"
            source.write_text(
                'new Test "unknown reason"\n'
                'scenario ace.test.unknown_reason\n'
                'uses valid_prop as Subject\n'
                'do ACE.Check on Subject as Result\n'
                'expect Result reason is "missing"\n'
                'cleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "unknown observation"):
                parse(
                    source,
                    {"fixtures": {"valid_prop": {"kind": "native_entity"}}},
                    {"actions": {"ACE.Check": {"kind": "global", "returns": []}}},
                )

    def test_scenario_id_is_required_and_unique(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "ids.ace_test"
            source.write_text(
                'new Test "missing id"\nuses valid_prop as Subject\ncleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "stable scenario id"):
                parse(source, {"fixtures": {"valid_prop": {"kind": "native_entity"}}})

            source.write_text(
                'new Test "duplicate one"\nscenario ace.test.duplicate\nuses valid_prop as Subject\ncleanup automatic\n'
                'new Test "duplicate two"\nscenario ace.test.duplicate\nuses valid_prop as Subject\ncleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "duplicate scenario id"):
                parse(source, {"fixtures": {"valid_prop": {"kind": "native_entity"}}})

    def test_registered_dotted_action_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "registered.ace_test"
            source.write_text(
                'new Test "registered action"\n'
                'scenario ace.test.registered_action\n'
                'uses valid_prop as Subject\n'
                'do ACE.Manufacturing.RoundCost on Subject as Cost\n'
                'expect Cost is greater than 0\n'
                'cleanup automatic\n',
                encoding="utf-8",
            )
            tests = parse(
                source,
                {"fixtures": {"valid_prop": {"kind": "native_entity"}}},
                {"actions": {"ACE.Manufacturing.RoundCost": {"kind": "global"}}},
            )
            self.assertEqual(tests[0]["actions"][0]["action"], "ACE.Manufacturing.RoundCost")

    def test_unknown_expectation_subject_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown_subject.ace_test"
            source.write_text(
                'new Test "unknown subject"\n'
                'scenario ace.test.unknown_subject\n'
                'uses valid_prop as Subject\n'
                'expect Typo exists\n'
                'cleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "unknown expectation subject"):
                parse(source, {"fixtures": {"valid_prop": {"kind": "native_entity"}}})

    def test_unknown_observation_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "unknown_observation.ace_test"
            source.write_text(
                'new Test "unknown observation"\n'
                'scenario ace.test.unknown_observation\n'
                'uses valid_prop as Subject\n'
                'expect Subject.NotARealField exists\n'
                'cleanup automatic\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(ValueError, "unknown observation"):
                parse(source, {"fixtures": {"valid_prop": {"kind": "native_entity"}}})


if __name__ == "__main__":
    unittest.main()
