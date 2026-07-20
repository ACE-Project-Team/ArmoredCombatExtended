"""Static contracts for the shared ballistics constants and scheduler boundaries."""

from pathlib import Path
import unittest


REPO = Path(__file__).resolve().parents[2]
BALLISTICS = REPO / "lua" / "acf" / "server" / "sv_acfballistics.lua"
MISSILES = REPO / "lua" / "autorun" / "server" / "sv_acf_missiles.lua"


class BallisticsContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ballistics = BALLISTICS.read_text(encoding="utf-8")
        cls.missiles = MISSILES.read_text(encoding="utf-8")

    def test_missile_conversion_uses_cached_gravity_vector(self):
        self.assertIn("ret.Accel\t= ACF.BallisticsGravityVector", self.missiles)
        self.assertNotIn('ret.Accel\t= cvarGrav', self.missiles)

    def test_scheduler_has_explicit_visibility_and_impact_limits(self):
        self.assertIn("VisibilityRetries = 50", self.ballistics)
        self.assertIn("Impacts = 100", self.ballistics)
        self.assertIn("visCount < ACE.BallisticsLimits.VisibilityRetries", self.ballistics)
        self.assertIn("Bullet.ImpactCount > ACE.BallisticsLimits.Impacts", self.ballistics)

    def test_active_bullet_iteration_uses_registration(self):
        self.assertIn("local ActiveBullets = {}", self.ballistics)
        self.assertIn("ACF_RegisterBullet", self.ballistics)
        self.assertIn("UnregisterBullet", self.ballistics)
        self.assertNotIn("for Index, Bullet in pairs(ACF.Bullet) do\n\t\tACF_CalcBulletFlight", self.ballistics)


if __name__ == "__main__":
    unittest.main()
