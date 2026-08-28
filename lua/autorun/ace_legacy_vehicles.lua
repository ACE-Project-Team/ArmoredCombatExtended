-- Compatibility lookups for old vehicle keys. Keep aliases out of registry
-- enumeration so the canonical ACE entries remain the only menu entries.
local function InstallLegacyVehicleAliases()
	local vehicles = list.GetForEdit("Vehicles")
	local meta = getmetatable(vehicles) or {}
	if meta.ACE_LegacyVehicleAliases then return end

	local previousIndex = meta.__index
	meta.__index = function(self, key)
		if key == "acf_pod" then return rawget(self, "ACE_pod") end
		if key == "acf_pilotseat" then return rawget(self, "ACE_pilotseat") end
		if isfunction(previousIndex) then return previousIndex(self, key) end
		if istable(previousIndex) then return previousIndex[key] end
	end
	meta.ACE_LegacyVehicleAliases = true
	setmetatable(vehicles, meta)
end

hook.Add("Initialize", "ACE_LegacyVehicleAliases", InstallLegacyVehicleAliases)
