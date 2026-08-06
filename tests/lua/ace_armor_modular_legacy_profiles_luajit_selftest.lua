ACE = { ArmorTypes = {} }
SERVER = true
CLIENT = false

function AddCSLuaFile() end

function math.Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

dofile("lua/acf/shared/sh_ace_armor_behaviors.lua")
dofile("lua/acf/shared/armor/modular_legacy_profiles.lua")

local expected = {
	RHA = { massMod = 1, effectiveness = 1 },
	CHA = { massMod = 1.2, effectiveness = 0.98 },
	Cer = { massMod = 1.2, effectiveness = 2.05 },
	DU = { massMod = 2.43, effectiveness = 3 },
	Ti = { massMod = 0.61, effectiveness = 1.7 },
	Alum = { massMod = 0.333, effectiveness = 0.8325 },
	ERA = { massMod = 2, effectiveness = 2.5 },
	Rub = { massMod = 0.2, effectiveness = 0.05 },
	Texto = { massMod = 0.35, effectiveness = 0.5 }
}

for id, values in pairs(expected) do
	local material = ACE.ArmorTypes[id]
	assert(material, "missing modular material: " .. id)
	assert(material.ArmorResolver == "modular", id .. " did not use the modular resolver")
	assert(type(material.ArmorResolution) == "function", id .. " lost its resolver")
	assert(material.massMod == values.massMod, id .. " mass compatibility changed")
	assert(material.effectiveness == values.effectiveness, id .. " kinetic effectiveness changed")
	assert(type(material.BehaviorModules) == "table" and #material.BehaviorModules > 0, id .. " has no behavior modules")
	assert(type(material.ArmorSpec) == "table" and material.ArmorSpec.densityKgM3 == values.massMod * 7850, id .. " density was not derived from legacy mass")
	assert(type(material.ACEArmorRuntime) == "table", id .. " runtime profile was not compiled")
	assert(material.ACEArmorRuntime.spec == material.ArmorSpec, id .. " runtime spec cache is stale")
	assert(material.ACEArmorRuntime.resolverConfig == material.ArmorResolverConfig, id .. " resolver config cache is stale")
end

assert(ACE.ArmorTypes.Cast == nil, "Cast must retain the CHA compatibility ID")
assert(ACE.ArmorTypes.CHA.sname == "Cast", "Cast display identity changed")
assert(ACE.ArmorTypes.ERA.Stopshock == true, "ERA shock compatibility changed")
assert(ACE.ArmorTypes.Rub.Stopshock == true, "Rubber shock compatibility changed")
assert(ACE.ArmorTypes.Rub.ArmorSpec.spallCapture == 0.65, "Rubber spall capture behavior missing")
assert(ACE.ArmorTypes.Texto.ArmorSpec.spallCapture == 0.35, "Textolite spall capture behavior missing")
assert(ACE.ArmorTypes.Rub.ArmorSpec.spallCaptureArealDensity == 18, "Rubber capture areal density missing")
assert(ACE.ArmorTypes.Texto.ArmorSpec.spallCaptureVelocity == 1800, "Textolite capture velocity missing")
assert(ACE.ArmorTypes.ERA.ACEArmorRuntime.hasShockBarrier, "ERA shock behavior was not compiled")
assert(ACE.ArmorTypes.ERA.ACEArmorRuntime.singleUse, "ERA single-use behavior was not compiled")
assert(ACE.ArmorTypes.ERA.ACEArmorRuntime.impactHook == "era_detonation", "ERA impact hook was not compiled")
assert(ACE.ArmorTypes.Cer.ACEArmorRuntime.hasBrittleStrikeFace, "ceramic brittle behavior was not compiled")
assert(ACE.ArmorTypes.Texto.ACEArmorRuntime.hasCompositeBacking, "textolite backing behavior was not compiled")

print("ACE modular legacy armor profile self-test: PASS")
