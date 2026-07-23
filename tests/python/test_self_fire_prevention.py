"""Static contracts for contraption-wide projectile self-fire prevention."""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]


def source(relative):
    return (REPO / relative).read_text(encoding="utf-8")


class SelfFirePreventionTests(unittest.TestCase):
    def test_contraption_owns_a_live_bullet_filter(self):
        cfw = source("lua/cfw/extensions/ace_sv.lua")

        self.assertIn('hook.Add("cfw.contraption.created", "CFW_ACE_BulletFilter"', cfw)
        self.assertIn("con.BulletFilter = {}", cfw)
        self.assertIn('hook.Add("cfw.contraption.entityAdded", "CFW_ACE_Entities"', cfw)
        self.assertIn("con.BulletFilter[#con.BulletFilter + 1] = ent", cfw)
        self.assertIn('hook.Add("cfw.contraption.entityRemoved", "CFW_ACE_BulletFilter"', cfw)
        self.assertIn("table.remove(filter, index)", cfw)

    def test_gun_passes_the_live_filter_to_the_bullet_snapshot(self):
        gun = source("lua/entities/acf_gun/init.lua")
        ballistics = source("lua/acf/server/sv_acfballistics.lua")
        fire = gun[gun.index("function ENT:FireShell") :]

        self.assertIn("local Contraption = self:CFW_GetContraption()", fire)
        self.assertIn(
            "local BulletFilter = Contraption and Contraption.BulletFilter",
            fire,
        )
        self.assertIn("self.BulletData.Filter = BulletFilter or { self }", fire)
        self.assertIn("self.BulletData.Pos = MuzzlePos", fire)
        self.assertIn("local ParentVelocity = IsValid(Parent) and Parent:GetVelocity() or vector_origin", fire)
        self.assertNotIn("TestVel", fire)
        self.assertLess(fire.index("self.BulletData.Filter"), fire.index("self.CreateShell"))
        self.assertIn("local HasGun = false", ballistics)
        self.assertIn("if Gun and not HasGun then", ballistics)

        flechette = source("lua/acf/shared/rounds/roundfl.lua")
        self.assertIn('FlechetteData["Filter"]', flechette)

        for relative in (
            "lua/acf/shared/rounds/roundclusterap.lua",
            "lua/acf/shared/rounds/roundclusterhe.lua",
            "lua/acf/shared/rounds/roundclusterheat.lua",
        ):
            with self.subTest(round=relative):
                cluster = source(relative)
                self.assertIn("local Filter = istable(bdata.Filter) and table.Copy(bdata.Filter) or { GEnt }", cluster)
                self.assertIn('BulletDataC["Filter"]\t\t= Filter', cluster)


if __name__ == "__main__":
    unittest.main()
