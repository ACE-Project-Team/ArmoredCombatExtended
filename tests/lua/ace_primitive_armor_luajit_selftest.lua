-- Offline lifecycle coverage for saved and legacy Primitive armor dupes.
local repo = assert(arg[1], "usage: luajit ace_primitive_armor_luajit_selftest.lua <ace-repo>")

ACE = {}
hook = { Stored = {} }
function hook.Add(event, name, callback)
	hook.Stored[event] = hook.Stored[event] or {}
	hook.Stored[event][name] = callback
end

local function isValid(value)
	return type(value) == "table" and value.valid ~= false
end

IsValid = isValid
isnumber = function(value) return type(value) == "number" end
istable = function(value) return type(value) == "table" end
isstring = function(value) return type(value) == "string" end
math.Clamp = function(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local activations = 0
function ACF_Activate(ent)
	activations = activations + 1
	ent.ACF = ent.ACF or {}
	ent.ACF.Area = 100
	ent.ACF.Armour = 50
	ent.ACF.MaxArmour = 50
	ent.ACF.Health = 20
	ent.ACF.MaxHealth = 20
	ent.ACF.PhysObj = ent.Phys
	ent.ACF.Mass = ent.Phys:GetMass()
end

function ACE.ClearArmorPointCache() end
function ACE.MarkArmorDirty() end

local function newPrimitive()
	local phys = {
		Mass = 100,
		valid = true,
	}
	function phys:GetMass() return self.Mass end

	local ent = {
		valid = true,
		IsPrimitive = true,
		Phys = phys,
	}
	function ent:GetPhysicsObject() return self.Phys end
	function ent:GetCollisionGroup() return 0 end
	function ent:SetCollisionGroup() end
	function ent:CFW_GetContraption() return nil end

	return ent
end

dofile(repo .. "/lua/autorun/server/sv_ace_primitive_compat.lua")

local pasted = assert(hook.Stored.AdvDupe_FinishPasting.ACE_CapturePrimitiveArmor)

local legacy = newPrimitive()
pasted({ {
	CreatedEntities = { [1] = legacy },
	EntityList = {
		[1] = {
			ACF = nil,
			EntityMods = { acfsettings = { Material = "Alum", Ductility = 80 } },
		},
	},
} })

assert(activations == 1, "legacy Primitive must activate immediately after AdvDupe finishes")
assert(legacy.ACF.Material == "Alum", "legacy material was not restored")
assert(legacy.ACF.Ductility == 0.8, "legacy ductility was not restored")
assert(legacy.ACE_PrimitiveSavedArmor == nil, "legacy Primitive captured transient armor")

local modern = newPrimitive()
modern.ACF = nil
local saved = {
	Area = 200,
	Armour = 60,
	MaxArmour = 80,
	Health = 25,
	MaxHealth = 40,
	Material = "Ti",
	Ductility = 0.2,
}
pasted({ {
	CreatedEntities = { [2] = modern },
	EntityList = { [2] = { ACF = saved } },
} })

assert(modern.ACF.Area == saved.Area, "modern Primitive area was not restored")
assert(modern.ACF.Armour == saved.Armour, "modern Primitive armor was not restored")
assert(modern.ACF.Material == saved.Material, "modern Primitive material was not restored")
assert(modern.ACF.Ductility == saved.Ductility, "modern Primitive ductility was not restored")

local rebuilt = newPrimitive()
rebuilt.ACF = {
	Area = 5,
	Armour = 2,
	MaxArmour = 2,
	Health = 1,
	MaxHealth = 1,
}
local beforeRebuildActivations = activations
hook.Stored.Primitive_PreRebuildPhysics.ACE_RememberPrimitiveCollisionGroup(rebuilt)
hook.Stored.Primitive_PostRebuildPhysics.ACE_PrimitiveArmorRecalc(rebuilt, {})
assert(activations == beforeRebuildActivations + 1, "ordinary Primitive rebuild did not recalculate armor")
assert(rebuilt.ACF.Area == 100, "ordinary Primitive rebuild preserved stale geometry")

print("ACE Primitive armor LuaJIT self-test: PASS")
