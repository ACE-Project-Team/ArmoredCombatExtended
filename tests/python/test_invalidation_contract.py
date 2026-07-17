"""Static source contracts for every ACE point invalidation producer."""

from pathlib import Path
import re
import unittest

from lua_source import code_without_comments_and_strings


REPO = Path(__file__).resolve().parents[2]


def source(relative):
    return (REPO / relative).read_text(encoding="utf-8")


def call_spans(text, function_name):
    """Return raw call spans while locating calls in comment/string-free code."""

    code = code_without_comments_and_strings(text)
    pattern = re.compile(rf"\b{re.escape(function_name)}\s*\(")
    for match in pattern.finditer(code):
        opening = code.find("(", match.start(), match.end())
        depth = 0
        for index in range(opening, len(code)):
            if code[index] == "(":
                depth += 1
            elif code[index] == ")":
                depth -= 1
                if depth == 0:
                    yield text[match.start() : index + 1]
                    break


def call_with_reason(text, function_name, reason):
    quoted = (f'"{reason}"', f"'{reason}'")
    return any(any(value in span for value in quoted) for span in call_spans(text, function_name))


class InvalidationContractTests(unittest.TestCase):
    def assert_reasons(self, relative, reasons):
        text = source(relative)
        self.assertIn("ACE_PointsInputChanged", text, relative)
        for reason in reasons:
            with self.subTest(source=relative, reason=reason):
                self.assertTrue(
                    call_with_reason(text, "ACE_PointsInputChanged", reason),
                    f"{reason} is not an active ACE_PointsInputChanged reason",
                )

    def test_entity_producers_route_through_the_shared_input_api(self):
        self.assert_reasons(
            "lua/entities/acf_gun/init.lua",
            (
                "gun-removed",
                "gunner-linked",
                "loader-linked",
                "gun-ammo-linked",
                "gun-unlinked",
                "gun-rof-limit",
                "gun-links-pasted",
            ),
        )
        self.assert_reasons(
            "lua/entities/acf_rack/init.lua",
            (
                "rack-removed",
                "rack-preloaded",
                "rack-missile-fired",
                "rack-missile-reloaded",
                "rack-links-pasted",
                "rack-ammo-linked",
                "rack-unlinked",
            ),
        )
        self.assert_reasons(
            "lua/entities/acf_ammo/init.lua",
            ("ammo-updated", "ammo-removed"),
        )
        self.assert_reasons("lua/entities/acf_engine/init.lua", ("engine-updated",))

    def test_paste_and_ammo_update_suppress_intermediate_link_events(self):
        gun = source("lua/entities/acf_gun/init.lua")
        rack = source("lua/entities/acf_rack/init.lua")
        ammo = source("lua/entities/acf_ammo/init.lua")

        for name, text, final_reason in (
            ("gun", gun, "gun-links-pasted"),
            ("rack", rack, "rack-links-pasted"),
        ):
            with self.subTest(entity=name):
                self.assertIn("_ACEPointsSuppress = true", text)
                self.assertIn(f'"{final_reason}"', text)

        gun_endpoint_calls = [
            span for span in call_spans(gun, "ACE_PointsInputChanged") if "self, Target" in span
        ]
        rack_endpoint_calls = [
            span for span in call_spans(rack, "ACE_PointsInputChanged") if "self, Target" in span
        ]
        self.assertEqual(len(gun_endpoint_calls), 4)
        self.assertEqual(len(rack_endpoint_calls), 2)
        self.assertIn("ReadyRack = true", rack)
        self.assertIn("if missile and ACE_PointsInputChanged", rack)
        self.assertIn('ACE_PointsInputChanged(self, "rack-missile-fired"', rack)
        self.assertIn('ACE_PointsInputChanged(self, "rack-missile-reloaded"', rack)

        self.assertIn("self._ACEPointsSuppress = true", ammo)
        self.assertIn('"ammo-updated"', ammo)
        self.assertIn('"ammo-removed"', ammo)

    def test_non_entity_armor_producers_use_the_armor_boundary(self):
        for relative, reason in (
            ("lua/starfall/libs_sv/acf.lua", "armor-starfall"),
            ("lua/weapons/gmod_tool/stools/acfarmorprop.lua", "armor-tool"),
            ("lua/entities/gmod_wire_expression2/core/custom/acf.lua", "armor-expression2"),
        ):
            with self.subTest(source=relative):
                text = source(relative)
                self.assertTrue(call_with_reason(text, "ACE_MarkArmorDirty", reason))

        primitive = source("lua/autorun/server/sv_ace_primitive_compat.lua")
        self.assertIn("ACE_MarkArmorDirty", primitive)
        self.assertIn("ProperClippingPhysicsClipped", primitive)
        self.assertIn("ProperClippingPhysicsReset", primitive)

    def test_central_hook_contract_is_present(self):
        legality = source("lua/acf/server/sv_contraptionlegality.lua")
        pointshandling = source("lua/acf/server/sv_pointshandling.lua")

        self.assertIn("function ACE_NotifyPointsInvalidated", legality)

        self.assertIn("local POINTS_STATE_VERSION = 3", legality)
        self.assertIn("ACE.PointContraptions[con] = true", legality)
        self.assertIn("ACE_OnContraptionsPointsInvalidated", legality)
        self.assertIn("ACE_NotifyContraptionPointsInvalidated", pointshandling)
        self.assertIn("ACE_OnContraptionPointsInvalidated", pointshandling)
        self.assertIn("ACE_OnContraptionPointsRecalculated", pointshandling)

        for hook_name in (
            "cfw.contraption.created",
            "cfw.contraption.entityAdded",
            "cfw.contraption.entityRemoved",
            "cfw.contraption.split",
            "cfw.contraption.merged",
            "cfw.contraption.removed",
            "PlayerFrozeObject",
            "PlayerUnfrozeObject",
            "PlayerEnteredVehicle",
            "ProperClippingPhysicsClipped",
            "ProperClippingPhysicsReset",
        ):
            with self.subTest(hook=hook_name):
                self.assertIn(f'hook.Add("{hook_name}"', legality)

        self.assertNotIn('hook.Add("PhysgunDrop", "ACE_PointsUnfreezeInvalidation"', legality)
        self.assertIn("if ent._ACEPointsFrozen == false then return end", legality)

    def test_matrix_selftest_is_discovered_by_the_offline_runner(self):
        runner = source("tests/run_luajit_tests.py")
        self.assertIn('glob("*_selftest.lua")', runner)
        matrix = REPO / "tests" / "lua" / "ace_points_invalidation_matrix_luajit_selftest.lua"
        self.assertTrue(matrix.is_file())


if __name__ == "__main__":
    unittest.main()
