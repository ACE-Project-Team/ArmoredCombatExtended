ACE = { ArmorTypes = {} }
SERVER = true
CLIENT = false

function AddCSLuaFile() end
math.Min = math.min
vector_up = {}
NULL = {}
timer = { Simple = function() end, Create = function() end, Exists = function() return false end }
util = { Effect = function() end }
EffectData = function() return { SetOrigin = function() end, SetNormal = function() end, SetRadius = function() end } end

function math.Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

ACE.HE = function() end
ACE.CalculateHERadius = function() return 1 end

dofile("lua/acf/shared/sh_ace_armor_behaviors.lua")
dofile("lua/acf/shared/armor/modular_legacy_profiles.lua")

local entity = {
	ACF = { Ductility = 0.25, Health = 100, MaxHealth = 100 },
	Remove = function() end,
	EmitSound = function() end
}

local cases = {
	RHA = { "AP", "Spall" },
	CHA = { "AP" },
	Cer = { "AP", "HE" },
	DU = { "AP" },
	Ti = { "AP" },
	Alum = { "AP", "HEAT" },
	ERA = { "HE", "AP" },
	Rub = { "AP", "HEAT", "HE", "Spall" },
	Texto = { "AP", "HEAT", "HE", "Spall" }
}

-- Frozen outputs from the legacy material resolvers at c7053562. These cases cover
-- each threat branch and the special ceramic/rubber/ERA paths after the source
-- implementations have been removed from the runtime tree.
local expected = {
	RHA = { AP = { [0] = { 5.92405063291139, 5, 0.75 } } },
	CHA = { AP = { [0] = { 2.36962025316456, 5.3, 0.735 } } },
	Cer = { AP = { [0] = { 63.5996950510823, 0, 1 } }, HE = { [0] = { 953.995425766234, 0, 1 } } },
	DU = { AP = { [0] = { 1.57974683544304, 0, 1 } } },
	Ti = { AP = { [0] = { 2.32315711094564, 0, 1 } } },
	Alum = { HEAT = { [0] = { 21.1254928576916, 9.94485817662462, 0.502757091168769 } } },
	ERA = { HE = { [0] = { 1.3, 0, 1 } }, AP = { [0] = { 1.3, 0, 1 } } },
	Rub = {
		AP = { [0] = { 1.84303797468354, 11.4886196179762, 0.425569019101188 }, [1] = { 2.83833743731381, 19.3795098734362, 0.0310245063281877 } },
		HEAT = { [0] = { 1.51968640871268, 0, 1 } },
		HE = { [1] = { 24.3286066055469, 19.3795098734362, 0.0310245063281877 } },
		Spall = { [1] = { 2.83833743731381, 18.1385296203087, 0.093073518984563 } }
	},
	Texto = {
		AP = { [0] = { 4.05063291139241, 11.2903641004392, 0.43548179497804 }, [1] = { 6.58528316250751, 13.6247710222612, 0.318761448886942 } },
		HEAT = { [0] = { 1.64632079062688, 4.69945045342678, 0.765027477328661 } },
		HE = { [1] = { 2.46948118594031, 8.52458784007009, 0.573770607996496 } }
	}
}

local function assertFinite(label, value)
	assert(type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge, label .. " is not finite")
end

for id, types in pairs(cases) do
	local material = ACE.ArmorTypes[id]
	for _, impactType in ipairs(types) do
		for _, randomValue in ipairs({ 0, 1 }) do
			math.random = function() return randomValue end
			local maxPenetration = id == "ERA" and 1 or 20
			local args = { entity, 10, 15, 10, maxPenetration, 2.5, 5, 1.3, impactType }
			local result = material.ArmorResolution(unpack(args))
			assertFinite(id .. "/" .. impactType .. "/" .. randomValue .. " Damage", result.Damage)
			assertFinite(id .. "/" .. impactType .. "/" .. randomValue .. " Overkill", result.Overkill)
			assertFinite(id .. "/" .. impactType .. "/" .. randomValue .. " Loss", result.Loss)
			local snapshot = expected[id] and expected[id][impactType] and expected[id][impactType][randomValue]
			if snapshot then
				assert(math.abs(result.Damage - snapshot[1]) < 0.0000001, id .. "/" .. impactType .. " damage parity failed")
				assert(math.abs(result.Overkill - snapshot[2]) < 0.0000001, id .. "/" .. impactType .. " overkill parity failed")
				assert(math.abs(result.Loss - snapshot[3]) < 0.0000001, id .. "/" .. impactType .. " loss parity failed")
			end
		end
	end
end

local heCalls = 0
ACE.HE = function() heCalls = heCalls + 1 end
local removed = 0
local impactEntity = {
	ACF = { Ductility = 0.25, Health = 100, MaxHealth = 100 },
	Remove = function() removed = removed + 1 end,
	GetPos = function() return {} end,
	EmitSound = function() end
}
math.random = function() return 0 end
ACE.ArmorTypes.DU.ArmorResolution(impactEntity, 10, 15, 10, 100, 2.5, 5, 1.3, "AP")
assert(heCalls == 1, "DU secondary blast hook was not preserved")
ACE.ArmorTypes.ERA.ArmorResolution(impactEntity, 10, 15, 10, 20, 2.5, 5, 1.3, "AP")
assert(removed == 1, "ERA detonation removal hook was not preserved")
assert(heCalls == 2, "ERA detonation blast hook was not preserved")

print("ACE legacy armor resolver parity self-test: PASS")
