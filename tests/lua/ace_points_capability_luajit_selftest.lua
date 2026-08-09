-- Best-practical (capability) firepower pricing: a gun bills at least the best round it
-- could practically fire, so weak linked ammo, missing links, and tiny wire ROF limits can
-- no longer discount the weapon; configured crates bill their own configuration charge.
-- Runs the REAL gun/round definitions and the real pricing resolver under LuaJIT stubs.

local root = assert(arg[1], "usage: ace_points_capability_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

-- ---------------------------------------------------------------- GMod environment stubs
SERVER = true
CLIENT = false

function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return istable(v) and v.__valid ~= false end
function AddCSLuaFile() end
function Vector() return { x = 0, y = 0, z = 0 } end
function CurTime() return 0 end

hook = { Add = function() end, Run = function() end, Remove = function() end }
timer = { Simple = function() end, Create = function() end, Exists = function() return false end }
list = { Set = function() end, Get = function() return {} end }
concommand = { Add = function() end }
duplicator = { RegisterEntityModifier = function() end }

function math.Clamp(v, lo, hi) return math.min(math.max(v, lo), hi) end
function math.Round(v, d)
	local mult = 10 ^ (d or 0)
	return math.floor(v * mult + 0.5) / mult
end

function table.Merge(dest, source)
	for k, v in pairs(source) do
		if type(v) == "table" and type(dest[k]) == "table" then
			table.Merge(dest[k], v)
		else
			dest[k] = v
		end
	end
	return dest
end

function table.Inherit(t, base)
	for k, v in pairs(base) do
		if t[k] == nil then t[k] = v end
	end
	t.BaseClass = base
	return t
end

function table.IsEmpty(t) return next(t) == nil end

function table.Copy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do copy[k] = table.Copy(v) end
	return copy
end

function string.Comma(n)
	return tostring(n)
end

-- ACE namespace with the production ACE.X -> _G.ACE_X fallback.
ACE = setmetatable({}, {
	__index = function(_, key)
		local value = rawget(_G, "ACE_" .. key)
		if value ~= nil then return value end
		return nil
	end,
})
ACF = ACE

function ACE_IsEnt(v) return istable(v) and v.__valid ~= false end

-- Numeric globals harvested from the real config so ballistics constants cannot drift.
do
	local f = assert(io.open(root .. "/lua/autorun/acf_globals.lua", "r"))
	local src = f:read("*a")
	f:close()
	for name, value in src:gmatch("ACE%.([%w_]+)%s*=%s*(%-?%d+%.?%d*)%s") do
		if rawget(ACE, name) == nil then ACE[name] = tonumber(value) end
	end
	assert(ACE.PDensity and ACE.PBase and ACE.KEtoRHA and ACE.HEPower and ACE.HEBlastPenetration,
		"acf_globals constant harvest must find the ballistics constants")
end

-- Auto-vivifying translation table: round/gun names only feed display strings.
ACE.Translation = setmetatable({}, {
	__index = function(t, k)
		local entry = setmetatable({}, { __index = function() return k end })
		rawset(t, k, entry)
		return entry
	end,
})

ACE.AmmoBlacklist = {}
ACE.RoundTypes = {}
ACE.IdRounds = {}
ACE.Weapons = { Guns = {} }
ACE.Classes = { GunClass = {} }
ACE.ArmorTypes = {}
ACE.ArmorClasses = {}

function ACE_DefineMuzzleFlash() end

function ACE_DefineGunClass(id, data)
	data.id = id
	ACE.Classes.GunClass[id] = data
end

function ACE_DefineGun(id, data)
	data.id = id
	data.round.id = id
	data.ent = "acf_gun"
	data.type = "Guns"
	ACE.Weapons.Guns[id] = data
end

-- include() inside sh_ace_functions loads its pricing model dependency; the manufacturing
-- model is not needed by the firepower path and stays stubbed out.
function include(path)
	if path:find("sh_ace_points_model", 1, true) then
		dofile(root .. "/lua/" .. path)
	end
end

-- ---------------------------------------------------------------- real definitions + resolver
dofile(root .. "/lua/acf/shared/rounds/ace_roundfunctions.lua")
for _, roundFile in ipairs({
	"roundap", "roundaphe", "roundapds", "roundapfsds", "roundhvap",
	"roundhe", "roundheat", "roundhesh", "roundhp", "roundsmoke", "roundrefill",
}) do
	dofile(root .. "/lua/acf/shared/rounds/" .. roundFile .. ".lua")
end

for _, gunFile in ipairs({ "cannon", "machinegun", "rotaryautocannon", "smoothcannon" }) do
	dofile(root .. "/lua/acf/shared/guns/" .. gunFile .. ".lua")
end

dofile(root .. "/lua/acf/shared/sh_ace_functions.lua")

assert(ACE.RoundTypes.AP and ACE.RoundTypes.APFSDS and ACE.RoundTypes.HE,
	"real round definitions must be registered")
assert(ACE.Weapons.Guns["120mmC"] and ACE.Weapons.Guns["20mmRAC"] and ACE.Weapons.Guns["12.7mmMG"],
	"real gun definitions must be registered")

-- ---------------------------------------------------------------- helpers
local function makeGun(id)
	local def = assert(ACE.Weapons.Guns[id], "unknown gun id " .. id)
	local classData = assert(ACE.Classes.GunClass[def.gunclass], "unknown gun class")
	local frArea = 3.1416 * (def.caliber / 2) ^ 2
	return {
		__valid = true,
		Id = id,
		Caliber = def.caliber,
		Class = def.gunclass,
		MagSize = math.max(def.magsize or 1, 1),
		MagReload = math.max(def.magreload or 0, 0),
		RoFmod = classData.rofmod or 1,
		PGRoFmod = math.max(def.rofmod or 1, 0.01),
		maxrof = def.maxrof,
		MinLengthBonus = 0.5 * frArea * def.round.maxlength,
		LoaderCount = 0,
		HasGunner = true,
		ROFLimit = 0,
		AmmoLink = {},
		GetClass = function() return "acf_gun" end,
		EntIndex = function() return 1 end,
	}
end

local crateIndex = 10
local function makeCrate(bdata)
	crateIndex = crateIndex + 1
	local index = crateIndex
	return {
		__valid = true,
		BulletData = bdata,
		GetClass = function() return "acf_ammo" end,
		EntIndex = function() return index end,
	}
end

local function convertRound(gunId, typeName, playerData)
	playerData.Id = gunId
	playerData.Type = typeName
	playerData.Tracer = playerData.Tracer or 0
	playerData.TwoPiece = playerData.TwoPiece or 0
	local data = assert(ACE.RoundTypes[typeName].convert(nil, playerData),
		"convert must return SERVER data")
	return data
end

-- ---------------------------------------------------------------- capability synthesis
local best120 = assert(ACE.Points.BestPracticalRound("120mmC"),
	"a 120mm cannon must synthesize a best practical round")
assert(best120.Round.maxPen > 100, "a 120mm cannon's best practical round must penetrate")
assert(best120.Round.Type ~= "APFSDS", "APFSDS is blacklisted for plain cannons")
assert(best120.Rps > 0 and best120.FinalScore > 0, "capability rate and score must be positive")
assert(ACE.Points.BestPracticalRound("120mmC") == best120,
	"best practical rounds must be cached per gun id")

local bestSB = assert(ACE.Points.BestPracticalRound("120mmSBC"),
	"a 120mm smoothbore must synthesize a best practical round")
assert(bestSB.Round.Type ~= "HEAT", "HEAT is blacklisted for smoothbore cannons")
assert(bestSB.Round.maxPen > 400,
	"a 120mm smoothbore's best practical round must carry real penetration")

local bestMG = assert(ACE.Points.BestPracticalRound("12.7mmMG"),
	"a machinegun must synthesize a best practical round")
local mgBlacklisted = { HE = true, HEAT = true, APDS = true, APFSDS = true }
assert(not mgBlacklisted[bestMG.Round.Type],
	"a machinegun's best practical round must respect the ammo blacklists")

local bestRAC = assert(ACE.Points.BestPracticalRound("20mmRAC"))
assert(bestRAC.Rps > 10, "a rotary autocannon's practical rate must stay high")
assert(bestSB.Rps <= (ACE.Weapons.Guns["120mmSBC"].maxrof / 60) + 1e-9,
	"capability rate must respect the definition maxrof cap")

-- ---------------------------------------------------------------- exploit closure
local gun = makeGun("120mmC")
local unlinked = assert(ACE.GetGunFirepowerReadout(gun))
assert(unlinked.Capability, "an unlinked gun must bill its best practical configuration")
assert(unlinked.Points > 20, "capability pricing must exceed the flat weapon minimum")

gun.RoFmod, gun.PGRoFmod = nil, nil
local missingModifiers = assert(ACE.GetGunFirepowerReadout(gun))
gun.RoFmod, gun.PGRoFmod = 1, 1
local neutralModifiers = assert(ACE.GetGunFirepowerReadout(gun))
assert(math.abs(missingModifiers.Points - neutralModifiers.Points) < 1e-9,
	"missing ROF modifiers must retain the neutral legacy cadence")

-- Linking a deliberately weak round must not discount the gun below capability.
local weakData = convertRound("120mmC", "AP", { ProjLength = 20, PropLength = 2 })
gun.AmmoLink = { makeCrate(weakData) }
local weakLinked = assert(ACE.GetGunFirepowerReadout(gun))
assert(weakLinked.Capability, "weak linked ammo must lose to the capability bid")
assert(math.abs(weakLinked.Points - unlinked.Points) < 1e-6,
	"weak linked ammo must not change the capability price")

-- A tiny wired ROF limit must not price the gun below capability either.
gun.ROFLimit = 0.1
local throttled = assert(ACE.GetGunFirepowerReadout(gun))
assert(math.abs(throttled.Points - unlinked.Points) < 1e-6,
	"a tiny ROF limit must not discount the gun below capability")
gun.ROFLimit = 0

-- A configured round that genuinely outscores the practical best wins and clears the flag.
local monsterData = convertRound("120mmC", "AP", { ProjLength = 20, PropLength = 2 })
monsterData.MaxPen = 5000
gun.AmmoLink = { makeCrate(monsterData) }
local monster = assert(ACE.GetGunFirepowerReadout(gun))
assert(not monster.Capability,
	"a configured round that outscores the practical best must price the gun")
assert(monster.Points > unlinked.Points,
	"an over-practical configuration must raise the price, never lower it")

-- The no-gunner contract is preserved under capability pricing.
gun.AmmoLink = {}
gun.HasGunner = false
local ungunned = assert(ACE.GetGunFirepowerReadout(gun))
assert(math.abs(ungunned.Points / unlinked.Points - 2) < 1e-9,
	"the ungunned 2x multiplier must apply to capability pricing")
gun.HasGunner = true

-- Capability notice renders only when the capability bid priced the weapon.
assert(ACE.GetCapabilityPricingLine(unlinked, true), "capability pricing must announce itself")
assert(ACE.GetCapabilityPricingLine(monster, true) == nil,
	"configured pricing must not show the capability notice")

-- ---------------------------------------------------------------- crate configuration charge
local strongData = convertRound("120mmSBC", "APFSDS", { ProjLength = 60, PropLength = 40, Data5 = 0.5 })
local strongCrate = makeCrate(strongData)
local strongCost = ACE.GetAmmoCrateConfigCost(strongCrate)
local strongRound = ACE.Points.RoundFromBullet(strongData)
assert(math.abs(strongCost - ACE.Points.CrateCost(ACE.Points.RoundScore(strongRound))) < 1e-9,
	"a crate must bill one window-delivery of its configured round score")
assert(strongCost > 0, "a lethal configuration must carry a crate charge")

local weakCost = ACE.GetAmmoCrateConfigCost(makeCrate(weakData))
assert(weakCost < strongCost, "weaker configurations must bill smaller crate charges")

local smokeData = convertRound("120mmC", "SM", { ProjLength = 30, PropLength = 10, Data5 = 100 })
assert(ACE.GetAmmoCrateConfigCost(makeCrate(smokeData)) == 0,
	"utility configurations must bill zero crate points")

assert(ACE.GetAmmoCrateConfigCost(makeCrate(nil)) == 0,
	"crates without bullet data must bill zero")
assert(ACE.GetPtsType("acf_ammo") == "Firepower",
	"configured crates must bill under the Firepower category")
assert(ACE.GetEntPoints(makeCrate(strongData)) == strongCost,
	"the points ledger must bill crates their configuration charge")

print("ACE points capability LuaJIT self-test: PASS")
