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
        loader = source("ace/shared/sh_ace_loader.lua")
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
                self.assertIn(f"function ACE.{family}", loader)

    def test_crewseat_gui_loader_uses_migrated_menu_namespace(self):
        loader = source("ace/shared/sh_ace_loader.lua")
        self.assertIn("ACE.CrewMenuGUICreate", loader)
        self.assertNotIn("ACECrewseatGUICreate", loader)

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
        base = source("ace/server/sv_acfbase.lua")
        getters = source("ace/shared/sh_acfm_getters.lua")
        functions = source("ace/shared/sh_ace_functions.lua")
        for text, patterns in (
            (base, ("function ACE.GetLinkedWheels", "function ACE.CreateLinkRope", "GearLink", "WheelLink")),
            (getters, ("function ACE.RackCanLoadCaliber", "function ACE.CanLinkRack")),
            (functions, ("AmmoLink", "Master")),
        ):
            for pattern in patterns:
                with self.subTest(pattern=pattern):
                    self.assertIn(pattern, text)

    def test_rack_firepower_readout_explains_the_additive_round_cost(self):
        functions = source("ace/shared/sh_ace_functions.lua")
        self.assertIn("local isRack = class == \"acf_rack\"", functions)
        self.assertIn(
            "local flooredRawPoints = flooredRate * roundScore * firepowerScale + baseRoundCostPoints",
            functions,
        )
        self.assertIn(
            "Rack delivery: %s pts + %s base-round pts = %s pts",
            functions,
        )
        self.assertIn(
            "%.1f rpm / 60; %s delivery pts + %s base-round pts",
            functions,
        )
        self.assertIn(
            "FinalScore = ACE.Points.RackCostFromRate(rate, roundScore, baseRoundCost)",
            functions,
        )
        for field in (
            "Points = points",
            "DeliveryPoints = points - baseRoundCostPoints",
            "BaseRoundCostPoints = baseRoundCostPoints",
            "IsRack = isRack",
        ):
            with self.subTest(field=field):
                self.assertIn(field, functions)

    def test_firing_contract_keeps_input_dispatch_and_bullet_creation(self):
        base = source("ace/server/sv_acfbase.lua")
        ballistics = source("ace/server/sv_acfballistics.lua")
        weapon_base = (REPO / "lua/weapons/weapon_ace_base/init.lua").read_text(
            encoding="utf-8", errors="replace"
        )
        self.assertRegex(base, r"Inputs\.Fire")
        self.assertRegex(ballistics, r"function ACE.CreateBullet")
        self.assertRegex(weapon_base, r"ACE\.CreateBullet")
        self.assertRegex(ballistics, r"ACE\.BulletClient")
        self.assertRegex(ballistics, r"RoundTypes\[Bullet\.Type\]")

    def test_tracking_contract_keeps_radar_registration_and_tracking_definitions(self):
        contraption = source("ace/server/sv_contraption.lua")
        tracking = source("ace/shared/radars/radar_tracking.lua")
        search = source("ace/shared/radars/radar_search.lua")
        self.assertIn("ACE.radarEntities", contraption)
        self.assertIn("table.insert(ACE.radarEntities", contraption)
        self.assertIn("table.remove(ACE.radarEntities", contraption)
        self.assertIn("ACE.DefineTrackRadarClass", tracking)
        self.assertIn("ACE.DefineTrackRadar", tracking)
        self.assertIn("ACE.DefineTrackRadar", search)

    def test_radar_missile_guidance_distinguishes_jam_state_and_owner_radars(self):
        radar = source("ace/shared/guidances/f_radar.lua")
        semi = source("ace/shared/guidances/i_radarsemi.lua")
        self.assertIn("if missile.IsJammed == 0 then", radar)
        self.assertIn("if missile.IsJammed == 0 then", semi)
        self.assertIn("if scanEnt:CPPIGetOwner() ~= missile.DamageOwner then continue end", semi)
        self.assertNotIn("if not missile.IsJammed then", radar)
        self.assertNotIn("if not missile.IsJammed then", semi)

    def test_revving_contract_keeps_engine_torque_and_rpm_inputs(self):
        engines = list((LUA / "ace/shared/engines").glob("*.lua"))
        self.assertTrue(engines)
        definitions = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in engines)
        for field in ("torque", "idlerpm", "limitrpm"):
            with self.subTest(field=field):
                self.assertIn(field, definitions)
        heat = source("ace/server/sv_heat.lua")
        self.assertIn("Engine.FlyRPM", heat)
        self.assertIn("function ACE.HeatFromGearbox", heat)

    def test_ace_notification_protocol_is_namespaced(self):
        globals_source = source("autorun/acf_globals.lua")
        networking = source("ace/shared/sv_ace_networking.lua")
        self.assertIn('net.Start( "ACE_Notify" )', globals_source)
        self.assertIn('net.Receive( "ACE_Notify"', globals_source)
        self.assertIn('util.AddNetworkString( "ACE_Notify" )', networking)
        self.assertNotIn('util.AddNetworkString( "notify" )', networking)

    def test_backend_hook_identifiers_are_ace_namespaced(self):
        backend = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (LUA / "ace").rglob("*.lua")
        )
        globals_source = source("autorun/acf_globals.lua")
        combined = backend + "\n" + globals_source
        for legacy in ("ACFPermissions", "CreateACFCategory", "ACF Parented"):
            with self.subTest(legacy=legacy):
                self.assertNotIn(legacy, combined)
        self.assertNotIn('hook.Run("ACFOn', backend)
        self.assertIn('hook.Run("ACEOnDamage"', backend)
        self.assertIn('hook.Run("ACEOnBulletCreation"', backend)
        for current in (
            "ACEOnDamage", "ACEOnBulletCreation", "ACEOnBulletRemoved",
            "ACEOnBulletPenetrated", "ACEOnBulletRicochet", "ACEOnBulletHit",
            "ACEPermissions", "CreateACECategory",
        ):
            with self.subTest(current=current):
                self.assertIn(current, combined)
        self.assertIn('"ACE_RestoreSZsCleanup"', source("ace/server/sv_acfpermission.lua"))
        self.assertIn('"ACE_RenderDamageInitialSpawn"', globals_source)
        missiles = source("autorun/server/sv_acf_missiles.lua")
        self.assertIn('"ACE_Missiles_DupeDeny"', missiles)
        self.assertIn('"ACE_Missiles_AddLinkable"', missiles)

    def test_legacy_hook_events_forward_to_ace_namespaced_events(self):
        globals_source = source("autorun/acf_globals.lua")
        self.assertNotIn("RemoveCompatibilityView", globals_source)
        self.assertNotIn("ACF_OnLoadAddon", globals_source)

        ballistics = source("ace/server/sv_acfballistics.lua")
        for name in (
            "BulletCreation", "BulletRemoved", "BulletPenetrated", "BulletRicochet", "BulletHit",
        ):
            with self.subTest(name=name):
                self.assertIn(f'hook.Run("ACEOn{name}"', ballistics)
                self.assertEqual(ballistics.count(f'hook.Run("ACEOn{name}"'), 1)

        damage = source("ace/server/sv_acfbase.lua")
        self.assertIn('hook.Run("ACEOnDamage"', damage)

    def test_backend_network_channels_are_ace_namespaced(self):
        backend = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in (LUA / "ace").rglob("*.lua")
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
        self.assertIn('CreateConVar("ace_restrictinfo", 1)', globals_source)
        self.assertIn('GetConVar("ace_restrictinfo")', starfall)
        self.assertIn('ACEOnBulletCreation', starfall)
        for legacy_hook in ("ACFOnBulletHit", "ACFOnBulletRicochet", "ACFOnBulletPenetrated"):
            self.assertNotIn(legacy_hook, source("ace/server/sv_acfballistics.lua"))
        self.assertNotIn('ACE_LegacyRestrictInfo', globals_source)
        self.assertNotIn('ACF_OnLoadAddon', globals_source)
        self.assertNotIn('cvars.AddChangeCallback("acf_restrictinfo"', globals_source)
        self.assertNotIn('current:SetInt(tobool(new) and 1 or 0)', globals_source)
        self.assertNotIn('ACE.GetMaterialData = ACE_GetMaterialData', globals_source)

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
                    rf"(?:function\s+ACE\.{name}\b|ACE\.{name}\s*=)",
                )

    def test_dotted_ace_calls_have_ace_global_exports(self):
        backend_sources = "\n".join(
            path.read_text(encoding="utf-8", errors="replace")
            for path in LUA.rglob("*.lua")
        )
        called = set(re.findall(r"\bACE\.([A-Za-z_][A-Za-z0-9_]*)\s*\(", backend_sources))
        exported = set(re.findall(r"(?:function\s+|\b)ACE\.([A-Za-z_][A-Za-z0-9_]*)\b", backend_sources))
        explicitly_dotted = set(re.findall(r"function\s+ACE\.([A-Za-z_][A-Za-z0-9_]*)\b", backend_sources))
        explicitly_assigned = set(re.findall(r"\bACE\.([A-Za-z_][A-Za-z0-9_]*)\s*=", backend_sources))
        missing = sorted(
            name for name in called
            if name not in exported and name not in explicitly_dotted and name not in explicitly_assigned
        )
        self.assertEqual([], missing)


if __name__ == "__main__":
    unittest.main()
