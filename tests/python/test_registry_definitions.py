"""Registry checks: prove ACE definitions are present and discoverable."""

from collections import defaultdict
from pathlib import Path
import re
import unittest

from ace_test_support import Scenario, scenario_failure
from lua_source import (
    code_without_comments_and_strings,
    iter_qualified_string_assignments,
    iter_named_calls,
)


REPO = Path(__file__).resolve().parents[2]
SHARED_ROOT = REPO / "lua" / "ace" / "shared"
ROUND_ROOT = SHARED_ROOT / "rounds"
DEFINITION_FUNCTIONS = {
    "ACE.DefineEntity",
    "ACE.DefineCrewseat",
    "ACE.DefineExtras",
    "ACE.DefineMuzzleFlash",
    "ACE.DefineGunFireSound",
    "ACE.DefineGunClass",
    "ACE.DefineGun",
    "ACE.DefineAmmoCrate",
    "ACE.DefineLegacyAmmoCrate",
    "ACE.DefineRack",
    "ACE.DefineRackClass",
    "ACE.DefineEngine",
    "ACE.DefineGearbox",
    "ACE.DefineFuelTank",
    "ACE.DefineFuelTankSize",
    "ACE.DefineRadar",
    "ACE.DefineRadarClass",
    "ACE.DefineTrackRadar",
    "ACE.DefineTrackRadarClass",
    "ACE.DefineSonar",
    "ACE.DefineSonarClass",
    "ACE.DefineIRST",
    "ACE.DefineIRSTClass",
    "ACE.DefineVHeatSource",
    "ACE.DefineExplosive",
    "ACE.DefineMine",
}


def collect_definitions():
    definitions = defaultdict(list)

    for path in SHARED_ROOT.rglob("*.lua"):
        source = path.read_text(encoding="utf-8", errors="replace")
        for function in DEFINITION_FUNCTIONS:
            for identifier, _, _ in iter_named_calls(source, function):
                definitions[function].append((identifier, path))

    return definitions


class RegistryDefinitionTests(unittest.TestCase):
    scenario = Scenario(
        "ace.offline.definitions.discoverable",
        "ACE definitions are defined and discoverable",
    )

    @classmethod
    def setUpClass(cls):
        cls.definitions = collect_definitions()

    def test_registry_has_every_expected_definition_family(self):
        for function in sorted(DEFINITION_FUNCTIONS):
            with self.subTest(function=function):
                if not self.definitions[function]:
                    self.fail(scenario_failure(
                        self.scenario,
                        "load definition family",
                        "the family has at least one source definition",
                        f"{function} has no source definitions",
                    ))

    def test_registry_definition_ids_are_unique(self):
        for function in sorted(DEFINITION_FUNCTIONS):
            entries = self.definitions[function]
            locations = defaultdict(list)
            for identifier, path in entries:
                locations[identifier].append(str(path.relative_to(REPO)))
            duplicates = {
                identifier: paths
                for identifier, paths in locations.items()
                if len(paths) > 1
            }
            with self.subTest(function=function):
                if duplicates:
                    self.fail(scenario_failure(
                        self.scenario,
                        "load definition family",
                        "IDs are unique within the family",
                        f"duplicate IDs: {duplicates}",
                        [f"family={function}"],
                    ))

    def test_registry_definition_ids_are_not_blank(self):
        for function, entries in self.definitions.items():
            for identifier, path in entries:
                with self.subTest(function=function, source=path):
                    if not identifier.strip():
                        self.fail(scenario_failure(
                            self.scenario,
                            "load definition family",
                            "every definition has a non-blank ID",
                            "a blank ID was found",
                            [f"family={function}", f"source={path.relative_to(REPO)}"],
                        ))

    def test_registry_scanner_ignores_comments_and_strings(self):
        source = '''
            -- ACF_defineGun("commented", {})
            local example = "ACF_defineGun('quoted', {})"
            local long_comment = --[=[ ACF_defineGun("long comment", {}) ]=]
                "ignored"
            local long_string = [=[ ACF_defineGun("long string", {}) ]=]
            object.ACF_defineGun("method-qualified", {})
            ACF_defineGun("real", {})
        '''

        self.assertEqual(
            ["real"],
            [
                identifier
                for identifier, _, _ in iter_named_calls(source, "ACF_defineGun")
            ],
        )

    def test_round_registry_scanner_ignores_comments_and_strings(self):
        source = '''
            -- Round.Type = "commented"
            local text = [=[ Round.Type = "quoted" ]=]
            Round . Type = "real"
            ACE.RoundTypes[Round.Type] = Round
        '''

        self.assertEqual(
            ["real"],
            [
                value
                for value, _ in iter_qualified_string_assignments(source, "Round.Type")
            ],
        )
        code = code_without_comments_and_strings(source)
        self.assertRegex(
            code,
            r"ACE\s*\.\s*RoundTypes\s*\[\s*Round\s*\.\s*Type\s*\]"
            r"\s*=\s*Round",
        )

    def test_round_registry_contains_unique_self_registering_types(self):
        round_types = []
        for path in sorted(ROUND_ROOT.glob("round*.lua")):
            source = path.read_text(encoding="utf-8", errors="replace")
            matches = [
                value
                for value, _ in iter_qualified_string_assignments(source, "Round.Type")
            ]
            with self.subTest(source=path):
                if len(matches) != 1:
                    self.fail(scenario_failure(
                        self.scenario,
                        "load round definition",
                        "each round source declares exactly one type",
                        f"found {len(matches)} types",
                        [f"source={path.relative_to(REPO)}"],
                    ))
                code = code_without_comments_and_strings(source)
                if not re.search(
                    r"ACE\s*\.\s*RoundTypes\s*\[\s*Round\s*\.\s*Type\s*\]"
                    r"\s*=\s*Round",
                    code,
                ):
                    self.fail(scenario_failure(
                        self.scenario,
                        "load round definition",
                        "the round registers itself in ACE.RoundTypes",
                        "the registration statement was not found",
                        [f"source={path.relative_to(REPO)}"],
                    ))
            round_types.extend(matches)

        if not round_types:
            self.fail(scenario_failure(
                self.scenario,
                "load round definitions",
                "at least one round definition exists",
                "no round definitions were found",
            ))
        if len(round_types) != len(set(round_types)):
            self.fail(scenario_failure(
                self.scenario,
                "load round definitions",
                "round type names are unique",
                f"duplicate round types: {round_types}",
            ))


if __name__ == "__main__":
    unittest.main()
