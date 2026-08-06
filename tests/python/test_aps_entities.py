"""Static contracts for the new ACE APS system."""

import re
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
ENTITY_ROOT = ROOT / "lua" / "entities"


class APSEntityTests(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_variants_are_spawnable_and_use_the_shared_base(self):
        for variant in ("ace_aps_static", "ace_aps_gimbal"):
            source = self.read(f"lua/entities/{variant}/shared.lua")
            with self.subTest(variant=variant):
                self.assertIn('ENT.Base = "ace_aps"', source)
                self.assertIn("ENT.Spawnable = true", source)
                self.assertIn("ENT.AdminSpawnable = true", source)

    def test_base_defines_shared_capacity_kill_and_network_contracts(self):
        source = self.read("lua/entities/ace_aps/init.lua")
        for symbol in (
            "function ENT:CanLink",
            "function ENT:Link",
            "function ENT:Unlink",
            "function ENT:PreEntityCopy",
            "function ENT:PostEntityPaste",
            "function ENT:GetCharges()",
            "function ENT:GetKillRange()",
            "function ENT:GetInterceptForGun(target, data, gun)",
            "function ENT:GetInterceptForTarget(target, data)",
            "function ENT:TryEngageTarget(target, data, members)",
            "function ENT:TrackAndEngage()",
            "function ENT:GetNetworkMembers",
            "function ENT:GetNetworkRadars",
            "function ENT:GetNetworkTargets",
            "function ENT:ReportTarget",
        ):
            self.assertIn(symbol, source)

        self.assertIn("self.LinkedGuns = {}", source)
        self.assertIn("ClampAPSConfig", source)
        self.assertIsNone(re.search(r"\bLinkedGun\b", source))
        self.assertIn('Target:GetClass() == "acf_gun"', source)
        self.assertIn('"Maximum number of guns this APS can link."', source)
        self.assertIn('"Outer kill-check range in meters."', source)
        self.assertIn('models/props_lab/reciever01a.mdl', source)

    def test_zaslin_mount_and_round_geometry_contract(self):
        shared = self.read("lua/entities/ace_aps_static/shared.lua")
        source = self.read("lua/entities/ace_aps_static/init.lua")
        base = self.read("lua/entities/ace_aps/init.lua")
        self.assertIn('ENT.APSModel = "models/golem/Zaslin_APS.mdl"', shared)
        self.assertIn("function ENT:UpdateTubeBodygroup()", source)
        self.assertIn("function ENT:MountLinkedGuns()", source)
        self.assertIn("gun:SetParent(self)", source)
        self.assertIn('hook.Add("PlayerUnfrozeObject"', source)
        self.assertIn("function ENT:IsPositionCovered(position)", base)
        self.assertIn("local function GetRoundKillRadius", base)
        self.assertIn("local CentimeterToHU = MeterToHU / 100", base)
        self.assertIn("round.FlechetteSpread", base)
        self.assertIn("return spread + pelletRadius", base)
        self.assertIn("function ENT:GetInterceptForGun", base)
        self.assertIn("GetRoundIntercept", base)
        self.assertIn("self:GetKillRange())", base)
        self.assertIn("KillRange = {0.5, 30}", base)
        self.assertIn("ACE.ActiveMissiles", base)
        self.assertIn("duplicator.StoreEntityModifier(self, \"ACEAPSConfig\"", base)
        self.assertIn("ACE.APSPresets.Zaslin.ReloadTime", shared)
        presets = self.read("lua/entities/ace_aps/shared.lua")
        self.assertIn("Zaslin = {", presets)
        self.assertIn("ReloadTime = 15", presets)
        self.assertIn('RadarSize = "1"', presets)

    def test_gimbal_declares_arc_and_slew_hooks(self):
        shared = self.read("lua/entities/ace_aps_gimbal/shared.lua")
        source = self.read("lua/entities/ace_aps_gimbal/init.lua")
        for symbol in ("ENT.YawRadius", "ENT.PitchRadius", "ENT.SlewRate"):
            self.assertIn(symbol, shared)
        self.assertIn("function ENT:CanGunEngage", source)
        self.assertIn("function ENT:GetGunAim", source)
        self.assertIn("math.ApproachAngle", source)

    def test_menu_and_wire_overlay_contracts_remain_present(self):
        extras = self.read("lua/acf/shared/extras/extras.lua")
        menu = self.read("lua/acf/client/cl_acemenu_gui.lua")
        client = self.read("lua/entities/ace_aps/cl_init.lua")
        tool = self.read("lua/weapons/gmod_tool/stools/acemenu.lua")
        for entity_class in ("ace_aps_static", "ace_aps_gimbal"):
            self.assertIn(f'ent = "{entity_class}"', extras)
            self.assertIn(f'"{entity_class}"', self.read(f"lua/entities/{entity_class}/init.lua"))
        self.assertIn('local apsNode = HomeNode:AddNode("APS", "icon16/shield.png")', menu)
        self.assertIn('ExtrasData.category == "APS"', menu)
        self.assertIn("function ACE.APSMenuGUICreate(data)", menu)
        self.assertIn('ACE.DefineExtras("APS_Zaslin"', extras)
        self.assertIn('apsconfig = {1, 3, 15, 1, 90, 45}', extras)
        self.assertIn("PostDrawHalos", client)
        self.assertIn("ACEAPSNetworkEntities", client)
        self.assertIn("self.SelectedEntities[ent]", tool)
        self.assertNotIn("ent.ACEAPSNetworkEntities", tool)
        self.assertIn("APSOwnedAmmoLinks", self.read("lua/entities/ace_aps/init.lua"))
        self.assertIn("RefreshNetworkHighlight(network)", self.read("lua/entities/ace_aps/init.lua"))

    def test_acf_fire_path_simulates_impact_without_projectile(self):
        source = self.read("lua/entities/acf_gun/init.lua")
        aps = self.read("lua/entities/ace_aps/init.lua")
        for symbol in (
            "function ACE.SimulateAPSImpact",
            "if APSDirectHit then",
            "ACE.SimulateAPSImpact(self, APSDirectHit)",
            "local impactSuccess = ACE.SimulateAPSImpact(self, APSDirectHit)",
            "if not impactSuccess then return false end",
            "not APSDirectHit",
            "DirectExplosionFiller",
        ):
            self.assertIn(symbol, source)
        self.assertIn("if not gun.ACE_APSLastFire then return false end", aps)


if __name__ == "__main__":
    unittest.main()
