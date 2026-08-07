local root = assert(arg[1], "usage: ace_points_model_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end

dofile(root .. "/lua/acf/shared/sh_ace_points_model.lua")

assert(ACE.PointsModel.ArmorMassAlpha == 0.5, "armor mass alpha must default to 0.5")
local expectedBaseArmorCost = ACE.PointsModel.kArmor * 100.0 * ACE.PointsModel.Scale * 10.0
assert(math.abs(ACE.Points.ArmorProp(50, 75, 1) - expectedBaseArmorCost) < 1e-9,
	"armor HP pricing must use the 10x balance multiplier")
assert(math.abs(ACE.Points.ArmorProp(50, 150, 1) / ACE.Points.ArmorProp(50, 75, 1) - 2.0) < 1e-9,
	"linear HP pricing must remain split-neutral")

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
	ACF = { MaxArmour = 100, MaxHealth = 100, Material = "Ti" },
}
local threatRHAe, health, massEfficiency = ACE.Points.PropArmor(primitive)
assert(threatRHAe ~= nil and health == 100 and massEfficiency > 1,
	"ordinary prop armor must return a lightweight-material premium")
primitive.ACE_PrimitivePropertiesPending = true
assert(ACE.Points.PropArmor(primitive) == nil,
	"Primitive armor must stay out of pricing while its properties are pending")

ACE.PointsModel.ArmorMassAlpha = 1.0
local titanium = ACE.Points.ArmorProp(threatRHAe, health, massEfficiency)
ACE.PointsModel.ArmorMassAlpha = 0.5
local relaxed = ACE.Points.ArmorProp(threatRHAe, health, massEfficiency)
ACE.PointsModel.ArmorMassAlpha = 2.0
local strict = ACE.Points.ArmorProp(threatRHAe, health, massEfficiency)
ACE.PointsModel.ArmorMassAlpha = 0.5
assert(relaxed < titanium and strict > titanium,
	"armor mass alpha must control the lightweight-material premium")

local unknown = {
	GetClass = primitive.GetClass,
	ACF = { MaxArmour = 100, MaxHealth = 100, Material = "Unknown" },
}
local _, _, unknownMassEfficiency = ACE.Points.PropArmor(unknown)
assert(math.abs(unknownMassEfficiency - 1) < 1e-12,
	"unknown materials must use neutral mass efficiency")

local gunWithGunner = ACE.Points.GunCost(1, 10, 0.5, 1)
local gunWithoutGunner = ACE.Points.GunCost(1, 10, 0.5, 2)
assert(math.abs(gunWithoutGunner / gunWithGunner - 2) < 1e-12,
	"ungunned guns must cost exactly twice as much firepower")

local minimumWithGunner = ACE.Points.GunCost(0, 0, 0, 1)
local minimumWithoutGunner = ACE.Points.GunCost(0, 0, 0, 2)
assert(math.abs(minimumWithoutGunner / minimumWithGunner - 2) < 1e-12,
	"the ungunned multiplier must apply to the flat firepower minimum")

print("ACE points model LuaJIT self-test: PASS")
