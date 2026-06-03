--- Fault tests: short circuit is OVER-CURRENT ONLY now.
--
-- The main in-game bug was false shorts on every step-up/down boundary, caused by
-- the old "neighbour voltages differ -> short" heuristic. Voltage is path-based
-- now (one voltage per energised segment), so Fault.Short keys solely off current
-- vs ampacity. These pin that down.

local H = dofile((_G.ACE_TEST_DIR or "./") .. "helpers.lua")
local F = H.load("logic_fault")

suite("short circuit = over-current only")
do
	-- cap 10 kW, trip threshold = cap * ShortFactor (3) = 30 kW.
	local sIn = F.Short{ energized = true, capacityKW = 10, currentKW = 5 }
	check(sIn == false, "in-spec current does not short")

	local sStep = F.Short{ energized = true, capacityKW = 10, currentKW = 25 }
	check(sStep == false, "moderate over-load (under 3x) does not short - no false step-up short")

	local sOver, faultKW, heat, cause = F.Short{ energized = true, capacityKW = 10, currentKW = 50 }
	check(sOver == true, "current above 3x ampacity shorts")
	check(cause == "amp", "the only short cause is over-current ('amp')")
	check(faultKW >= 30, "fault current is at least the trip threshold")
	check(heat > 0, "a short dumps heat")

	local sDead = F.Short{ energized = false, capacityKW = 10, currentKW = 9999 }
	check(sDead == false, "an un-energised conductor never shorts")
end

suite("hazard gating")
do
	check(F.IsHazard{ voltage = 5, energized = true, overCurrent = 100 } == false,
		"low-voltage node is never a shock hazard")
	check(F.IsHazard{ voltage = 100, energized = true, overCurrent = 50 } == true,
		"overloaded high-voltage live node is a hazard")
	check(F.IsHazard{ voltage = 100, energized = false, broken = true } == false,
		"a dead (un-energised) node is safe even if broken")
end
