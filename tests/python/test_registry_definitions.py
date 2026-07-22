"""Static checks for ACE/ACF definition IDs before the runtime loader sees them."""

from collections import defaultdict
from pathlib import Path
import re
import unittest

from lua_source import (
    code_without_comments_and_strings,
    iter_qualified_string_assignments,
    iter_named_calls,
)


REPO = Path(__file__).resolve().parents[2]
SHARED_ROOT = REPO / "lua" / "acf" / "shared"
ROUND_ROOT = SHARED_ROOT / "rounds"
COMPATIBILITY_SOURCE = REPO / "lua" / "autorun" / "acf_globals.lua"
PREEXISTING_NAMESPACE_FUNCTIONS = {"GetHeadPos"}
ACE_ONLY_NAMESPACE_FUNCTIONS = {"GetBallisticsStats", "ResetBallisticsStats"}
LATE_LOADED_ALIASES = {
    "CalcVehicleView": "lua/autorun/sh_ace_workarounds.lua",
    "PrimitivePropertiesApplied": "lua/autorun/server/sv_ace_primitive_compat.lua",
    "CreateMine": "lua/entities/ace_mine/init.lua",
    "RemoveBulletClient": "lua/effects/ace_bulleteffect/init.lua",
    "EngineGUI_Update": "lua/entities/acf_engine/cl_init.lua",
    "GetExplosiveMasses": "lua/entities/ace_explosive/init.lua",
    "MakePrebuiltExplosive": "lua/entities/ace_explosive_prebuilt/init.lua",
}

DEFINITION_FUNCTIONS = {
    "ACE_DefineEntity",
    "ACE_DefineCrewseat",
    "ACE_DefineExtras",
    "ACE_DefineMuzzleFlash",
    "ACE_DefineGunFireSound",
    "ACE_DefineGunClass",
    "ACE_DefineGun",
    "ACE_DefineAmmoCrate",
    "ACE_DefineLegacyAmmoCrate",
    "ACE_DefineRack",
    "ACE_DefineRackClass",
    "ACE_DefineEngine",
    "ACE_DefineGearbox",
    "ACE_DefineFuelTank",
    "ACE_DefineFuelTankSize",
    "ACE_DefineRadar",
    "ACE_DefineRadarClass",
    "ACE_DefineTrackRadar",
    "ACE_DefineTrackRadarClass",
    "ACE_DefineSonar",
    "ACE_DefineSonarClass",
    "ACE_DefineIRST",
    "ACE_DefineIRSTClass",
    "ACE_DefineVHeatSource",
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

    def test_migrated_namespace_functions_have_legacy_aliases(self):
        ace_globals = set()

        for path in (REPO / "lua").rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            ace_globals.update(re.findall(r"(?m)^\s*function\s+ACE_([A-Za-z_][A-Za-z0-9_]*)\s*\(", source))
            self.assertNotRegex(source, r"(?m)^\s*function\s+ACF_[A-Za-z_][A-Za-z0-9_]*\s*\(")

        self.assertIn("CreateBullet", ace_globals)
        self.assertIn("DefineExplosive", ace_globals)
        self.assertIn("MarkArmorDirty", ace_globals)

        for name, relative_path in LATE_LOADED_ALIASES.items():
            source = (REPO / relative_path).read_text(encoding="utf-8")
            self.assertTrue(
                f"ACE_{name} = ACE.{name}" in source
                or re.search(rf"function\s+ACE_{re.escape(name)}\s*\(", source),
                f"late-loaded function {name} is missing its ACE entry point",
            )

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
                    r"ACE\s*\.\s*RoundTypes\s*\[\s*Round\s*\.\s*Type\s*\]"
                    r"\s*=\s*Round",
                )
            round_types.extend(matches)

        self.assertTrue(round_types, "no round definitions were found")
        self.assertEqual(len(round_types), len(set(round_types)))


if __name__ == "__main__":
    unittest.main()
