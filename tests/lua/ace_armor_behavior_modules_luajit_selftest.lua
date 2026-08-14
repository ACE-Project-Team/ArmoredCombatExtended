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
		degradation = 0.5,
		multiHitRetention = 0.5,
		shockTransmission = 0.5
	},
	resolver = "modular"
})

assert(ACE.ArmorTypes.TestComposite == modular, "material was not registered")
assert(modular.massMod == 2400 / 7850, "density did not derive mass modifier")
assert(modular.effectiveness == 1.6, "kinetic RHAe did not derive effectiveness")
assert(modular.HEATeffectiveness == 1.1, "chemical RHAe did not derive HEAT effectiveness")
assert(modular.HEeffectiveness == 0.8, "HE RHAe did not derive HE effectiveness")
assert(modular.spallresist == 1 and modular.spallmult == 1, "legacy spall defaults missing")
assert(modular.BehaviorConfig.composite_backing.residualDamageMultiplier == 0.75, "behavior parameters missing")
assert(type(modular.ArmorResolution) == "function", "modular resolver missing")

local customImpactHook = ACE.DefineArmorMaterial({
	id = "CustomImpactHook",
	resolver = "modular",
	behaviors = { "homogeneous_metal" },
	resolverConfig = { impactHook = "du_secondary_blast", triggerOnPenetration = true },
	spec = { densityKgM3 = 2400, kineticRHAe = 1.2 }
})
assert(customImpactHook.ArmorResolverConfig.impactHook == "du_secondary_blast", "custom impact-hook compatibility was removed")

local valid, errors = ACE.ValidateArmorSpec({ densityKgM3 = -1 })
assert(not valid and #errors == 1, "invalid armor specs were accepted")

local incomplete = pcall(ACE.DefineArmorMaterial, { id = "Incomplete", resolver = "modular", spec = { kineticRHAe = 1 } })
assert(not incomplete, "incomplete modular material was registered")
local malformed = pcall(ACE.DefineArmorMaterial, { id = "Malformed", resolver = "modular", spec = { densityKgM3 = 2400, kineticRHAe = 1, hardnessHB = "unknown" } })
assert(not malformed, "malformed modular material was registered")
local badOvermatch = pcall(ACE.DefineArmorMaterial, { id = "BadOvermatch", resolver = "modular", spec = { densityKgM3 = 2400, kineticRHAe = 1, overmatchRatio = "unknown" } })
assert(not badOvermatch, "nonnumeric overmatch was registered")
local badBehaviorParameter = pcall(ACE.DefineArmorMaterial, {
	id = "BadBehaviorParameter",
	resolver = "modular",
	behaviors = { { id = "homogeneous_metal", parameters = { shockTransmission = 0.5 } } },
	spec = { densityKgM3 = 2400, kineticRHAe = 1 }
})
assert(not badBehaviorParameter, "unsupported module parameter was registered")
local badBehaviorShape = pcall(ACE.DefineArmorMaterial, {
	id = "BadBehaviorShape",
	resolver = "modular",
	behaviors = { { id = "homogeneous_metal", parameters = false } },
	spec = { densityKgM3 = 2400, kineticRHAe = 1 }
})
assert(not badBehaviorShape, "malformed behavior parameters were registered")
local sparseBehaviors = pcall(ACE.DefineArmorMaterial, {
	id = "SparseBehaviors",
	resolver = "modular",
	behaviors = { [2] = "homogeneous_metal" },
	spec = { densityKgM3 = 2400, kineticRHAe = 1 }
})
assert(not sparseBehaviors, "sparse behavior list was registered")
local orphanBehaviorParameter = pcall(ACE.DefineArmorMaterial, {
	id = "OrphanBehaviorParameter",
	resolver = "modular",
	behaviors = { "homogeneous_metal" },
	behaviorConfig = { shock_barrier = { shockTransmission = 0.5 } },
	spec = { densityKgM3 = 2400, kineticRHAe = 1 }
})
assert(not orphanBehaviorParameter, "inactive module parameter was registered")

local oldRandom = math.random
math.random = function() return 0 end
local customHookCalls = 0
ACE.HE = function() customHookCalls = customHookCalls + 1 end
local customHookEntity = { GetPos = function() return {} end, ACF = { Health = 100, MaxHealth = 100 } }
customImpactHook.ArmorResolution(customHookEntity, 10, 10, 10, 100, 1, 1, 100, "AP")
assert(customHookCalls > 0, "custom impact-hook dispatch was removed")
local target = { ACF = { Health = 100, MaxHealth = 100 } }
local intact = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "AP")
local intactLocal = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "AP", 1)
local damagedLocal = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "AP", 0)
local heat = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "HE")
local breach = modular.ArmorResolution(target, 10, 10, 10, 20, 1, 100, 1, "AP")

assert(type(intact.Outcome) == "string", "modular resolver missing normalized outcome")
assert(intact.PenetrationSpent >= 0, "modular resolver missing penetration spent")
assert(intact.PenetrationRemaining >= 0, "modular resolver missing penetration remaining")
assert(damagedLocal.Overkill > intactLocal.Overkill, "localized impact condition was not forwarded to the modular resolver")
assert(math.abs(intact.PenetrationSpent + intact.PenetrationRemaining - 100) < 0.0000001, "normalized penetration budget changed")
target.ACF.Health = 0
local degraded = modular.ArmorResolution(target, 10, 10, 10, 100, 1, 1, 1, "AP")

local retentionOnly = ACE.DefineArmorMaterial({
	id = "RetentionOnly",
	resolver = "modular",
	behaviors = { "homogeneous_metal" },
	spec = { densityKgM3 = 2400, kineticRHAe = 1.6, multiHitRetention = 0.5, degradation = 0.75 }
})
local degradationOnly = ACE.DefineArmorMaterial({
	id = "DegradationOnly",
	resolver = "modular",
	behaviors = { "homogeneous_metal" },
	spec = { densityKgM3 = 2400, kineticRHAe = 1.6, degradation = 0.25 }
})
local damagedTarget = { ACF = { Health = 0, MaxHealth = 100 } }
local retentionResult = retentionOnly.ArmorResolution(damagedTarget, 10, 10, 10, 100, 1, 1, 1, "AP")
local degradationResult = degradationOnly.ArmorResolution(damagedTarget, 10, 10, 10, 100, 1, 1, 1, "AP")
math.random = oldRandom
assert(degraded.Overkill > intact.Overkill, "multi-hit retention did not reduce degraded protection")
assert(heat.Damage < intact.Damage, "shock transmission did not reduce HE damage")
assert(breach.Overkill == 4, "breach math ignored kinetic RHAe")
assert(retentionResult.Overkill == 92, "retention floor changed unexpectedly: " .. tostring(retentionResult.Overkill))
assert(degradationResult.Overkill == 88, "degradation slope changed unexpectedly: " .. tostring(degradationResult.Overkill))

print("ACE armor behavior modules LuaJIT self-test: PASS")
