local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
ACE.HealthRefmm = 10 -- pricing compensation input (acf_globals.lua)
ACE.ArmorMod = 1
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end
dofile(root .. "/lua/ace/shared/sh_ace_entity_state.lua")

dofile(root .. "/lua/ace/shared/sh_ace_points_model.lua")

local empty = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 0 }
local loaded = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 60 }

assert(ACE.Points.IntrinsicValueMul(empty) == 1.0,
	"zero-filler APHE must not receive HE utility value")
assert(ACE.Points.GatePen(empty) == empty.maxPen,
	"zero-filler APHE must retain only its kinetic penetration gate")
assert(ACE.Points.IntrinsicValueMul(loaded) == 1.5,
	"loaded APHE must receive HE payload value")
assert(ACE.Points.GatePen(loaded) > ACE.Points.GatePen(empty),
	"loaded APHE filler must add HE-equivalent threat reach")
assert(ACE.Points.BaseRoundCost(loaded) > ACE.Points.BaseRoundCost(empty),
	"loaded APHE filler must add round cost")

local primitive = {
	GetClass = function() return "prop_physics" end,
	ACE = { MaxArmour = 100, MaxHealth = 100 },
}
assert(ACE.Points.PropArmor(primitive) ~= nil, "ordinary prop armor must remain priced")
local _, pricedHp = ACE.Points.PropArmor(primitive)
assert(pricedHp == 100 * ACE.HealthRefmm * ACE.ArmorMod / 100,
	"pricing must undo the mass-scaled health factor exactly")
ACE.ArmorMod = 2
local _, pricedHpMod = ACE.Points.PropArmor(primitive)
assert(pricedHpMod == 100 * ACE.HealthRefmm * ACE.ArmorMod / 100,
	"the compensation must scale with ACE.ArmorMod, not against it")
ACE.ArmorMod = 1
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

print("ACE points model LuaJIT self-test: PASS")
