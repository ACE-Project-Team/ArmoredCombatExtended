"""Regression checks for the non-entity ACE namespace migration."""

from pathlib import Path
import re
import subprocess
import unittest

from lua_source import code_without_comments_and_strings


REPO = Path(__file__).resolve().parents[2]
LUA_ROOT = REPO / "lua"
ENTITY_ROOT = LUA_ROOT / "entities"
STARFALL_ROOT = LUA_ROOT / "starfall"
ACE_CONVARS = (
    "enable_dp",
    "kepush",
    "hepush",
    "recoilpush",
    "healthmod",
    "armormod",
    "ammomod",
    "gunfire",
    "debris_lifetime",
    "debris_children",
    "spalling",
    "spalling_multipler",
    "explosions_scaled_he_max",
    "explosions_scaled_ents_max",
    "wind",
    "legacyrecoil",
)


def non_entity_sources():
    for path in LUA_ROOT.rglob("*.lua"):
        if ENTITY_ROOT in path.parents or STARFALL_ROOT in path.parents:
            continue
        yield path


def ace_owned_sources():
    for path in LUA_ROOT.rglob("*.lua"):
        if STARFALL_ROOT in path.parents or (LUA_ROOT / "entities" / "gmod_wire_expression2") in path.parents:
            continue
        if path == LUA_ROOT / "autorun" / "acf_globals.lua":
            continue
        yield path


class NamespaceRefactorTests(unittest.TestCase):
    def test_non_entity_private_helpers_use_ace_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"\b(?:local\s+)?function\s+ACF_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_non_entity_calls_do_not_use_legacy_acf_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?<![:.])\bACF_[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_ace_global_functions_are_defined_with_ace_prefix(self):
        definitions = set()
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            definitions.update(
                re.findall(
                    r"(?m)^\s*function\s+ACE_([A-Za-z_][A-Za-z0-9_]*)\s*\(",
                    source,
                )
            )

        self.assertTrue(definitions)
        self.assertIn("DefineExplosive", definitions)
        self.assertIn("MarkArmorDirty", definitions)

    def test_non_entity_hooks_and_identifiers_use_ace_prefix(self):
        for path in non_entity_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                source = source.replace("ACF_E2_LinkTables", "")
                for compatibility_name in (
                    "ACF_CalcArmor", "ACF_Check", "ACF_CheckClips",
                    "ACF_GetHitAngle", "ACF_GetLinkedWheels", "ACF_SendNotify"
                ):
                    source = source.replace(compatibility_name, "")
                self.assertNotRegex(source, r"(?<![.:])\bACF_[A-Za-z_][A-Za-z0-9_]*")
                self.assertNotRegex(source, r"\bacfmenu|\bacfsound")

    def test_ace_owned_sources_have_no_unqualified_legacy_globals(self):
        for path in ace_owned_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            ).replace("ACF_E2_LinkTables", "")
            for compatibility_name in (
                "ACF_CalcArmor", "ACF_Check", "ACF_CheckClips",
                "ACF_GetHitAngle", "ACF_GetLinkedWheels", "ACF_SendNotify"
            ):
                source = source.replace(compatibility_name, "")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(source, r"(?<![.:])\bACF_[A-Za-z_][A-Za-z0-9_]*")

    def test_globals_keep_backend_state_out_of_acf_table(self):
        raw_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        source = code_without_comments_and_strings(raw_source)

        self.assertRegex(source, r"\bACE\.Threshold\s*=")
        self.assertRegex(source, r"\bACE\.Bullet\s*=\s*\{\}")
        self.assertNotRegex(
            source,
            r"(?m)^\s*ACF\.[A-Za-z_][A-Za-z0-9_]*\s*=\s*(?!ACF\[)"
        )
        self.assertNotRegex(source, r"ACF\s*\[\s*key\s*\]\s*=\s*ACE\[")
        self.assertIn("__ACECompatibilityView", raw_source)
        self.assertRegex(raw_source, r"ACF\s*==\s*nil\s*or\s*rawget\(ACF")
        self.assertRegex(raw_source, r"if\s+ACECompatibilityView\s+then")
        self.assertRegex(raw_source, r"__index\s*=\s*function\(_,\s*key\)")

    def test_deferred_adapters_keep_their_dotted_ace_api(self):
        globals_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        for name in (
            "GetMaterialData", "CheckRound", "HeatFromGun", "HeatFromEngine", "MarkArmorDirty"
        ):
            with self.subTest(name=name):
                self.assertIn(f"ACE.{name} = ACE_{name}", globals_source)

    def test_unchanged_adapter_files_match_pr290(self):
        for relative in (
            "lua/entities/gmod_wire_expression2/core/custom/acf.lua",
            "lua/entities/gmod_wire_expression2/core/custom/cl_acf.lua",
            "lua/starfall/libs_sv/acf.lua",
        ):
            result = subprocess.run(
                ["git", "diff", "--quiet", "047df31f", "--", relative],
                cwd=REPO,
                check=False,
            )
            with self.subTest(path=relative):
                self.assertEqual(result.returncode, 0)

    def test_backend_does_not_initialize_acf_global_table(self):
        for path in ace_owned_sources():
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(source, r"(?m)^\s*(?:local\s+)?ACF\s*=\s*ACF\s+or")
                self.assertNotRegex(source, r"(?m)^\s*if\s+not\s+ACF\s+then\s+ACF\s*=")

    def test_ace_owned_translation_table_is_not_legacy_global(self):
        translation = (LUA_ROOT / "autorun" / "translation" / "ace_translationpacks.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn("ACE.Translation = {}", translation)
        self.assertNotIn("ACFTranslation", translation)
        for path in ace_owned_sources():
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotIn("ACFTranslation", path.read_text(encoding="utf-8", errors="replace"))

    def test_entity_dupe_factories_do_not_collide_after_global_rename(self):
        sources = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (
                LUA_ROOT / "entities" / "ace_explosive" / "init.lua",
                LUA_ROOT / "entities" / "acf_explosive" / "init.lua",
            )
        )
        self.assertEqual(len(re.findall(r"function\s+ACE_MakeExplosive\s*\(", sources)), 1)
        self.assertEqual(len(re.findall(r"function\s+ACE_MakeLegacyExplosive\s*\(", sources)), 1)

    def test_non_entity_menu_sound_effect_and_tool_ids_are_ace_prefixed(self):
        expected_paths = (
            LUA_ROOT / "acf" / "client" / "cl_acemenu_gui.lua",
            LUA_ROOT / "acf" / "client" / "cl_acemenu_missileui.lua",
            REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acemenu.lua",
            REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acesound.lua",
        )
        for path in expected_paths:
            self.assertTrue(path.exists(), f"renamed non-entity asset is missing: {path}")

        for path in non_entity_sources():
            source = path.read_text(encoding="utf-8", errors="replace")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?i)acf/client/cl_acfmenu|\bacfmenu\b|\bacfsound\b|"
                    r"\bacfarmorprop\b|\bacfchaircam\b|\bacfcopy\b",
                )
                self.assertNotRegex(
                    source,
                    r'(?i)util\.Effect\s*\(\s*["\']acf_',
                )

        for path in ace_owned_sources():
            source = path.read_text(encoding="utf-8", errors="replace")
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r'(?i)(?:hook\.(?:Add|Run|Call)|net\.(?:Start|Receive)|'
                    r'util\.AddNetworkString)\s*\(\s*["\'](?:ACF_|acfmenu|acfsound)',
                )

        sound_tool = (REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acesound.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn('duplicator.RegisterEntityModifier( "ace_replacesound", ReplaceSound )', sound_tool)
        self.assertIn('duplicator.RegisterEntityModifier( "acf_replacesound", ReplaceSound )', sound_tool)
        self.assertIn('duplicator.ClearEntityModifier( Entity, "acf_replacesound" )', sound_tool)
        self.assertIn('duplicator.ClearEntityModifier( trace.Entity, "acf_replacesound" )', sound_tool)

        effect_names = {
            path.name for path in (REPO / "lua" / "effects").iterdir() if path.is_dir()
        }
        for old_name in {
            "acf_ap_impact", "acf_ap_penetration", "acf_ap_ricochet", "acf_bulleteffect",
            "acf_heat_explosion", "acf_missilelaunch", "acf_muzzleflash", "acf_racklaunch",
            "acf_radar_noise", "acf_scaled_explosion", "acf_smoke",
        }:
            self.assertNotIn(old_name, effect_names)

    def test_e2_and_starfall_adapters_remain_at_the_pr2_base(self):
        for relative in (
            "lua/entities/gmod_wire_expression2/core/custom/acf.lua",
            "lua/starfall/libs_sv/acf.lua",
        ):
            path = REPO / relative
            expected = subprocess.check_output(
                ["git", "show", f"047df31f:{relative}"], cwd=REPO
            )
            with self.subTest(source=relative):
                self.assertEqual(expected, path.read_bytes())

    def test_named_global_functions_are_namespaced_or_entity_methods(self):
        for path in LUA_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?m)^\s*function\s+(?!ACE_|ENT:|local\s)[A-Za-z_][A-Za-z0-9_]*\s*\(",
                )

    def test_entity_callers_use_the_ace_backend_prefix(self):
        self.assertTrue(any(ENTITY_ROOT.rglob("*.lua")))
        legacy_entity_calls = (
            "Activate", "BulletClient", "CalcArmor", "CalcBulletFlight", "CalcCurve",
            "CanLinkRack", "Check", "CheckClips", "CheckLegal", "Damage", "GetAllChildren",
            "GetAllPhysicalConstraints", "GetGunValue", "GetHitAngle", "GetLinkedWheels",
            "GetPhysicalParent", "GetRackValue", "HE", "HEKill", "KEShove", "Kinetic",
            "MuzzleVelocity", "PropDamage", "RackCanLoadCaliber", "RenderLight",
            "ScaledExplosion", "SendNotify",
        )
        for path in ENTITY_ROOT.rglob("*.lua"):
            if (ENTITY_ROOT / "gmod_wire_expression2") in path.parents:
                continue
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            for name in legacy_entity_calls:
                with self.subTest(source=path.relative_to(REPO), name=name):
                    self.assertNotRegex(
                        source,
                        rf"(?<!:)\bACF_{re.escape(name)}\s*\(",
                    )

    def test_entity_ace_globals_are_namespaced(self):
        for path in ENTITY_ROOT.rglob("*.lua"):
            source = code_without_comments_and_strings(
                path.read_text(encoding="utf-8", errors="replace")
            )
            with self.subTest(source=path.relative_to(REPO)):
                self.assertNotRegex(
                    source,
                    r"(?m)^\s*function\s+(?:Make(?:ACF|ACE)_[A-Za-z_]|ACF_[A-Za-z_])",
                )
                self.assertNotRegex(
                    source,
                    r"\bACE_Make(?!(?:Ammo|Gun)\b)[A-Za-z_][A-Za-z0-9_]*\s*=",
                )

    def test_ace_convars_use_modern_names_without_acf_aliases(self):
        globals_source = (LUA_ROOT / "autorun" / "acf_globals.lua").read_text(
            encoding="utf-8"
        )
        for name in ACE_CONVARS:
            with self.subTest(name=name):
                self.assertRegex(
                    globals_source,
                    rf'CreateConVar\(\s*"ace_{re.escape(name)}"',
                )
        for path in non_entity_sources():
            source = path.read_text(encoding="utf-8", errors="replace")
            for name in ACE_CONVARS:
                with self.subTest(source=path.relative_to(REPO), name=name):
                    self.assertNotIn(f'"acf_{name}"', source)


if __name__ == "__main__":
    unittest.main()
