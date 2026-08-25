local root = assert(arg[1], "usage: ace_sonar_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
function CurTime() return now end
function IsValid(entity) return entity and entity.valid == true end
function Color(r, g, b, a) return { r, g, b, a } end

hook = { Add = function() end, Remove = function() end }
local timers = {}
timer = {
	Create = function(name, _, _, callback) timers[name] = callback end,
	Remove = function(name) timers[name] = nil end,
}

debugoverlay = { lines = {}, Line = function(...) table.insert(debugoverlay.lines, {...}) end }

local function makeBase()
	return {
		valid = true,
		sounds = {},
		IsMarkedForDeletion = function() return false end,
		EmitSound = function(self, sound, level, pitch, volume, channel)
			table.insert(self.sounds, { sound, level, pitch, volume, channel })
		end,
	}
end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_sonar_scheduler.lua")
local scheduler = ACE.Scheduler

local function reset()
	if scheduler.Enabled then scheduler.Disable() end
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	for name in pairs(timers) do timers[name] = nil end
	for index = #debugoverlay.lines, 1, -1 do debugoverlay.lines[index] = nil end
	ACE.SonarTravelSoundSchedulerState.Records = {}
	ACE.SonarTravelSoundSchedulerState.NextId = 0
	ACE.SonarPingExpirySchedulerState.Records = {}
	ACE.SonarPingExpirySchedulerState.NextId = 0
end

reset()
local fallback = makeBase()
now = 0
assert(ACE.ScheduleSonarTravelSound(fallback, 0.6, "self", "base", "sonar.wav", 101, 0.75), "fallback request rejected")
local _, fallbackCallback = next(timers)
assert(fallbackCallback and scheduler.GetSize() == 0, "disabled request did not use timer fallback")
now = 0.6
fallbackCallback()
assert(#fallback.sounds == 1 and fallback.sounds[1][1] == "sonar.wav", "fallback sound did not emit")
assert(fallback.sounds[1][2] == 130 and fallback.sounds[1][3] == 101 and fallback.sounds[1][4] == 0.75, "fallback sound arguments changed")

reset()
assert(scheduler.Enable(), "scheduler did not enable")
local heapBase = makeBase()
now = 10
assert(ACE.ScheduleSonarTravelSound(heapBase, 0.6, "self-a", "base-a", "a.wav", 90, 0.4), "first heap request rejected")
assert(ACE.ScheduleSonarTravelSound(heapBase, 0.7, "self-b", "base-b", "b.wav", 110, 0.8, 100, "auto", "return-color", 0.35), "second heap request rejected")
assert(next(timers) == nil and scheduler.GetSize() == 2, "independent sounds were coalesced")
assert(scheduler.Run(10.59).Ran == 0 and #heapBase.sounds == 0, "heap sound ran early")
assert(scheduler.Run(10.6).Ran == 1 and #heapBase.sounds == 1, "first heap sound did not emit")
assert(heapBase.sounds[1][1] == "a.wav" and #debugoverlay.lines == 1, "first heap arguments or debug line changed")
assert(scheduler.Run(10.7).Ran == 1 and #heapBase.sounds == 2, "second heap sound did not emit")
assert(heapBase.sounds[2][2] == 100 and heapBase.sounds[2][3] == 110 and heapBase.sounds[2][4] == 0.8 and heapBase.sounds[2][5] == "auto", "second heap sound arguments changed")

local invalid = makeBase()
invalid.valid = false
assert(not ACE.ScheduleSonarTravelSound(invalid, 1, "x", "y", "x.wav", 100, 1), "invalid base was accepted")
local removed = makeBase()
now = 20
assert(ACE.ScheduleSonarTravelSound(removed, 1, "x", "y", "x.wav", 100, 1), "lifecycle request rejected")
removed.valid = false
assert(scheduler.Run(21).Ran == 1 and #removed.sounds == 0, "invalidated base still emitted")

local reload = makeBase()
now = 30
assert(ACE.ScheduleSonarTravelSound(reload, 1, "x", "y", "x.wav", 100, 1), "reload request rejected")
reload.valid = false
dofile(root .. "/lua/ace/server/sv_ace_sonar_scheduler.lua")
assert(scheduler.GetSize() == 0, "reload left invalid sound record")

local toggled = makeBase()
now = 40
assert(ACE.ScheduleSonarTravelSound(toggled, 1, "x", "y", "x.wav", 100, 1), "toggle request rejected")
assert(scheduler.Disable(), "scheduler did not disable")
assert(scheduler.GetSize() == 0 and next(timers) ~= nil, "disable did not restore fallback")
local _, toggleCallback = next(timers)
now = 41
toggleCallback()
assert(#toggled.sounds == 1, "fallback after disable did not emit")

reset()
local pingBase = makeBase()
local pingContraption = {
	SonarPings = { [7] = { Time = 5 } },
	GetACEBaseplate = function(self) return self.base end,
	base = pingBase,
}
now = 0
assert(ACE.ScheduleSonarPingExpiry(pingContraption, 7, 6), "fallback ping expiry was rejected")
assert(scheduler.GetSize() == 0 and next(timers) ~= nil, "disabled ping expiry did not use timer fallback")
local _, pingFallback = next(timers)
now = 6
ACE.CurTime = now
pingFallback()
assert(pingContraption.SonarPings[7] == nil, "fallback ping expiry did not clear stale cache")

reset()
assert(scheduler.Enable(), "scheduler did not enable for ping expiry")
pingContraption.SonarPings[7] = { Time = 5 }
now = 10
ACE.CurTime = now
assert(ACE.ScheduleSonarPingExpiry(pingContraption, 7, 6), "heap ping expiry was rejected")
local firstPingRecord = ACE.SonarPingExpirySchedulerState.Records[pingContraption][7]
now = 10.5
ACE.CurTime = now
assert(ACE.ScheduleSonarPingExpiry(pingContraption, 7, 6), "replacement ping expiry was rejected")
local record = ACE.SonarPingExpirySchedulerState.Records[pingContraption][7]
assert(record ~= firstPingRecord and math.abs(record.Due - 16.5) < 0.000001, "ping expiry did not retain the latest legacy timer")
assert(scheduler.GetSize() == 1, "ping expiry did not coalesce by contraption and ping id")
pingContraption.SonarPings[7].Time = 16.25
ACE.CurTime = 16
local pingStats = scheduler.Run(16)
assert(pingStats.Ran == 0 and pingContraption.SonarPings[7] ~= nil, "heap ping expiry ran before the refreshed timer")
ACE.CurTime = 16.5
pingStats = scheduler.Run(16.5)
assert(pingStats.Ran == 1 and pingContraption.SonarPings[7] == nil, "heap ping expiry did not clear stale cache")

local invalidPingContraption = { GetACEBaseplate = function() return nil end }
assert(not ACE.ScheduleSonarPingExpiry(invalidPingContraption, 8, 1), "invalid-base ping expiry was accepted")
assert(scheduler.GetSize() == 0 and next(ACE.SonarPingExpirySchedulerState.Records) == nil, "invalid-base ping expiry retained scheduler state")

reset()
print("ACE sonar scheduler LuaJIT self-test: PASS")
