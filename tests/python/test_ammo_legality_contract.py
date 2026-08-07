"""Static contracts for the ammo crate legality transition."""

from pathlib import Path
import unittest


SOURCE = (Path(__file__).resolve().parents[2] / "lua/entities/acf_ammo/init.lua").read_text(
    encoding="utf-8"
)


class AmmoLegalityContractTests(unittest.TestCase):
    def test_think_uses_cached_legality_and_unloads_after_periodic_recheck(self):
        think = SOURCE[SOURCE.index("function ENT:Think()") :]

        self.assertNotIn("local currentLegal = ACE.RequireEntityLegal(self)", think)
        self.assertIn("if active and self.Legal and not self.Load then", think)
        self.assertIn("if not self.Legal then", think)
        self.assertIn("or not self.Legal then", think)


if __name__ == "__main__":
    unittest.main()
