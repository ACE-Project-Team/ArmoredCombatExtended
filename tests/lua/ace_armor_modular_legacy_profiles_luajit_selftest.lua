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
end

assert(ACE.ArmorTypes.Cast == nil, "Cast must retain the CHA compatibility ID")
assert(ACE.ArmorTypes.CHA.sname == "Cast", "Cast display identity changed")
assert(ACE.ArmorTypes.ERA.Stopshock == true, "ERA shock compatibility changed")
assert(ACE.ArmorTypes.Rub.Stopshock == true, "Rubber shock compatibility changed")

print("ACE modular legacy armor profile self-test: PASS")
