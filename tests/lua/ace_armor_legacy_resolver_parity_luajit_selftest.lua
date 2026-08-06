ACE = { ArmorTypes = {} }
SERVER = true
CLIENT = false

function AddCSLuaFile() end
math.Min = math.min
vector_up = {}
NULL = {}
CHAN_WEAPON = 1
Sound = function(path) return path end
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
			assert(type(result.Outcome) == "string", id .. "/" .. impactType .. " missing normalized outcome")
			assert(result.PenetrationSpent >= 0 and result.PenetrationRemaining >= 0, id .. "/" .. impactType .. " invalid penetration budget")
		end
	end
end

local heCalls = 0
ACE.HE = function() heCalls = heCalls + 1 end
local removed = 0
local soundCalls = 0
local impactEntity = {
	ACF = { Ductility = 0.25, Health = 100, MaxHealth = 100 },
	Remove = function() removed = removed + 1 end,
	GetPos = function() return {} end,
	EmitSound = function() soundCalls = soundCalls + 1 end
}
math.random = function() return 0 end
local castBreach = ACE.ArmorTypes.CHA.ArmorResolution(impactEntity, 10, 10, 10, 20, 2.5, 100, 1.3, "AP")
assertFinite("Cast modular damage", castBreach.Damage)
local ceramicAP = ACE.ArmorTypes.Cer.ArmorResolution(impactEntity, 10, 15, 10, 20, 2.5, 5, 1.3, "AP")
local ceramicFrag = ACE.ArmorTypes.Cer.ArmorResolution(impactEntity, 10, 15, 10, 20, 2.5, 5, 1.3, "Frag")
assertFinite("Ceramic AP damage", ceramicAP.Damage)
assertFinite("Ceramic fragment damage", ceramicFrag.Damage)
ACE.ArmorTypes.Cer.ArmorResolution(impactEntity, 10, 15, 10, 100, 2.5, 5, 1.3, "AP")
assert(soundCalls > 0, "Ceramic shatter behavior was not activated")
ACE.ArmorTypes.DU.ArmorResolution(impactEntity, 10, 15, 10, 20, 2.5, 5, 1.3, "AP")
local duCallsBefore = heCalls
ACE.ArmorTypes.DU.ArmorResolution(impactEntity, 10, 15, 10, 100, 2.5, 5, 1.3, "AP")
assert(heCalls > duCallsBefore, "DU secondary blast behavior was not activated")
ACE.ArmorTypes.ERA.ArmorResolution(impactEntity, 10, 15, 10, 20, 2.5, 5, 1.3, "AP")
local eraCallsBefore = heCalls
ACE.ArmorTypes.ERA.ArmorResolution(impactEntity, 10, 15, 10, 100, 2.5, 5, 1.3, "AP")
assert(removed > 0, "ERA detonation behavior was not activated")
assert(heCalls > eraCallsBefore, "ERA detonation blast behavior was not activated")
assert(type(ACE.ArmorTypes.ERA.HEATList) == "table", "ERA HEATList compatibility field was lost")
assert(type(ACE.ArmorTypes.ERA.HEList) == "table", "ERA HEList compatibility field was lost")
assert(ACE.ERABoomPerTick == 1, "ERA boom counter initialization changed")

print("ACE legacy armor resolver parity self-test: PASS")
