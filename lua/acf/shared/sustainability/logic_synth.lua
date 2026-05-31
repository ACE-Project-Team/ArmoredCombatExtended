--- ACE Sustainability - Fuel generation logic (pure, no GMod globals).
--
-- Two ways to make liquid fuel:
--   Synth - electric synthesizer: burns battery electricity into fuel at some
--           efficiency. Fast, but only as good as your power supply. Closes
--           the loop solar/alternator -> battery -> fuel -> engine.
--   Field - self-powered "thumper": makes fuel slowly on its own and runs hot.
--           Free but inefficient - the no-infrastructure fallback.
-- energyPerLiter is in kWh/L (chemical energy density of the fuel).
-- @module logic_synth

local Synth = {}

local KWH_TO_J = 3.6e6

--- Electric synthesizer step.
-- @param params table fields:
--   elecAvailableKWh (energy available from the battery this step),
--   maxRateKW (max electrical draw),
--   efficiency (0..1 elec -> chemical),
--   energyPerLiter (kWh per litre produced),
--   dt (timestep, s)
-- @return table { fuelMade (litres), elecUsed (kWh), heatAddJ (J) }
function Synth.Tick(params)
	local avail = params.elecAvailableKWh or 0
	local maxRate = params.maxRateKW or 0
	local eff = params.efficiency or 0.5
	local epl = params.energyPerLiter or 1
	local dt = params.dt or 0

	if dt <= 0 or maxRate <= 0 or avail <= 0 or epl <= 0 then
		return { fuelMade = 0, elecUsed = 0, heatAddJ = 0 }
	end

	local maxStep = maxRate * dt / 3600
	local elecUsed = math.min(avail, maxStep)
	local fuelEnergy = elecUsed * eff
	local fuelMade = fuelEnergy / epl
	local heatAddJ = elecUsed * (1 - eff) * KWH_TO_J

	return { fuelMade = fuelMade, elecUsed = elecUsed, heatAddJ = heatAddJ }
end

--- Self-powered field generator step.
-- @param params table fields:
--   literPerSec (base extraction rate),
--   heatWatts (constant heat output while running),
--   dt (timestep, s)
-- @return table { fuelMade (litres), heatAddJ (J) }
function Synth.Field(params)
	local lps = params.literPerSec or 0
	local hw  = params.heatWatts or 0
	local dt  = params.dt or 0
	if dt <= 0 then return { fuelMade = 0, heatAddJ = 0 } end
	return { fuelMade = lps * dt, heatAddJ = hw * dt }
end

Synth.KWH_TO_J = KWH_TO_J

return Synth
