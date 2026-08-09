"""Static contracts for decoupled engine activation and operation state."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


def source(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


class EngineActivationContractTests(unittest.TestCase):
    def test_activation_is_not_gated_by_legality_or_prerequisites(self):
        engine = source("lua/entities/acf_engine/init.lua")
        active_input = engine[engine.index('elseif (iname == "Active") then') :]

        self.assertIn("if (value > 0 and not self.Active) then", active_input)
        self.assertIn("self.Active = true", active_input)
        self.assertIn('"No Fuel"', active_input)
        self.assertIn('"No Driver"', active_input)
        self.assertIn("and ACE.RequireEntityLegal(self) then", active_input)
        self.assertIn("local EntityLegal = self.Active and ACE.RequireEntityLegal(self)", engine)
        self.assertIn("if self.ActivationIssue then", engine)
        self.assertNotIn('and ACE.RequireEntityLegal(self)) then', active_input)

    def test_missing_operational_inputs_clear_output_without_deactivating(self):
        engine = source("lua/entities/acf_engine/init.lua")
        calc = engine[engine.index("function ENT:CalcRPM()") :]

        self.assertIn("function ENT:ClearEngineOutput()", engine)
        self.assertIn("function ENT:StartEngineOutput()", engine)
        self.assertIn("self.Operational = false", engine)
        self.assertIn("self:StartEngineOutput()", calc)
        self.assertIn('self.ActivationIssue = table.concat(Missing, "\\n")', calc)
        self.assertIn("self:ClearEngineOutput()", calc)
        self.assertNotIn('self:TriggerInput( "Active", 0 )', calc)
        self.assertIn('self.ActivationIssue = #Missing > 0 and table.concat(Missing, "\\n") or nil', engine)

    def test_heat_tracks_operational_state(self):
        heat = source("lua/acf/server/sv_heat.lua")
        heat_function = heat[heat.index("function ACE_HeatFromEngine") : heat.index("function ACE_HeatFromRadar")]

        self.assertIn("if Engine.Operational then", heat_function)
        self.assertNotIn("if Engine.Active then", heat_function)

    def test_gunner_popup_is_only_an_operational_failure(self):
        gun = source("lua/entities/acf_gun/init.lua")
        overlay = gun[gun.index("function ENT:UpdateOverlayText()") :]

        self.assertIn("if self.CrewIssue then", overlay)
        self.assertNotIn("or (\"Won't fire: needs a gunner", overlay)

    def test_pasted_fuel_links_retry_after_parent_restoration(self):
        engine = source("lua/entities/acf_engine/init.lua")
        paste = engine[engine.index("function ENT:PostEntityPaste") :]

        self.assertIn("deferredFuelLinks", paste)
        self.assertIn("timer.Simple(0.1, RestoreFuelLinks)", paste)

    def test_illegal_crew_seats_remain_linked_for_recovery(self):
        for relative in (
            "lua/entities/ace_crewseat_driver/init.lua",
            "lua/entities/ace_crewseat_gunner/init.lua",
            "lua/entities/ace_crewseat_loader/init.lua",
        ):
            with self.subTest(relative=relative):
                seat = source(relative)
                think = seat[seat.index("function ENT:Think()") :]
                self.assertNotIn(":Unlink(", think)

                if "driver" in relative:
                    self.assertIn("table.HasValue( Link.CrewLink, self )", seat)
                elif "gunner" in relative:
                    self.assertIn("table.HasValue(Link.CrewLink, self)", seat)


if __name__ == "__main__":
    unittest.main()
