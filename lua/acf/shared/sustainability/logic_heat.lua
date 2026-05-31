--- ACE Sustainability - Heat logic (pure, no GMod globals).
--
-- One shared thermal model for every sustainability entity. Entities set
-- self.Heat (deg C), which ACE's IR/contraption layer already reads through
-- CLASS:GetACEHottestEntity (lua/cfw/extensions/ace_sv.lua), so this module's
-- only job is producing a believable, stable temperature each tick.
--
-- Model: lumped thermal mass + Newtonian cooling toward ambient.
--   rise = addedJoules / (mass * specificHeat)
--   cool = (T - ambient) * coolK * dissipScale * dt
-- Guarantees: never below ambient, no runaway for bounded heat input.
-- @module logic_heat

local Heat = {}

Heat.SpecificHeat = 500   -- J/(kg·K), steel-ish lumped value
Heat.CoolK        = 0.05  -- base cooling rate (per second per °C above ambient)

--- Advance an entity's temperature one tick.
-- @param cur number current temperature (deg C)
-- @param addedJoules number heat energy injected this step (J), >= 0
-- @param massKg number thermal mass of the entity (kg)
-- @param dissipScale number cooling multiplier (bigger surface > 1; insulated < 1)
-- @param ambient number ambient temperature (deg C)
-- @param dt number timestep (s)
-- @return number new temperature (deg C), clamped to >= ambient
function Heat.HeatStep(cur, addedJoules, massKg, dissipScale, ambient, dt)
	ambient = ambient or 20
	dt = dt or 0
	cur = cur or ambient

	local thermalMass = (massKg or 1) * Heat.SpecificHeat
	if thermalMass < 1 then thermalMass = 1 end

	local rise = (addedJoules or 0) / thermalMass
	local cool = (cur - ambient) * Heat.CoolK * (dissipScale or 1) * dt

	local nh = cur + rise - cool
	if nh < ambient then nh = ambient end
	return nh
end

--- Equilibrium temperature for a constant power input.
-- Where a steady load eventually settles - handy for tests/balance.
-- @param powerWatts number constant heat input (W)
-- @param dissipScale number cooling multiplier
-- @param massKg number thermal mass (kg)
-- @param ambient number ambient temperature (deg C)
-- @return number steady-state temperature (deg C)
function Heat.Equilibrium(powerWatts, dissipScale, massKg, ambient)
	ambient = ambient or 20
	-- At equilibrium rise == cool over a unit of time:
	-- power/thermalMass = (T-ambient)*coolK*dissip  (per second)
	local thermalMass = (massKg or 1) * Heat.SpecificHeat
	local denom = Heat.CoolK * (dissipScale or 1) * thermalMass
	if denom <= 0 then return ambient end
	return ambient + (powerWatts or 0) / denom
end

return Heat
