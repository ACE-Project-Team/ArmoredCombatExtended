local root = assert(arg[1], "usage: ace_loader_reload_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

AddCSLuaFile = function() end
ACE = {}
dofile(root .. "/lua/acf/shared/sh_crewseat_base.lua")

local multiplier = ACE.GetLoaderReloadMultiplier
assert(multiplier(0) == 1, "upright loader must have no reload penalty")
assert(multiplier(15) == 1, "the linear ramp must start at 15 degrees")
assert(math.abs(multiplier(90) - 3) < 1e-12, "horizontal loader must have a 3x reload penalty")
assert(multiplier(90.01) == 10, "angles beyond horizontal must have a 10x reload penalty")
assert(multiplier(180) == 10, "inverted loader must have a 10x reload penalty")

local previous = multiplier(15)
for angle = 16, 90 do
	local current = multiplier(angle)
	assert(current >= previous, "loader reload penalty must be monotonic")
	previous = current
end

print("ACE loader reload LuaJIT self-test: PASS")
