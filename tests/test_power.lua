--- Power logic tests: voltage sag, capacity, and the new over-voltage heat that
-- drives per-device overheating.

local H = dofile((_G.ACE_TEST_DIR or "./") .. "helpers.lua")
local P = H.load("logic_power")

suite("capacity scales with voltage")
do
	near(P.Capacity(2, 100), 200, "P = I*V")
	check(P.Capacity(2, 200) > P.Capacity(2, 100), "same conductor carries more at higher voltage")
end

suite("voltage sags under shortfall")
do
	local full = P.Delivered(100, 50, 50)
	near(full.voltage, 100, "voltage held when supply meets demand")
	local sag = P.Delivered(100, 25, 50)
	near(sag.voltage, 50, "voltage halves when supply is half the demand")
end

suite("over-voltage breakdown + heat")
do
	near(P.Breakdown(120, 120), 0, "at rating there is no breakdown")
	near(P.Breakdown(60, 120),  0, "under rating there is no breakdown")
	check(P.Breakdown(240, 120) > 0, "above rating breakdown is positive")

	near(P.OverVoltageHeat(0, 100), 0, "in-spec load makes no over-voltage heat")
	local h = P.OverVoltageHeat(P.Breakdown(240, 120), 50)
	check(h > 0, "over-volted load generates heat")
	-- Heat scales with both breakdown and the load drawn.
	check(P.OverVoltageHeat(P.Breakdown(240, 120), 100) > h, "more load over-volted = more heat")
end
