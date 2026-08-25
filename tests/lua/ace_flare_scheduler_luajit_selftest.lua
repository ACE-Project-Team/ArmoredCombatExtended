local root = assert(arg[1], "usage: ace_flare_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local hooks = {}
hook = {
	Add = function(name, identifier, callback)
		hooks[name] = hooks[name] or {}
		hooks[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if hooks[name] then hooks[name][identifier] = nil end
	end,
}

local now = 0
function CurTime() return now end
ACE = { CMTable = {}, CurTime = 0 }

local function makeFlare()
	return {
		valid = true,
		water = 0,
		FirstTime = 0,
		Life = 1,
		FirstThermal = 10,
		FirstRadarSig = 4,
		Thermal = 10,
		RadarSig = 4,
		nextThink = nil,
		stops = 0,
		NextThink = function(self, due) self.nextThink = due end,
		WaterLevel = function(self) return self.water end,
		StopParticles = function(self) self.stops = self.stops + 1 end,
	}
end

local function near(actual, expected)
	return math.abs(actual - expected) < 1e-9
end

local function legacyThink(ent, time)
	if ent:WaterLevel() == 3 then
		ent.Thermal = 0
		ent:StopParticles()
		return false
	end

	local effectiveness = 1 - (time - ent.FirstTime) / ent.Life
	ent.Thermal = ent.FirstThermal * effectiveness
	ent.RadarSig = ent.FirstRadarSig * effectiveness
	ent:NextThink(time + 0.2)
	return true
end

local function snapshot(ent, returned)
	return {
		Thermal = ent.Thermal,
		RadarSig = ent.RadarSig,
		nextThink = ent.nextThink,
		stops = ent.stops,
		returned = returned,
	}
end

local function assertParity(actual, expected, label, compareNextThink)
	assert(near(actual.Thermal, expected.Thermal), label .. " thermal diverged")
	assert(near(actual.RadarSig, expected.RadarSig), label .. " radar signature diverged")
	assert(actual.stops == expected.stops, label .. " particle-stop behavior diverged")
	assert(actual.returned == expected.returned, label .. " Think return diverged")
	if not compareNextThink or not actual.returned then return end
	if actual.nextThink == nil or expected.nextThink == nil then
		assert(actual.nextThink == expected.nextThink, label .. " next Think diverged")
	else
		assert(near(actual.nextThink, expected.nextThink), label .. " next Think diverged")
	end
end

function IsValid(ent) return ent and ent.valid == true end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_flare_scheduler.lua")
local scheduler = ACE.Scheduler

local function reset()
	if scheduler.Enabled then scheduler.Disable() end
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	ACE.CMTable = {}
	ACE.FlareThinkSchedulerState.Records = setmetatable({}, { __mode = "k" })
	ACE.FlareThinkSchedulerState.NextId = 0
	ACE.FlareThinkSchedulerState.Enabled = false
	now = 0
	ACE.CurTime = 0
end

reset()
local fallback = makeFlare()
local legacy = makeFlare()
ACE.CMTable[fallback] = true
assert(ACE.RegisterFlareThink(fallback), "fallback flare registration was rejected")
local fallbackResult = ACE.FlareThink(fallback)
local legacyResult = legacyThink(legacy, now)
assertParity(snapshot(fallback, fallbackResult), snapshot(legacy, legacyResult), "initial fallback")

now = 0.2
ACE.CurTime = now
fallbackResult = ACE.FlareThink(fallback)
legacyResult = legacyThink(legacy, now)
assertParity(snapshot(fallback, fallbackResult), snapshot(legacy, legacyResult), "second fallback")

assert(scheduler.Enable(), "flare scheduler did not enable")
assert(scheduler.GetSize() == 1, "enabling did not attach the live flare")
assert(fallback.nextThink > 1000, "native flare Think was not parked")
now = 0.4
ACE.CurTime = now
assert(scheduler.Run(now).Ran == 1, "heap flare Think did not run")
legacyResult = legacyThink(legacy, now)
assertParity(snapshot(fallback, true), snapshot(legacy, legacyResult), "heap step", false)
assert(scheduler.GetSize() == 1, "heap flare Think did not reschedule")

assert(scheduler.Disable(), "flare scheduler did not disable")
assert(scheduler.GetSize() == 0, "disable retained flare heap work")
assert(math.abs(fallback.nextThink - 0.6) < 1e-9, "disable did not restore the next native due time")
now = 0.6
ACE.CurTime = now
fallbackResult = ACE.FlareThink(fallback)
legacyResult = legacyThink(legacy, now)
assertParity(snapshot(fallback, fallbackResult), snapshot(legacy, legacyResult), "fallback after disable")

local nativeSubmerged = makeFlare()
ACE.CMTable[nativeSubmerged] = true
assert(ACE.RegisterFlareThink(nativeSubmerged), "disabled submerged flare registration was rejected")
nativeSubmerged.water = 3
now = 0.7
ACE.CurTime = now
local legacySubmerged = makeFlare()
legacySubmerged.water = 3
fallbackResult = ACE.FlareThink(nativeSubmerged)
legacyResult = legacyThink(legacySubmerged, now)
assertParity(snapshot(nativeSubmerged, fallbackResult), snapshot(legacySubmerged, legacyResult), "disabled submerged fallback")
assert(nativeSubmerged.stops == 1, "disabled fallback did not stop particles once")
assert(ACE.FlareThink(nativeSubmerged) == false and nativeSubmerged.stops == 2, "disabled submerged flare did not preserve Think behavior")
ACE.UnregisterFlareThink(nativeSubmerged)
ACE.CMTable[nativeSubmerged] = nil

assert(scheduler.Enable(), "flare scheduler did not re-enable")
now = 0.8
ACE.CurTime = now
fallback.water = 3
assert(scheduler.Run(now).Ran == 1, "submerged flare callback did not run")
legacy.water = 3
legacyResult = legacyThink(legacy, now)
assertParity(snapshot(fallback, false), snapshot(legacy, legacyResult), "enabled submerged heap")
assert(fallback.Thermal == 0 and near(fallback.RadarSig, legacy.RadarSig), "submerged contract changed frozen RadarSig")
assert(fallback.stops == 1 and scheduler.GetSize() == 1, "submerged flare did not retain its polling cadence")
assert(ACE.FlareThink(fallback) == true and fallback.stops == 1, "enabled submerged flare lost its parked Think path")
assert(scheduler.Disable(), "disable after submersion failed")
assert(ACE.FlareThink(fallback) == false and fallback.stops == 2, "submerged flare did not preserve fallback Think behavior")
ACE.UnregisterFlareThink(fallback)
ACE.CMTable[fallback] = nil

local reloadFlare = makeFlare()
reloadFlare.FirstTime = 1
ACE.CMTable[reloadFlare] = true
now = 1
ACE.CurTime = now
assert(ACE.RegisterFlareThink(reloadFlare), "reload flare registration was rejected")
assert(scheduler.Enable(), "scheduler did not enable for reload fixture")
assert(scheduler.GetSize() == 1, "reload fixture did not attach")
dofile(root .. "/lua/ace/server/sv_ace_flare_scheduler.lua")
assert(scheduler.GetSize() == 1, "adapter reload stranded or duplicated flare work")
now = 1
ACE.CurTime = now
assert(scheduler.Run(now).Ran == 1, "reloaded flare callback did not run")
local legacyReload = makeFlare()
legacyReload.FirstTime = 1
legacyResult = legacyThink(legacyReload, now)
assertParity(snapshot(reloadFlare, true), snapshot(legacyReload, legacyResult), "reloaded flare", false)

ACE.UnregisterFlareThink(reloadFlare)
assert(scheduler.GetSize() == 0, "flare unregister retained heap work")
scheduler.Disable()
print("ACE flare scheduler LuaJIT self-test: PASS")
