local root = assert(arg[1], "usage: ace_points_material_mass_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function isstring(value) return type(value) == "string" end
function istable(value) return type(value) == "table" end
function ACE.IsEnt(value) return value ~= nil end

dofile(root .. "/lua/acf/shared/sh_ace_points_model.lua")

local rha = ACE.Points.ArmorProp(50, 75, 1)
local titanium = ACE.Points.ArmorProp(50, 75, 1.7 / 0.61)
assert(titanium > rha, "lightweight armor must pay a mass-efficiency premium")

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

print("ACE points material mass LuaJIT self-test: PASS")
