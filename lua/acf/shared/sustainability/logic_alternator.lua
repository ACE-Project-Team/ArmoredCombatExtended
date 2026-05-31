--- ACE Sustainability - Alternator logic (pure, no GMod globals).
--
-- The alternator is a generator head: it reads the RPM of a spinning shaft it
-- is linked to, drags on it, and turns the absorbed motion into electricity.
-- Load (0-1) sets how hard it drags.
--
-- The braking torque itself is **velocity-proportional** (the same idea the
-- gearbox brake uses): it scales with the shaft's current speed and inertia,
-- so it decays smoothly to zero as the shaft slows and can never reverse or
-- spin it up. That stable braking is applied by the entity; this module just
-- produces the electrical figures.
-- @module logic_alternator

local Alt = {}

local function clamp(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end

--- Velocity-proportional braking torque to apply to the shaft.
-- Returns a value with the same sign as `vel`; the entity applies the negative
-- of it so the drag always opposes the current rotation.
-- @param vel number shaft angular velocity along its axis (deg/s, signed)
-- @param inertia number shaft inertia about that axis
-- @param load number 0..1 brake fraction
-- @param coeff number tuning coefficient
-- @return number braking magnitude (signed like vel)
function Alt.BrakeTorque(vel, inertia, load, coeff)
	return (vel or 0) * (inertia or 0) * clamp(load or 0, 0, 1) * (coeff or 1)
end

--- Electrical output and heat for one tick.
-- Output rises with load and with RPM up to the rated RPM, then holds at the
-- alternator's rated power. Conversion losses become heat.
-- @param params table {rpm, load, maxPower (kW), ratedRPM, efficiency, dt}
-- @return table {outputPower (kW), energyKWh, heatAddJ (J)}
function Alt.Tick(params)
	local rpm      = params.rpm or 0
	local load     = clamp(params.load or 0, 0, 1)
	local maxPower  = params.maxPower or 0
	local ratedRPM  = params.ratedRPM or 3000
	local eff       = params.efficiency or 0.85
	local dt        = params.dt or 0

	if rpm <= 0.1 or load <= 0 or maxPower <= 0 then
		return { outputPower = 0, energyKWh = 0, heatAddJ = 0 }
	end

	local frac = clamp(rpm / ratedRPM, 0, 1)        -- ramps in with speed
	local outputPower = maxPower * load * frac      -- kW
	local energyKWh   = outputPower * dt / 3600
	local heatAddJ    = (eff > 0) and (outputPower * 1000 * (1 / eff - 1) * dt) or 0

	return {
		outputPower = outputPower,
		energyKWh   = energyKWh,
		heatAddJ    = heatAddJ,
	}
end

return Alt
