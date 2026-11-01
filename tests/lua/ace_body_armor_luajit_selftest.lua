-- Offline coverage for body armor resolved as ACE armor plates: real material files, ACE.CalcDamage and
-- ACE.ResolveBodyArmor, fired with small arms rounds at a helmet, plates and HL2 suit armor.
local repo = assert(arg[1], "usage: luajit ace_body_armor_luajit_selftest.lua <ace-repo>")

SERVER = true
ACE = { ArmorTypes = {} }
hook = { Stored = {} }
function hook.Add(event, name, callback)
	hook.Stored[event] = hook.Stored[event] or {}
	hook.Stored[event][name] = callback
end
function hook.Run(event, ...)
	for _, callback in pairs(hook.Stored[event] or {}) do callback(...) end
end

IsValid = function(value) return value ~= nil end
isnumber = function(value) return type(value) == "number" end
istable = function(value) return type(value) == "table" end
Sound = function(path) return path end
math.Clamp = function(value, minimum, maximum) return math.max(minimum, math.min(maximum, value)) end
DMG_CLUB, DMG_PREVENT_PHYSICS_FORCE, DMG_BULLET = 128, 2048, 2
HITGROUP_GENERIC, HITGROUP_HEAD, HITGROUP_CHEST, HITGROUP_STOMACH = 0, 1, 2, 3
HITGROUP_LEFTARM, HITGROUP_RIGHTARM, HITGROUP_LEFTLEG, HITGROUP_RIGHTLEG, HITGROUP_GEAR = 4, 5, 6, 7, 10

local VectorMeta = {}
VectorMeta.__index = VectorMeta
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VectorMeta) end
VectorMeta.__unm = function(a) return Vector(-a.x, -a.y, -a.z) end
VectorMeta.__mul = function(a, b) return Vector(a.x * b, a.y * b, a.z * b) end
function VectorMeta:Dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function VectorMeta:LengthSqr() return self:Dot(self) end
function VectorMeta:GetNormalized() local l = math.sqrt(self:LengthSqr()) return Vector(self.x / l, self.y / l, self.z / l) end

-- Globals from acf_globals.lua
ACE.SlopeEffectFactor = 1
ACE.PenAreaMod = 0.85
ACE.KEtoRHA = 0.25
ACE.KinFudgeFactor = 2.1
ACE.KineticDamageThreshold = 0.65
ACE.APDamageMult = 2

local function extract(path, name)
	local file = assert(io.open(repo .. "/" .. path, "rb"))
	local source = file:read("*a"):gsub("\r\n", "\n")
	file:close()

	local first = assert(source:find("function " .. name .. "%(", 1), name .. " not found in " .. path)
	local last = assert(source:find("\nend\n", first, true), name .. " has no end")
	assert(loadstring(source:sub(first, last + 4), name))()
end

extract("lua/ace/shared/sh_ace_functions.lua", "ACE.Kinetic")
extract("lua/ace/shared/sh_ace_functions.lua", "ACE.CalcPenetration")
extract("lua/ace/server/sv_acfbase.lua", "ACE.CalcDamage")
extract("lua/ace/server/sv_acfdamage.lua", "ACE.GetPostPenetration")
extract("lua/ace/server/sv_acfdamage.lua", "ACE.GetHitAngle")

function ACE.IsKineticDamageType(Type) return Type == "AP" end
function ACE.GetMaterialData(Mat) return ACE.ArmorTypes[Mat] or ACE.ArmorTypes.RHA end

for _, name in ipairs({ "rha", "ceramic", "aramid", "textolite" }) do
	dofile(repo .. "/lua/ace/shared/armor/" .. name .. ".lua")
end

-- ace_bodyarmor_min_damage, changeable per test
local MinDamageValue = 4
function GetConVar() return { GetFloat = function() return MinDamageValue end } end

-- ApplyDamage's plumbing: DamageInfo records the damage, TakeDamageInfo records the hit
game = { GetWorld = function() return "world" end }
function DamageInfo()
	local Info = { Damage = 0 }
	function Info:SetDamage(D) self.Damage = D end
	function Info:SetDamageType() end
	function Info:SetAttacker() end
	function Info:SetInflictor() end
	function Info:SetDamagePosition() end
	function Info:SetDamageForce() end
	function Info:GetAttacker() return nil end
	return Info
end

local function Victim()
	local V = { Taken = {} }
	function V:TakeDamageInfo(Info) self.Taken[#self.Taken + 1] = Info.Damage end
	function V:IsPlayer() return false end
	function V:IsNPC() return false end
	function V:GetPhysicsObject() return nil end
	function V:GetMaxHealth() return 100 end
	function V:WorldSpaceCenter() return Vector() end
	return V
end

dofile(repo .. "/lua/ace/server/sv_ace_squishy_damage.lua")

-- Small arms rounds as ace_smallarms fires them at the muzzle: caliber mm, mass g, velocity m/s, penMul
local Rounds = {
	["9x19"]     = { 9, 8, 360, 2.5 },
	["5.56x45"]  = { 5.7, 4, 940, 1.3 },
	["7.62x51"]  = { 7.82, 9.5, 850, 1.3 },
	["7.62x54R"] = { 7.92, 9.6, 830, 1.7 },
	[".338LM"]   = { 8.6, 16.2, 915, 1.3 },
}

local function round(name)
	local r = Rounds[name]
	local Caliber = r[1] / 10
	local FrArea = math.pi * (Caliber / 2) ^ 2
	return ACE.Kinetic(r[3] * 39.37, r[2] / 1000, 800), FrArea ^ ACE.PenAreaMod * 1.1 / r[4]
end

local Wearer = { EmitSound = function() end } -- Ceramic shatters audibly when penetrated

-- Fires a round at one stack of layers N times. Angle is between the flight and the armor's normal.
local function stopRate(name, Stack, Angle)
	local Rad = math.rad(Angle or 0)
	local Dir = Vector(math.sin(Rad), 0, -math.cos(Rad))
	local Stopped, N = 0, 2000

	hook.Stored.ACE_GetBodyArmor = { Test = function(_, _, Layers)
		for _, Layer in ipairs(Stack) do
			Layers[#Layers + 1] = { Material = Layer[1], Armour = Layer[2], Normal = Angle and Vector(0, 0, 1) }
		end
	end }

	for _ = 1, N do
		local Energy, PenArea = round(name)
		local Left, BluntJ = ACE.ResolveBodyArmor(Wearer, HITGROUP_CHEST, Energy, PenArea, "AP", Vector(), Dir)
		if not Left then
			Stopped = Stopped + 1
			assert(BluntJ > 0 and BluntJ < Energy.Kinetic * 1000, "blunt energy is a share of the bullet's")
		end
	end

	return Stopped / N
end

local Helmet = { { "Aramid", 10 } }
local Plate = { { "Cer", 3.5 }, { "Aramid", 4 } }

local checks = {
	{ "helmet stops 9x19 square on",           stopRate("9x19", Helmet, 0),     ">", 0.95 },
	{ "5.56 goes through the helmet square on", stopRate("5.56x45", Helmet, 0),  "<", 0.1 },
	{ "helmet stops 5.56 at 60 degrees",       stopRate("5.56x45", Helmet, 60), ">", 0.95 },
	{ "plate stops 5.56",                      stopRate("5.56x45", Plate, 0),   ">", 0.95 },
	{ "plate stops 7.62x51",                   stopRate("7.62x51", Plate, 0),   ">", 0.95 },
	{ "7.62x54R goes through the plate",       stopRate("7.62x54R", Plate, 0),  "<", 0.1 },
	{ ".338 goes through the plate",           stopRate(".338LM", Plate, 0),    "<", 0.1 },
	{ "100 suit points stop 9x19",             stopRate("9x19", { { "Aramid", 7 } }), ">", 0.9 },
	{ "100 suit points don't stop 5.56",       stopRate("5.56x45", { { "Aramid", 7 } }), "<", 0.1 },
}

local failed = 0
for _, check in ipairs(checks) do
	local label, rate, op, limit = check[1], check[2], check[3], check[4]
	local ok = (op == ">" and rate > limit) or (op == "<" and rate < limit)
	print(string.format("%s %-40s stopped %.3f", ok and "ok  " or "FAIL", label, rate))
	if not ok then failed = failed + 1 end
end

-- A penetrated layer passes on what's left: lower energy and penetration for the next one
hook.Stored.ACE_GetBodyArmor = { Test = function(_, _, Layers) Layers[1] = { Material = "Cer", Armour = 3.5 } end }
local Energy, PenArea = round(".338LM")
local Left = ACE.ResolveBodyArmor(Wearer, HITGROUP_CHEST, Energy, PenArea, "AP")
assert(Left and Left.Kinetic < Energy.Kinetic and Left.Penetration < Energy.Penetration, "penetrated layer takes energy")
assert(Energy.Kinetic == select(1, round(".338LM")).Kinetic, "the bullet's own energy table is left alone")

-- DU and ERA need a real prop, so they resolve as RHA instead of erroring
local HitRes = ACE.ResolveArmorLayer(nil, "ERA", 5, Energy, PenArea, 0, "AP")
assert(HitRes.Loss, "prop-only materials fall back")

-- A penetrated real armor layer marks the energy as armored; a suit layer doesn't
hook.Stored.ACE_GetBodyArmor = { Test = function(_, _, Layers) Layers[1] = { Material = "Cer", Armour = 3.5 } end }
Energy, PenArea = round(".338LM")
Left = ACE.ResolveBodyArmor(Wearer, HITGROUP_CHEST, Energy, PenArea, "AP")
assert(Left and Left.Armored == true, "a penetrated armor layer flags the hit as armored")

hook.Stored.ACE_GetBodyArmor = { Test = function(_, _, Layers) Layers[1] = { Material = "Cer", Armour = 3.5, Suit = true } end }
Energy, PenArea = round(".338LM")
Left = ACE.ResolveBodyArmor(Wearer, HITGROUP_CHEST, Energy, PenArea, "AP")
assert(Left and not Left.Armored, "the HL2 suit doesn't count as armor")

-- ace_bodyarmor_min_damage: damage under the threshold is skipped only when armor was involved.
-- 300 J stopped by a plate leaves ~45 J blunt (1.1 HP) / ~120 J through aramid (3 HP), both under 4.
local function fleshDamage(Layer)
	hook.Stored.ACE_GetBodyArmor = { Test = function(_, _, Layers)
		if Layer then Layers[1] = Layer end
	end }
	local V = Victim()
	local Round, FrArea = round("9x19")
	Round.Kinetic = 0.3
	ACE.FleshDamage(V, Round, FrArea, nil, HITGROUP_CHEST)
	return V.Taken
end

assert(#fleshDamage({ Material = "RHA", Armour = 50 }) == 0, "armored hit under the threshold applies nothing")
assert(#fleshDamage({ Material = "Aramid", Armour = 50, Suit = true }) == 1, "suit armor doesn't get the threshold")
assert(#fleshDamage(nil) == 1, "a bare hit is unaffected")

-- The same floor reaches the wound path: a penetrated layer's weak hit still does nothing
local V = Victim()
ACE.FleshHit(V, 300, 0, 9, HITGROUP_CHEST, nil, nil, nil, nil, 4)
assert(#V.Taken == 0, "FleshHit honours MinDamage")
ACE.FleshHit(V, 300, 0, 9, HITGROUP_CHEST)
assert(#V.Taken == 1 and V.Taken[1] > 0, "without MinDamage the same hit lands")

if failed > 0 then
	error(failed .. " body armor checks failed")
end
print("body armor self-test passed")
