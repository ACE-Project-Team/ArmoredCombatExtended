local root = assert(arg[1], "usage: ace_points_material_mass_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function isstring(value) return type(value) == "string" end
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end
ACE.Points_MaterialPointEffectiveness = function() return "stale" end

dofile(root .. "/lua/acf/shared/sh_ace_points_model.lua")

local rha = ACE.Points.ArmorProp(50, 75, 1)
local titanium = ACE.Points.ArmorProp(50, 75, 1.7 / 0.61)
assert(titanium > rha, "lightweight armor must pay a mass-efficiency premium")

local rhaEffectiveness = ACE.Points.MaterialPointEffectiveness("RHA")
local castEffectiveness = ACE.Points.MaterialPointEffectiveness("CHA")
local titaniumEffectiveness = ACE.Points.MaterialPointEffectiveness("Ti")
assert(ACE.Points.MaterialPointEffectiveness ~= nil,
	"material point effectiveness helper must remain under ACE.Points")
assert(ACE.Points_MaterialPointEffectiveness == nil,
	"material point effectiveness must remain namespaced under ACE.Points")
assert(math.abs(rhaEffectiveness - 100) < 0.001, "RHA must be the point-effectiveness baseline")
assert(math.abs(castEffectiveness - 123.44) < 0.01,
	"cast steel point effectiveness changed unexpectedly")
assert(math.abs(titaniumEffectiveness - 29.02) < 0.01,
	"titanium point effectiveness changed unexpectedly")

ACE.PointsModel.ArmorMassAlpha = 0.5
local relaxed = ACE.Points.ArmorProp(50, 75, 1.7 / 0.61)
ACE.PointsModel.ArmorMassAlpha = 2.0
local strict = ACE.Points.ArmorProp(50, 75, 1.7 / 0.61)
ACE.PointsModel.ArmorMassAlpha = 1.0
assert(relaxed < titanium and strict > titanium,
	"armor mass alpha must control the lightweight-material premium")

local prop = {
	ACF = { MaxArmour = 50, MaxHealth = 75, Material = "Ti" },
	GetClass = function() return "prop_physics" end,
}
local threatRHAe, health, massEfficiency = ACE.Points.PropArmor(prop)
assert(math.abs(threatRHAe - 85) < 1,
	"titanium threat RHAe must use its effectiveness and curve")
assert(health == 75, "armor adapter must preserve max health")
assert(massEfficiency > 1, "titanium must carry a mass-efficiency premium")

ACE.ArmorTypes = {
	Custom = {
		effectiveness = 1.5,
		HEATeffectiveness = 2.5,
		massMod = 0.4,
		curve = 0.8,
	},
}

local custom = {
	ACF = { MaxArmour = 80, MaxHealth = 75, Material = "Custom" },
	GetClass = function() return "prop_physics" end,
}
local customRHAe, customHealth, customEfficiency = ACE.Points.PropArmor(custom)
local customExpected = 80 ^ 0.8 * (0.7 * 1.5 + 0.3 * 2.5)
assert(math.abs(customRHAe - customExpected) < 0.001,
	"custom material armor pricing must use live kinetic and chemical coefficients")
assert(customHealth == 75, "custom material adapter must preserve max health")
assert(math.abs(customEfficiency - customExpected / (80 * 0.4)) < 0.001,
	"custom material armor pricing must use live mass and curve coefficients")

print("ACE points material mass LuaJIT self-test: PASS")
