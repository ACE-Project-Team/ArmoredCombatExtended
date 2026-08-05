local root = assert(arg[1], "usage: ace_armor_behavior_modules_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
AddCSLuaFile = function() end
table.Copy = function(value)
	local copy = {}
	for key, item in pairs(value) do copy[key] = item end
	return copy
end

assert(dofile(root .. "/lua/acf/shared/sh_ace_armor_behaviors.lua") == nil)

local materials = {}
for materialId in pairs(ACE.ArmorBehaviorSets) do materials[materialId] = {} end
ACE.ApplyArmorBehaviorModules(materials)

local expected = {
	RHA = { "homogeneous_metal", "spall_response" },
	Cer = { "brittle_strike_face", "composite_backing", "spall_response", "failure_state" },
	ERA = { "reactive_tile", "shock_barrier", "spall_response", "failure_state" },
	Rub = { "elastomer_liner", "spall_response", "shock_barrier" },
	Texto = { "composite_backing", "spall_response", "failure_state" }
}

for materialId, behaviorIds in pairs(expected) do
	assert(#materials[materialId].BehaviorModules == #behaviorIds, materialId .. " module count changed")
	for index, behaviorId in ipairs(behaviorIds) do
		assert(materials[materialId].BehaviorModules[index] == behaviorId, materialId .. " module order changed")
	end
	assert(#materials[materialId].BehaviorLabels == #behaviorIds, materialId .. " labels missing")
end

print("ACE armor behavior modules LuaJIT self-test: PASS")
