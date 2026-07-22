local root = assert(arg[1], "usage: ace_missile_launch_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local source = assert(io.open(root .. "/lua/autorun/server/sv_acf_missiles.lua", "r")):read("*a")
local start = assert(source:find("function ACE_Missile_BulletLaunch"))
local finish = assert(source:find("function ACE_Missile_ExpandBulletData", start))

ACE = {
	CurBulletIndex = 0,
	BulletIndexLimit = 128,
	BallisticsGravity = -600,
	BallisticsGravityVector = { z = -600 },
	SysTime = 12.5,
	Bullet = {},
	BallisticsFrame = 9,
}

local registeredIndex
local registeredBullet
local clientBullet

function ACE_AcquireBullet(BulletData)
	local Copy = {}
	for Key, Value in pairs(BulletData) do
		Copy[Key] = Value
	end
	return Copy
end

function ACE_RegisterBullet(Index, Bullet)
	registeredIndex = Index
	registeredBullet = Bullet
	ACE.Bullet[Index] = Bullet
end

function ACE_BulletClient(_, Bullet)
	clientBullet = Bullet
end

local gun = {}
local filterEnt = {}
local original = {
	Type = "HEAT",
	Gun = gun,
	Filter = { filterEnt },
}

assert(loadstring(source:sub(start, finish - 1)))()
ACE_Missile_BulletLaunch(original)

assert(original.Index == 1)
assert(original.Gravity == ACE.BallisticsGravity)
assert(original.Accel == ACE.BallisticsGravityVector)
assert(original.LastThink == ACE.SysTime)
assert(original.FlightTime == 0)
assert(original.TraceBackComp == 0)
assert(original.FuseLength == 0)
assert(original.ActiveFrame == ACE.BallisticsFrame)
assert(original.Filter[1] == filterEnt and original.Filter[2] == gun)

assert(registeredIndex == original.Index)
assert(registeredBullet)
assert(registeredBullet ~= original)
assert(registeredBullet.Index == original.Index)
assert(registeredBullet.Gravity == original.Gravity)
assert(registeredBullet.LastThink == original.LastThink)
assert(registeredBullet.Filter == original.Filter)
assert(clientBullet == registeredBullet)

local impactIndex
local impactBullet
local roundType = {
	propimpact = function(Index, Bullet)
		impactIndex = Index
		impactBullet = Bullet
	end,
}
ACE.RoundTypes = { HEAT = roundType }

local Bullet = original
local Index = Bullet.Index
ACE.RoundTypes[Bullet.Type].propimpact(Index, Bullet)

assert(impactIndex == original.Index)
assert(impactBullet == original)

print("ACE missile launch LuaJIT self-test: PASS")
