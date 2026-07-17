"""Static checks for ACE/ACF definition IDs before the runtime loader sees them."""

from collections import defaultdict
from pathlib import Path
import unittest

from lua_source import (
    code_without_comments_and_strings,
    iter_qualified_string_assignments,
    iter_named_calls,
)


REPO = Path(__file__).resolve().parents[2]
SHARED_ROOT = REPO / "lua" / "acf" / "shared"
ROUND_ROOT = SHARED_ROOT / "rounds"

DEFINITION_FUNCTIONS = {
    "ACF_DefineEntity",
    "ACE_DefineCrewseat",
    "ACE_DefineExtras",
    "ACE_DefineMuzzleFlash",
    "ACE_DefineGunFireSound",
    "ACF_defineGunClass",
    "ACF_defineGun",
    "ACE_DefineAmmoCrate",
    "ACE_DefineLegacyAmmoCrate",
    "ACF_DefineRack",
    "ACF_DefineRackClass",
    "ACF_DefineEngine",
    "ACF_DefineGearbox",
    "ACF_DefineFuelTank",
    "ACF_DefineFuelTankSize",
    "ACF_DefineRadar",
    "ACF_DefineRadarClass",
    "ACF_DefineTrackRadar",
    "ACF_DefineTrackRadarClass",
    "ACF_DefineSonar",
    "ACF_DefineSonarClass",
    "ACF_DefineIRST",
    "ACF_DefineIRSTClass",
    "ACF_DefineVHeatSource",
    "ACE_DefineExplosive",
    "ACE_DefineMine",
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
    @classmethod
    def setUpClass(cls):
        cls.definitions = collect_definitions()

    def test_every_definition_family_has_source_entries(self):
        for function in sorted(DEFINITION_FUNCTIONS):
            with self.subTest(function=function):
                self.assertTrue(
                    self.definitions[function],
                    f"{function} has no source definitions",
                )

    def test_definition_ids_are_unique_within_each_family(self):
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
                self.assertEqual({}, duplicates, f"duplicate IDs: {duplicates}")

    def test_definition_ids_are_not_blank(self):
        for function, entries in self.definitions.items():
            for identifier, path in entries:
                with self.subTest(function=function, source=path):
                    self.assertTrue(identifier.strip())

    def test_definition_scanner_ignores_comments_and_strings(self):
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

    def test_round_scanner_ignores_comments_and_strings(self):
        source = '''
            -- Round.Type = "commented"
            local text = [=[ Round.Type = "quoted" ]=]
            Round . Type = "real"
            ACF.RoundTypes[Round.Type] = Round
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
            r"ACF\s*\.\s*RoundTypes\s*\[\s*Round\s*\.\s*Type\s*\]"
            r"\s*=\s*Round",
        )

    def test_round_sources_have_unique_types_and_register_themselves(self):
        round_types = []
        for path in sorted(ROUND_ROOT.glob("round*.lua")):
            source = path.read_text(encoding="utf-8", errors="replace")
            matches = [
                value
                for value, _ in iter_qualified_string_assignments(source, "Round.Type")
            ]
            with self.subTest(source=path):
                self.assertEqual(1, len(matches))
                code = code_without_comments_and_strings(source)
                self.assertRegex(
                    code,
                    r"ACF\s*\.\s*RoundTypes\s*\[\s*Round\s*\.\s*Type\s*\]"
                    r"\s*=\s*Round",
                )
            round_types.extend(matches)

        self.assertTrue(round_types, "no round definitions were found")
        self.assertEqual(len(round_types), len(set(round_types)))


if __name__ == "__main__":
    unittest.main()
