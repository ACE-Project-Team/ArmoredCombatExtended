"""Static regression contracts for the entity-facing ACE pipeline.

These checks intentionally inspect the non-entity backend and its adapters. Entity classes remain
out of scope for this namespace slice, but their load/link/fire/track/drive contracts must not be
silently disconnected while the backend names are migrated.
"""

from pathlib import Path
import re
import unittest


REPO = Path(__file__).resolve().parents[2]
LUA = REPO / "lua"
ENTITIES = LUA / "entities"


def source(relative):
    return (LUA / relative).read_text(encoding="utf-8", errors="replace")


class EntityPipelineContractTests(unittest.TestCase):
    def test_loader_keeps_all_entity_backend_definition_families(self):
        loader = source("acf/shared/sh_ace_loader.lua")
        for family in (
            "DefineGun",
            "DefineRack",
            "DefineEngine",
            "DefineGearbox",
            "DefineFuelTank",
            "DefineRadar",
            "DefineTrackRadar",
            "DefineSonar",
            "DefineIRST",
            "DefineExplosive",
            "DefineMine",
        ):
            with self.subTest(family=family):
                self.assertIn(f"function ACE_{family}", loader)

    def test_entity_load_contract_is_present_for_every_mounted_entity(self):
        entity_dirs = [
            path
            for path in ENTITIES.iterdir()
            if path.is_dir() and path.name != "gmod_wire_expression2"
        ]
        self.assertTrue(entity_dirs)
        for entity_dir in entity_dirs:
            init = entity_dir / "init.lua"
            shared = entity_dir / "shared.lua"
            client = entity_dir / "cl_init.lua"
            with self.subTest(entity=entity_dir.name):
                self.assertTrue(init.is_file())
                self.assertTrue(shared.is_file())
                self.assertTrue(client.is_file())
                self.assertRegex(
                    init.read_text(encoding="utf-8", errors="replace"),
                    r"AddCSLuaFile\s*\(\s*[\"']shared\.lua",
                )

    def test_linking_contract_keeps_wheels_racks_and_ammo_links(self):
        base = source("acf/server/sv_acfbase.lua")
        getters = source("acf/shared/sh_acfm_getters.lua")
        functions = source("acf/shared/sh_ace_functions.lua")
        for text, patterns in (
            (base, ("function ACE_GetLinkedWheels", "function ACE_CreateLinkRope", "GearLink", "WheelLink")),
            (getters, ("function ACE_RackCanLoadCaliber", "function ACE_CanLinkRack")),
            (functions, ("AmmoLink", "Master")),
        ):
            for pattern in patterns:
                with self.subTest(pattern=pattern):
                    self.assertIn(pattern, text)

    def test_firing_contract_keeps_input_dispatch_and_bullet_creation(self):
        base = source("acf/server/sv_acfbase.lua")
        ballistics = source("acf/server/sv_acfballistics.lua")
        weapon_base = (REPO / "lua/weapons/weapon_ace_base/init.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertRegex(base, r"Inputs\.Fire")
        self.assertRegex(ballistics, r"function ACE_CreateBullet")
        self.assertRegex(weapon_base, r"ACE_CreateBullet")
        self.assertRegex(ballistics, r"ACE_BulletClient")
        self.assertRegex(ballistics, r"RoundTypes\[Bullet\.Type\]")

    def test_tracking_contract_keeps_radar_registration_and_tracking_definitions(self):
        contraption = source("acf/server/sv_contraption.lua")
        tracking = source("acf/shared/radars/radar_tracking.lua")
        search = source("acf/shared/radars/radar_search.lua")
        self.assertIn("ACE.radarEntities", contraption)
        self.assertIn("table.insert(ACE.radarEntities", contraption)
        self.assertIn("table.remove(ACE.radarEntities", contraption)
        self.assertIn("ACE_DefineTrackRadarClass", tracking)
        self.assertIn("ACE_DefineTrackRadar", tracking)
        self.assertIn("ACE_DefineTrackRadar", search)

    def test_revving_contract_keeps_engine_torque_and_rpm_inputs(self):
        engines = list((LUA / "acf/shared/engines").glob("*.lua"))
        self.assertTrue(engines)
        definitions = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in engines)
        for field in ("torque", "idlerpm", "limitrpm"):
            with self.subTest(field=field):
                self.assertIn(field, definitions)
        heat = source("acf/server/sv_heat.lua")
        self.assertIn("Engine.FlyRPM", heat)
        self.assertIn("function ACE_HeatFromGearbox", heat)

    def test_ace_notification_protocol_is_namespaced(self):
        globals_source = source("autorun/acf_globals.lua")
        networking = source("acf/shared/sv_ace_networking.lua")
        self.assertIn('net.Start( "ACE_Notify" )', globals_source)
        self.assertIn('net.Receive( "ACE_Notify"', globals_source)
        self.assertIn('util.AddNetworkString( "ACE_Notify" )', networking)
        self.assertNotIn('util.AddNetworkString( "notify" )', networking)

    def test_backend_hook_identifiers_are_ace_namespaced(self):
        backend = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (LUA / "acf").rglob("*.lua")
        )
        globals_source = source("autorun/acf_globals.lua")
        combined = backend + "\n" + globals_source
        for legacy in ("ACFPermissions", "CreateACFCategory", "ACF Parented"):
            with self.subTest(legacy=legacy):
                self.assertNotIn(legacy, combined)
        self.assertNotIn('hook.Run("ACFOn', backend)
        self.assertIn('ACE_RunLegacyHook("ACFOnDamage"', backend)
        self.assertIn('ACE_RunLegacyHook("ACFOnBulletCreation"', backend)
        for current in ("ACEOnDamage", "ACEOnBulletCreation", "ACEPermissions", "CreateACECategory"):
            with self.subTest(current=current):
                self.assertIn(current, combined)

    def test_backend_network_channels_are_ace_namespaced(self):
        backend = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (LUA / "acf").rglob("*.lua")
        )
        client = source("autorun/client/cl_acfm_menuinject.lua")
        combined = backend + "\n" + client
        self.assertNotIn('"colorchatmessage"', combined)
        self.assertIn('"ACE_ColorChatMessage"', combined)

    def test_legacy_starfall_boundary_is_gated_and_live(self):
        globals_source = source("autorun/acf_globals.lua")
        starfall = (LUA / "starfall" / "libs_sv" / "acf.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertIn("ACE.LegacyCompatibility = ACECompatibilityView", globals_source)
        self.assertIn('CreateConVar("acf_restrictinfo", 1)', globals_source)
        self.assertIn('if ACECompatibilityView then', globals_source)
        self.assertIn('GetConVar("acf_restrictinfo")', starfall)
        self.assertIn('ACFOnBulletCreation', starfall)
        for legacy_hook in ("ACFOnBulletHit", "ACFOnBulletRicochet", "ACFOnBulletPenetrated"):
            self.assertIn(f'ACE_RunLegacyHook("{legacy_hook}"', source("acf/server/sv_acfballistics.lua"))
        self.assertIn('ACE_LegacyRestrictInfo', globals_source)
        self.assertIn('ACF_OnLoadAddon', globals_source)
        self.assertNotIn('cvars.AddChangeCallback("acf_restrictinfo"', globals_source)
        self.assertNotIn('current:SetInt(tobool(new) and 1 or 0)', globals_source)
        self.assertIn('ACE.GetMaterialData = ACE_GetMaterialData', globals_source)

    def test_entity_backend_calls_resolve_to_ace_implementations(self):
        backend_sources = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in LUA.rglob("*.lua")
        )
        required = (
            "Activate", "BulletClient", "CalcArmor", "CalcBulletFlight", "CalcCurve",
            "CanLinkRack", "Check", "CheckClips", "CheckLegal", "Damage", "GetAllChildren",
            "GetAllPhysicalConstraints", "GetGunValue", "GetHitAngle", "GetLinkedWheels",
            "GetPhysicalParent", "GetRackValue", "HE", "HEKill", "KEShove", "Kinetic",
            "MuzzleVelocity", "PropDamage", "RackCanLoadCaliber", "RenderLight",
            "ScaledExplosion", "SendNotify", "MakeAmmo", "MakeGun",
            "Missile_CompactBulletData", "Missile_CreateConfigurable",
        )
        for name in required:
            with self.subTest(name=name):
                self.assertRegex(
                    backend_sources,
                    rf"(?:function\s+ACE_{name}\b|ACE_{name}\s*=)",
                )

    def test_dotted_ace_calls_have_ace_global_exports(self):
        backend_sources = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in LUA.rglob("*.lua")
        )
        called = set(re.findall(r"\bACE\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", backend_sources))
        exported = set(re.findall(r"(?:function\s+|\b)ACE_([A-Za-z_][A-Za-z0-9_]*)\b", backend_sources))
        explicitly_dotted = set(re.findall(r"function\s+ACE\.([A-Za-z_][A-Za-z0-9_]*)\b", backend_sources))
        explicitly_assigned = set(re.findall(r"\bACE\.([A-Za-z_][A-Za-z0-9_]*)\s*=", backend_sources))
        bridged = "string.StartWith(Name, \"ACE_\")" in backend_sources

        self.assertTrue(bridged)
        missing = sorted(
            name for name in called
            if name not in exported and name not in explicitly_dotted and name not in explicitly_assigned
        )
        self.assertEqual([], missing)


if __name__ == "__main__":
    unittest.main()
