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

--- Product split by reactor temperature (realistic Fischer-Tropsch behaviour).
-- High-temperature FT (~340 C) favours light products (petrol ~2:1 over diesel);
-- low-temperature FT (~210 C) favours heavy products (diesel ~2:1 over petrol).
-- We interpolate linearly between those two endpoints and clamp outside the band.
-- @param tempC reactor temperature (deg C)
-- @return petrol fraction, diesel fraction (sum to 1)
function Synth.ProductSplit(tempC, tMin, tMax)
	tMin = tMin or 210
	tMax = tMax or 340
	local t = tMax > tMin and (tempC - tMin) / (tMax - tMin) or 0.5
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	-- petrol rises from 1/3 (cold) to 2/3 (hot); diesel is the remainder.
	local petrol = 0.3333 + t * (0.6667 - 0.3333)
	return petrol, 1 - petrol
end

--- Oil pump ("field") extraction step.
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
