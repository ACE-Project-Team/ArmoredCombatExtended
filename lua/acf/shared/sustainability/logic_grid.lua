--- ACE Sustainability - Electric grid logic (pure, no GMod globals).
--
-- Models the AC/DC tradeoff for moving electricity over distance:
--   * DC is simple but loses a lot over long runs (loss grows with distance).
--   * AC, pushed through transfer stations, loses far less - and the higher the
--     voltage, the lower the line loss - but each DC<->AC conversion at a
--     station costs a fixed slice.
-- So short hops favour cheap DC; spanning a map favours AC + stations.
-- @module logic_grid

local Grid = {}

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

Grid.DCLossPerUnit = 0.00025   -- DC line loss per unit distance (steep)
Grid.ACLossPerUnit = 0.00002   -- AC line loss per unit distance at 1 "voltage"
Grid.ConvLoss      = 0.04      -- lost per DC<->AC conversion at a station
Grid.MaxLoss       = 0.95      -- a line can never lose more than this

--- Fractional line loss over a run.
-- @param distance number source units between endpoints
-- @param voltage number AC voltage (>=1); ignored for DC
-- @param isAC boolean true for an AC line, false/nil for DC
-- @return number 0..MaxLoss
function Grid.LineLoss(distance, voltage, isAC)
	distance = math.max(distance or 0, 0)
	if isAC then
		local v = math.max(voltage or 1, 1)
		return clamp(Grid.ACLossPerUnit * distance / v, 0, Grid.MaxLoss)
	end
	return clamp(Grid.DCLossPerUnit * distance, 0, Grid.MaxLoss)
end

--- Total delivered fraction end-to-end.
-- AC includes two station conversions (source + sink); DC has none.
-- @param distance number source units
-- @param voltage number AC voltage
-- @param isAC boolean
-- @return number 0..1 fraction of energy that arrives
function Grid.Efficiency(distance, voltage, isAC)
	local line = Grid.LineLoss(distance, voltage, isAC)
	if isAC then
		local conv = (1 - Grid.ConvLoss) * (1 - Grid.ConvLoss)
		return conv * (1 - line)
	end
	return 1 - line
end

--- Delivered fraction along a multi-hop station path (the gridless model).
-- The source inverts DC->AC (one conversion), each relay re-boosts (one
-- conversion each), and the sink rectifies AC->DC (one conversion). Each hop
-- loses to distance at the voltage carried over that hop (a relay refreshes the
-- voltage for the hops after it, which is why relays beat distance).
-- @param hops table array of { distance = number, voltage = number } per hop
-- @param relays number count of relay re-boosts along the path (default 0)
-- @return number 0..1 fraction of source energy that reaches the sink
function Grid.PathEfficiency(hops, relays)
	relays = relays or 0
	-- source conversion + sink conversion + one per relay.
	local conversions = 2 + relays
	local eff = (1 - Grid.ConvLoss) ^ conversions

	for _, h in ipairs(hops or {}) do
		eff = eff * (1 - Grid.LineLoss(h.distance, h.voltage, true))
	end

	return clamp(eff, 0, 1)
end

return Grid
