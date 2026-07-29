local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end

dofile(root .. "/lua/acf/shared/sh_ace_points_model.lua")

local empty = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 0 }
local loaded = { Type = "APHE", maxPen = 200, FrArea = math.pi * 5 ^ 2, blastMass = 60 }

assert(ACE.Points_IntrinsicValueMul(empty) == 1.0,
	"zero-filler APHE must not receive HE utility value")
assert(ACE.Points_GatePen(empty) == empty.maxPen,
	"zero-filler APHE must retain only its kinetic penetration gate")
assert(ACE.Points_IntrinsicValueMul(loaded) == 1.5,
	"loaded APHE must receive HE payload value")
assert(ACE.Points_GatePen(loaded) > ACE.Points_GatePen(empty),
	"loaded APHE filler must add HE-equivalent threat reach")
assert(ACE.Points_BaseRoundCost(loaded) > ACE.Points_BaseRoundCost(empty),
	"loaded APHE filler must add round cost")

local primitive = {
	GetClass = function() return "prop_physics" end,
	ACF = { MaxArmour = 100, MaxHealth = 100 },
}
assert(ACE.Points.PropArmor(primitive) ~= nil, "ordinary prop armor must remain priced")
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

print("ACE points model LuaJIT self-test: PASS")
