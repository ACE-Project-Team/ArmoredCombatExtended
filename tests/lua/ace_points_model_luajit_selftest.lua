local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
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
local pricedMm, pricedHp = ACE.Points.PropArmor(primitive)
assert(pricedMm and pricedHp == 100, "ordinary prop armor must retain its normal health")
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

local rackRate = ACE.Points.RackRate(2, 1)
local rackScore = ACE.Points.RoundScore(loaded)
local rackBaseCost = ACE.Points.BaseRoundCost(loaded)
local rackPricedRate = math.max(rackRate, 1 / 30)
local rackWithoutRound = math.max(ACE.PointsModel.kGun * rackPricedRate * rackScore, 100)
local rackWithRound = ACE.Points.RackCostFromRate(rackRate, rackScore, rackBaseCost)
local rackExpected = (rackWithoutRound + rackBaseCost) * ACE.PointsModel.Scale
assert(math.abs(rackWithRound - rackExpected) < 1e-9,
	"rack firepower must add the selected round's base cost exactly once")
assert(math.abs(rackWithoutRound * ACE.PointsModel.Scale
	+ rackBaseCost * ACE.PointsModel.Scale - rackWithRound) < 1e-9,
	"rack delivery and base-round points must sum to the billed total")
assert(math.abs(ACE.Points.RackCostFromRate(rackRate, rackScore)
	- rackWithoutRound * ACE.PointsModel.Scale) < 1e-9,
	"rack pricing without the optional base cost must preserve the old result")
assert(math.abs(ACE.Points.RackCost(2, 1, rackScore)
	- rackWithoutRound * ACE.PointsModel.Scale) < 1e-9,
	"rack wrapper without the optional base cost must preserve the old result")
local rackFloor = ACE.Points.RackCostFromRate(0, 0, rackBaseCost)
assert(math.abs(rackFloor - (100 + rackBaseCost) * ACE.PointsModel.Scale) < 1e-9,
	"rack flat floor must apply before the base-round addition")

print("ACE points model LuaJIT self-test: PASS")
