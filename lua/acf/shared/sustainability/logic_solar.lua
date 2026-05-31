--- ACE Sustainability - Solar panel logic (pure, no GMod globals).
--
-- Output scales with available sunlight (shadow/weather), the cosine of the
-- incidence angle (sun vs panel normal) and a temperature derate: real PV
-- cells lose ~0.4%/deg C above a 25 deg C reference, so a baking panel
-- produces less - which ties the heat system to gameplay. Trace and
-- sun-direction work stay in the entity; this is just the maths.
-- @module logic_solar

local Solar = {}

Solar.TempCoeff = 0.004   -- fractional power loss per °C above reference
Solar.RefTemp   = 25      -- °C reference cell temperature
Solar.MinDerate = 0.30    -- never derate below this
Solar.SoakJperKW = 8000   -- heat soak: J added per kW of incident sun per second
                          -- (tuned so a sunlit panel settles around 40-50 C,
                          --  making the temperature derate actually matter)

--- Electrical output, derate and heat soak for one tick.
-- @param params table fields:
--   maxPower (kW at full sun / normal incidence / reference temp),
--   sun (0..1 available sunlight, 0 when shadowed),
--   angle (0..1 cosine of incidence),
--   mapLight (0..1 overall map brightness; a dark/night map yields less. Default 1),
--   panelTemp (current panel temperature, deg C),
--   dt (timestep, s)
-- @return table { power (kW), derate (0..1), energyKWh, heatAddJ (J) }
function Solar.Output(params)
	local maxPower = params.maxPower or 0
	local sun      = params.sun or 0
	local angle    = params.angle or 0
	local temp     = params.panelTemp or Solar.RefTemp
	local dt       = params.dt or 0
	local mapLight = params.mapLight
	if mapLight == nil then mapLight = 1 end

	if sun      < 0 then sun = 0           elseif sun      > 1 then sun = 1      end
	if angle    < 0 then angle = 0         elseif angle    > 1 then angle = 1    end
	if mapLight < 0 then mapLight = 0      elseif mapLight > 1 then mapLight = 1 end

	local derate = 1 - Solar.TempCoeff * (temp - Solar.RefTemp)
	if derate < Solar.MinDerate then derate = Solar.MinDerate
	elseif derate > 1 then derate = 1 end

	-- A darker map (night, overcast, dim theme) scales the incident light down.
	local incident = (maxPower > 0) and (maxPower * sun * angle * mapLight) or 0
	local power    = incident * derate
	local energyKWh = power * dt / 3600

	-- The panel soaks up incident sunlight as heat (independent of derate).
	local heatAddJ = incident * Solar.SoakJperKW * dt

	return {
		power     = power,
		derate    = derate,
		energyKWh = energyKWh,
		heatAddJ  = heatAddJ,
	}
end

return Solar
