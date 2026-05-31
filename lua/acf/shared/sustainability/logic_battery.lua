--- ACE Sustainability - Battery logic (pure, no GMod globals).
--
-- Layered on top of the existing "Electric" fuel tank. Adds three things: a
-- charge-rate limit (you can't dump a megawatt into a phone battery),
-- round-trip efficiency (energy is lost charging/discharging), and wear -
-- every equivalent full cycle nibbles capacity away. Hard use makes heat too.
--
-- State is a plain table the caller owns; this module mutates it and returns a
-- summary of what happened. State fields:
--   baseCapacity  - kWh design capacity
--   capacity      - kWh current usable max (= baseCapacity * health)
--   charge        - kWh currently stored
--   health        - 0..1 capacity multiplier
--   cycleCount    - number of equivalent full cycles
--   throughput    - kWh moved through the cell toward the next cycle tick
--   maxChargeRate - kW power cap
-- @module logic_battery

local Battery = {}

Battery.ChargeEff       = 0.95     -- one-way efficiency (applied both directions)
Battery.DegradePerCycle = 0.0006   -- health lost per equivalent full cycle (~80% @ ~330 cyc)
Battery.MinHealth       = 0.50     -- batteries never wear below 50% usable
-- Internal-resistance heating. Physically heat ~ I^2*R, i.e. proportional to the
-- C-rate squared (power relative to capacity), NOT to absolute kW - otherwise a
-- big battery charged fast would melt while a small one at the same C-rate barely
-- warms. HeatPerC2 is the watts produced at 1C; MaxHeatW clamps it so very high
-- (gamey) fast-charge C-rates warm the cell without instantly cooking it.
Battery.HeatPerC2       = 20000    -- W of internal-resistance heat at 1C
Battery.MaxHeatW        = 300000   -- clamp on internal-resistance heat (W)
Battery.InternalResK    = 4.0      -- (legacy, unused by the C-rate heat model)
-- Heat-based rate derating: a hot battery can't move power as fast. Above
-- DerateStart the max charge/discharge rate falls linearly toward Floor at
-- DerateEnd. (Future radiators will keep the battery in the safe band.)
Battery.RateDerateStart = 45       -- C, below this the full rate is available
Battery.RateDerateEnd   = 75       -- C, at/above this the rate is at the floor
Battery.RateDerateFloor = 0.30     -- never below 30% of the rated C-rate
Battery.RateKWperKWh    = 2        -- charge-rate cap defaults to 2C if not given
-- CC/CV charging: Li-ion takes full current up to ~80% state of charge, then the
-- charge current tapers toward zero as it tops off (constant-voltage phase). This
-- only limits CHARGING; discharge always gets the full rate cap.
Battery.CVThreshold     = 0.80     -- SoC above which the charge rate starts tapering
Battery.CVMinRate       = 0.05     -- floor on the taper so it still finishes (never literally 0)

local KWH_TO_J = 3.6e6

--- Rate-derate multiplier (0..1) for a given battery temperature (C).
-- Full rate below RateDerateStart, linearly down to RateDerateFloor at
-- RateDerateEnd. Used so a hot battery charges/discharges slower.
-- @param tempC number battery temperature in Celsius
-- @return number multiplier in [RateDerateFloor, 1]
function Battery.RateDerate(tempC)
	tempC = tempC or 20
	local lo, hi = Battery.RateDerateStart, Battery.RateDerateEnd
	if tempC <= lo then return 1 end
	if tempC >= hi then return Battery.RateDerateFloor end
	local f = (tempC - lo) / math.max(hi - lo, 1e-6)
	return 1 - f * (1 - Battery.RateDerateFloor)
end

--- Recompute usable capacity from base * health and clamp stored charge.
-- @param state table battery state (mutated)
-- @return number the new usable capacity (kWh)
function Battery.RefreshCapacity(state)
	state.capacity = state.baseCapacity * state.health
	if state.charge > state.capacity then state.charge = state.capacity end
	return state.capacity
end

--- Fill defaults for a fresh battery (or after a capacity change).
-- @param state table battery state (mutated)
-- @param baseCapacity number design capacity (kWh)
-- @param opts table optional { maxChargeRate = kW }
-- @return table the same state table
function Battery.Init(state, baseCapacity, opts)
	opts = opts or {}
	state.baseCapacity  = baseCapacity
	state.health        = state.health or 1
	state.cycleCount    = state.cycleCount or 0
	state.throughput    = state.throughput or 0
	state.maxChargeRate = opts.maxChargeRate or (baseCapacity * Battery.RateKWperKWh)
	Battery.RefreshCapacity(state)
	if state.charge == nil then state.charge = 0 end
	return state
end

--- Advance the battery one step.
-- @param state table battery state (mutated; see module header)
-- @param requestKWh number energy at the terminals this step (+ charge, - discharge)
-- @param dt number timestep (s)
-- @param cfg table optional overrides { chargeEff, degradePerCycle, internalResK }
-- @return table {
--   delta     = signed change in stored charge (kWh),
--   delivered = kWh delivered to the load when discharging (>=0),
--   terminal  = energy consumed (charge) / delivered (discharge) at terminals,
--   heatAddJ  = heat generated this step (J),
--   cycles    = whole cycles ticked over this step }
function Battery.Step(state, requestKWh, dt, cfg)
	cfg = cfg or {}
	local eff       = cfg.chargeEff or Battery.ChargeEff
	local degrade   = cfg.degradePerCycle or Battery.DegradePerCycle
	local resK      = cfg.internalResK or Battery.InternalResK
	dt = dt or 0

	local result = { delta = 0, delivered = 0, terminal = 0, heatAddJ = 0, cycles = 0 }
	if dt <= 0 or requestKWh == 0 then return result end

	-- Power cap (kWh this step). Discharge gets the full rate; charging tapers
	-- once past the CV threshold (the realistic "slows down after ~80%" effect).
	local maxStep   = state.maxChargeRate * dt / 3600
	local chargeCap = maxStep
	local cvT = cfg.cvThreshold or Battery.CVThreshold
	local cvM = cfg.cvMinRate or Battery.CVMinRate
	if requestKWh > 0 and state.capacity > 0 then
		local soc = state.charge / state.capacity
		if soc > cvT then
			local f = (1 - soc) / math.max(1 - cvT, 1e-6)
			if f < cvM then f = cvM elseif f > 1 then f = 1 end
			chargeCap = maxStep * f
		end
	end
	if requestKWh > chargeCap then requestKWh = chargeCap
	elseif requestKWh < -maxStep then requestKWh = -maxStep end

	local cellDelta = 0   -- signed change to stored charge
	local lossKWh   = 0
	local delivered = 0
	local terminal  = 0   -- energy consumed (charge) / delivered (discharge) at terminals

	if requestKWh > 0 then
		-- Charging: some energy lost as heat, rest stored, capped by room.
		local stored = requestKWh * eff
		local room   = state.capacity - state.charge
		if stored > room then stored = room end
		cellDelta = stored
		-- Loss is proportional to what actually went in.
		lossKWh = (eff > 0) and (stored * (1 - eff) / eff) or 0
		terminal = (eff > 0) and (stored / eff) or stored
	else
		-- Discharging: pull from the cell, deliver less than pulled.
		local want = -requestKWh
		local fromCell = want
		if fromCell > state.charge then fromCell = state.charge end
		cellDelta = -fromCell
		delivered = fromCell * eff
		lossKWh = fromCell * (1 - eff)
		terminal = delivered
	end

	state.charge = state.charge + cellDelta

	-- Heat: conversion losses + internal-resistance heating (∝ C-rate², clamped).
	local powerKW   = math.abs(requestKWh) / (dt / 3600)
	local cRate     = (state.capacity > 0) and (powerKW / state.capacity) or 0
	local lossW     = (dt > 0) and (lossKWh * KWH_TO_J / dt) or 0
	local resW      = (cfg.heatPerC2 or Battery.HeatPerC2) * cRate * cRate
	local heatW     = math.min(lossW + resW, cfg.maxHeatW or Battery.MaxHeatW)
	local heatJ     = heatW * dt

	-- Wear: accumulate throughput, tick a cycle each time we've moved a
	-- full (current) capacity's worth of energy through the cell.
	state.throughput = state.throughput + math.abs(cellDelta)
	local cyc = 0
	while state.capacity > 0 and state.throughput >= state.capacity do
		state.throughput = state.throughput - state.capacity
		state.cycleCount = state.cycleCount + 1
		cyc = cyc + 1
		state.health = state.health - degrade
		if state.health < Battery.MinHealth then state.health = Battery.MinHealth end
		Battery.RefreshCapacity(state)
	end

	result.delta     = cellDelta
	result.delivered = delivered
	result.terminal  = terminal
	result.heatAddJ  = heatJ
	result.cycles    = cyc
	return result
end

Battery.KWH_TO_J = KWH_TO_J

return Battery
