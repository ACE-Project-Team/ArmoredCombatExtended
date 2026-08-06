local root = assert(arg[1], "usage: ace_armor_behavior_modules_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
AddCSLuaFile = function() end
SERVER = true
math.Clamp = math.Clamp or function(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end
ACE.ArmorTypes = {}

assert(dofile(root .. "/lua/acf/shared/sh_ace_armor_behaviors.lua") == nil)

local materials = {}
for materialId in pairs(ACE.ArmorBehaviorSets) do materials[materialId] = {} end
ACE.ApplyArmorBehaviorModules(materials)

local expected = {
	RHA = { "homogeneous_metal", "spall_response" },
	CHA = { "homogeneous_metal", "spall_response" },
	Cer = { "brittle_strike_face", "composite_backing", "spall_response", "failure_state" },
	DU = { "dense_metal", "homogeneous_metal", "spall_response" },
	Ti = { "lightweight_metal", "homogeneous_metal", "spall_response" },
	Alum = { "lightweight_metal", "homogeneous_metal", "spall_response" },
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
	assert(ACE.GetArmorBehaviorModules(materials[materialId]) == materials[materialId].BehaviorModules, materialId .. " lookup changed")
end

assert(#ACE.GetArmorBehaviorModules(nil) == 0, "missing material lookup changed")

local modular = ACE.DefineArmorMaterial({
	id = "TestComposite",
	name = "Test composite",
	behaviors = {
		"brittle_strike_face",
		{ id = "composite_backing", parameters = { residualDamageMultiplier = 0.75 } }
	},
	spec = {
		densityKgM3 = 2400,
		kineticRHAe = 1.6,
		chemicalRHAe = 1.1,
		heRHAe = 0.8,
		curve = 1,
		ductility = 0.2,
		multiHitRetention = 0.5,
		degradation = 0.5
	},
	resolver = "modular"
})

assert(ACE.ArmorTypes.TestComposite == modular, "material was not registered")
assert(modular.massMod == 2400 / 7850, "density did not derive mass modifier")
assert(modular.effectiveness == 1.6, "kinetic RHAe did not derive effectiveness")
assert(modular.HEATeffectiveness == 1.1, "chemical RHAe did not derive HEAT effectiveness")
assert(modular.HEeffectiveness == 0.8, "HE RHAe did not derive HE effectiveness")
assert(modular.BehaviorConfig.composite_backing.residualDamageMultiplier == 0.75, "behavior parameters missing")
assert(type(modular.ArmorResolution) == "function", "modular resolver missing")

local valid, errors = ACE.ValidateArmorSpec({ densityKgM3 = -1 })
assert(not valid and #errors == 1, "invalid armor specs were accepted")

local incomplete = pcall(ACE.DefineArmorMaterial, { id = "Incomplete", resolver = "modular", spec = { kineticRHAe = 1 } })
assert(not incomplete, "incomplete modular material was registered")

local oldRandom = math.random
math.random = function() return 0 end
local target = { ACF = { Health = 100, MaxHealth = 100 } }
local intact = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "AP")
target.ACF.Health = 0
local degraded = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "AP")
math.random = oldRandom
assert(degraded.Overkill >= intact.Overkill, "multi-hit retention did not reduce degraded protection")

print("ACE armor behavior modules LuaJIT self-test: PASS")
