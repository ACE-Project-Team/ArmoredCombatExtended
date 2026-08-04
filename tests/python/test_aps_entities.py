"""Static contracts for the ACE APS entity variants."""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
ENTITY_ROOT = REPO / "lua" / "entities"


class APSEntityTests(unittest.TestCase):
    def test_variants_inherit_from_aps_and_are_spawnable(self):
        for variant in ("ace_aps_static", "ace_aps_gimbal"):
            source = (ENTITY_ROOT / variant / "shared.lua").read_text(encoding="utf-8")
            with self.subTest(variant=variant):
                self.assertIn('ENT.Base = "ace_aps"', source)
                self.assertIn("ENT.Spawnable = true", source)
                self.assertIn("ENT.AdminSpawnable = true", source)

    def test_wire_draw_path_uses_look_at_overlay(self):
        source = (ENTITY_ROOT / "ace_aps" / "cl_init.lua").read_text(encoding="utf-8")
        self.assertIn("self:DoNormalDraw(false, false)", source)
        self.assertIn("Wire_Render(self)", source)

    def test_base_aps_owns_link_and_duplication_contracts(self):
        source = (ENTITY_ROOT / "ace_aps" / "init.lua").read_text(encoding="utf-8")

        for symbol in (
            "function ENT:CanLink",
            "function ENT:Link",
            "function ENT:Unlink",
            "function ENT:PreEntityCopy",
            "function ENT:PostEntityPaste",
			"function ENT:IsLinkableAPS",
			"function ENT:GetNetworkMembers",
			"function ENT:GetNetworkRadars",
			"function ENT:GetNetworkTargets",
			"function ENT:ReportTarget",
			"function ENT:ClearTargetReport",
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, source)

        self.assertIn('acf_missileradar = true', source)
        self.assertIn('Target:GetClass() == "acf_gun"', source)
        self.assertIn('models/props_lab/reciever01a.mdl', source)
        self.assertIn('BaseClass.Initialize(self)', source)
        self.assertIn('BaseClass.PreEntityCopy(self)', source)
        self.assertIn('BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)', source)
        self.assertIn('function ACE.MakeAPS', source)
        self.assertNotIn('ACE_MakeAPS', source)
        self.assertIn('self.CanUpdate = true', source)
        self.assertIn('function ENT:Update(_ArgsTable)', source)
        self.assertIn('APS properties are not configurable yet.', source)
        self.assertIn('APSInputDescriptions', source)
        self.assertIn('APSOutputDescriptions', source)
        self.assertIn('"Enables or disables the APS scaffold."', source)
        self.assertIn('"Current active state."', source)
        self.assertIn('"Number of linked missile radars."', source)
        self.assertIn('"Whether an ACF gun is linked."', source)
        self.assertIn('"Whether this is the gimbal variant."', source)
        self.assertIn('ENT.IsAPS = true', (ENTITY_ROOT / "ace_aps" / "shared.lua").read_text(encoding="utf-8"))
        self.assertIn('Target:GetClass() == "acf_gun"', source)
        self.assertIn('self.APSLinks[Target] = true', source)
        self.assertIn('Target.APSLinks[self] = true', source)
        self.assertIn('local function EnsureAPSState(aps)', source)
        self.assertIn('aps.APSLinks = aps.APSLinks or {}', source)
        self.assertIn('aps.TargetReports = aps.TargetReports or {}', source)
        self.assertIn('RefreshNetworkState(self.APSNetwork)', source)
        self.assertIn('apsEntities = apsEntityIDs', source)
        self.assertIn('"Network Count"', source)
        self.assertIn('"Network Radar Count"', source)
        self.assertIn('"Network Target Count"', source)

    def test_menu_defines_both_spawnable_aps_choices(self):
        extras = (REPO / "lua" / "acf" / "shared" / "extras" / "extras.lua").read_text(
            encoding="utf-8"
        )
        menu = (REPO / "lua" / "acf" / "client" / "cl_acemenu_gui.lua").read_text(
            encoding="utf-8"
        )

        for entity_class in ("ace_aps_static", "ace_aps_gimbal"):
            with self.subTest(entity_class=entity_class):
                self.assertIn(f'ent = "{entity_class}"', extras)
                variant_source = (ENTITY_ROOT / entity_class / "init.lua").read_text(encoding="utf-8")
                self.assertIn(f'"{entity_class}"', variant_source)
                self.assertIn('function ENT:SpawnFunction', variant_source)
                self.assertIn('ACE.MakeAPS', variant_source)

        static_source = (ENTITY_ROOT / "ace_aps_static" / "init.lua").read_text(encoding="utf-8")
        static_shared = (ENTITY_ROOT / "ace_aps_static" / "shared.lua").read_text(encoding="utf-8")
        self.assertIn('models/golem/Zaslin_APS.mdl', static_shared)
        self.assertIn('ENT.GunMountOffset = Vector(0, 28, 0)', static_shared)
        self.assertIn('ENT.GunMountAngle = Angle(0, 90, 0)', static_shared)
        self.assertIn('function ENT:MountLinkedGun', static_source)
        self.assertIn('function ENT:Update(ArgsTable)', static_source)
        self.assertIn('gun:SetParent(self)', static_source)
        self.assertIn('function ENT:DetachMountedGun', static_source)
        self.assertIn('function ENT:Unlink(Target)', static_source)
        self.assertIn('hook.Add("PlayerUnfrozeObject"', static_source)
        self.assertIn('constraint.GetAllConstrainedEntities(root)', static_source)
        self.assertIn('local function GetParentRoot(entity)', static_source)

        self.assertIn('local apsNode = HomeNode:AddNode("APS", "icon16/shield.png")', menu)
        self.assertIn('ExtrasData.category == "APS"', menu)
        tool = (REPO / "lua" / "weapons" / "gmod_tool" / "stools" / "acemenu.lua").read_text(encoding="utf-8")
        self.assertIn('e1.IsAPS or APSClasses[e1:GetClass()]', tool)
        self.assertIn('e2.IsAPS or APSClasses[e2:GetClass()]', tool)


if __name__ == "__main__":
    unittest.main()
