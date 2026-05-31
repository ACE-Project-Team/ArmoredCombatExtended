--- ACE Sustainability - Electrical power / voltage logic (pure, no GMod globals).
--
-- Separates the three quantities the grid otherwise conflates:
--   * energy  (kWh) - stored amount (batteries)
--   * power   (kW)  - a rate; limited by source C-rate and conductor ampacity
--   * voltage (V)   - a potential a transformer establishes; NEVER stored
--
-- It provides the transformer maths, the ampacity<->power relationship
-- (current = power / voltage, so the same conductor carries more power at a
-- higher voltage - the reason real grids step up for transmission), the
-- brownout/voltage-sag model that makes a too-small source physically unable to
-- hold voltage under load, and the over-voltage breakdown stress the fault
-- system turns into arcing. Kept free of Entity/Wire/CurTime for unit testing.
-- @module logic_power

local Power = {}

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end
Power.clamp = clamp

Power.TransformEff = 0.97   -- default per-transformer conversion efficiency

--- Current (abstract amps) carried for a given power at a given voltage.
-- I = P / V. This is why grids step up: the same power at a higher voltage means
-- less current, so a thinner conductor suffices.
-- @param powerKW number
-- @param voltage number
-- @return number current
function Power.Current(powerKW, voltage)
	voltage = math.max(voltage or 0, 1e-9)
	return (powerKW or 0) / voltage
end

--- Power (kW) a conductor of a given ampacity can carry at a given voltage.
-- P = I * V. Hardware (cross-section / scale) fixes the ampacity; voltage is the
-- level you run it at, so a fixed conductor carries proportionally more power as
-- the voltage rises.
-- @param ampacity number current rating (from hardware)
-- @param voltage number operating voltage
-- @return number power capacity (kW)
function Power.Capacity(ampacity, voltage)
	return math.max(ampacity or 0, 0) * math.max(voltage or 0, 0)
end

--- Transformer step.
-- V_out = V_in * ratio. Power is conserved minus conversion loss and capped by
-- the device's ampacity AT THE OUTPUT voltage (P_cap = ampacity * V_out).
-- @param params table {vIn, ratio, powerInKW, ampacity (optional), efficiency (optional)}
-- @return table {vOut, powerOutKW, lossKW, currentOut}
function Power.Transform(params)
	local vIn   = math.max(params.vIn or 0, 0)
	local ratio = math.max(params.ratio or 1, 1e-9)
	local pIn   = math.max(params.powerInKW or 0, 0)
	local eff   = params.efficiency or Power.TransformEff
	local vOut  = vIn * ratio

	local pCap   = params.ampacity and Power.Capacity(params.ampacity, vOut) or math.huge
	local passed = math.min(pIn, pCap)
	local pOut   = passed * eff

	return {
		vOut       = vOut,
		powerOutKW = pOut,
		lossKW     = passed - pOut,
		currentOut = Power.Current(pOut, vOut),
	}
end

--- Voltage / power actually delivered to a load, given what the supply sustains.
-- The headline anti-cheese: voltage is held only while the supply can meet the
-- demanded power. When demand exceeds available power the voltage sags
-- proportionally (a real source "browns out"), so a tiny battery dressed up
-- behind a step-up transformer reads its rated voltage at no load but collapses
-- the instant a real load pulls on it.
-- @param ratedVoltage number the node's nominal voltage
-- @param availableKW number power the supply can actually deliver this instant
-- @param demandKW number power the load is asking for
-- @return table {voltage, powerKW, sag} (sag 0..1, 1 = full voltage held)
function Power.Delivered(ratedVoltage, availableKW, demandKW)
	ratedVoltage = math.max(ratedVoltage or 0, 0)
	availableKW  = math.max(availableKW or 0, 0)
	demandKW     = math.max(demandKW or 0, 0)

	if demandKW <= 0 then
		return { voltage = ratedVoltage, powerKW = 0, sag = 1 }
	end

	local sag = clamp(availableKW / demandKW, 0, 1)
	return {
		voltage = ratedVoltage * sag,
		powerKW = math.min(availableKW, demandKW),
		sag     = sag,
	}
end

--- Whether a load is satisfied: it must receive (nearly) its demanded power AND
-- see at least its minimum voltage.
-- @param delivered table result of Power.Delivered
-- @param demandKW number
-- @param minVoltage number
-- @return boolean
function Power.LoadOK(delivered, demandKW, minVoltage)
	return delivered.powerKW >= (demandKW or 0) * 0.99
		and delivered.voltage >= (minVoltage or 0)
end

Power.RefTemp      = 20      -- deg C reference temperature for resistivity
Power.TempCoeff    = 0.004   -- resistance rise per deg C above reference (copper ~0.0039)
Power.ResLossK     = 0.15    -- global tuning multiplier for resistive line loss
Power.MaxResLoss   = 0.9     -- a single conductor segment never loses more than this

--- Resistance of a conductor segment (abstract ohms), the IRL R = rho * L / A
-- with a temperature term. Length and cross-section are in source units
-- (inches, inches^2); resistivity is a per-material tuning constant. A longer or
-- thinner conductor, or a hotter one, has more resistance.
-- @param length number conductor length (its longest dimension)
-- @param area number cross-section (product of the two shorter dimensions)
-- @param resistivity number material constant (bigger = worse conductor)
-- @param temp number current temperature (deg C)
-- @return number abstract resistance
function Power.Resistance(length, area, resistivity, temp)
	resistivity = resistivity or 1
	local R = resistivity * math.max(length or 0, 0) / math.max(area or 1, 1e-6)
	return R * (1 + Power.TempCoeff * ((temp or Power.RefTemp) - Power.RefTemp))
end

--- Fractional power lost across a conductor of resistance R carrying at `voltage`.
-- Real grids step up because loss is I^2*R: at a higher voltage the same power
-- needs less current, so loss falls with voltage^2. This is why a low-voltage
-- (station-level) run bleeds power and you transmit at a transformer's high
-- voltage instead.
-- @param R number resistance from Power.Resistance
-- @param voltage number line voltage the conductor carries
-- @param powerKW number power actually being carried (more power = more loss)
-- @return number 0..MaxResLoss
function Power.ResistiveLoss(R, voltage, powerKW)
	voltage = math.max(voltage or 1, 1)
	powerKW = math.max(powerKW or 0, 0)
	-- The real line-loss FRACTION is I^2*R / P = P*R / V^2 (since I = P/V): it
	-- grows with the power carried and falls with voltage^2. So a lightly loaded
	-- line barely loses anything, while a near-capacity one bleeds (and heats).
	return clamp(Power.ResLossK * (R or 0) * powerKW / (voltage * voltage), 0, Power.MaxResLoss)
end

--- Over-voltage breakdown stress. Running a conductor/transformer above its
-- voltage rating stresses its insulation; the fault system turns this into arc
-- damage and condition loss. 0 at/under rating, growing past it.
-- @param voltage number applied voltage
-- @param ratedVoltage number hardware voltage rating
-- @return number 0 (safe) .. grows as it exceeds rating
function Power.Breakdown(voltage, ratedVoltage)
	ratedVoltage = math.max(ratedVoltage or 0, 1e-9)
	local over = (voltage or 0) / ratedVoltage - 1
	return over > 0 and over or 0
end

return Power
