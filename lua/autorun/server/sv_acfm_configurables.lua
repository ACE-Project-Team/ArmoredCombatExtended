


local Cast =
{
	number = function(str) return tonumber(str) end,
	string = function(str) return str end,
	boolean = function(str) return tobool(str) end
}




function ACFM_CreateConfigurable(str, configurables, bdata, wlistPath)

	local success, ret = xpcall( -- we're eating arbitrary user input, so let's not fuck up if they fuck up
						function()
							return ACFM_CreateConfigurable_Raw(str, configurables, bdata, wlistPath)
						end,

						ErrorNoHalt
					)

	return success and ret

end




function ACFM_CreateConfigurable_Raw(str, configurables, bdata, wlistPath)

	-- we're parsing a string of the form "NAME:CMD=VAL:CMD=VAL"... potentially.

	local parts = {}
	-- split parts delimited by ':'
	for part in string.gmatch(str, "[^:]+") do parts[#parts + 1] = part end

	if #parts <= 0 then return end


	local name = table.remove(parts, 1)
	if name and name ~= "" then

		-- base table for configurable object
		local class = configurables[name]
		if not class then return end


		if bdata then
			local allowed = ACF_GetGunValue(bdata, wlistPath)
			if istable(allowed) and not table.HasValue(allowed, name) then return nil end
		end


		local args = {}

		for _, arg in pairs(parts) do
			-- get CMD from 'CMD=VAL'
			local cmd = string.match(arg, "^[^=]+")
			if not cmd then continue end

			-- get VAL from 'CMD=VAL'
			local val = string.match(arg, "[^=]+$")
			if not val then continue end

			args[string.lower(cmd)] = val
		end


		-- construct new instance of configurable object
		local instance = class()
		if not instance.Configurable then return instance end


		-- loop through config, match up with args and set values accordingly
		for _, config in pairs(instance.Configurable) do

			local cmdName = config.CommandName

			if not cmdName then continue
			else cmdName = string.lower(cmdName) end

			local arg = args[cmdName]
			if not arg then continue end

			local type = config.Type

			if Cast[type] then
				instance[config.Name] = Cast[type](arg)
			end

		end

		return instance

	end

end
