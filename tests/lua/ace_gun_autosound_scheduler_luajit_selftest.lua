local root = assert(arg[1], "usage: ace_gun_autosound_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
function CurTime() return now end

hook = {
	Add = function() end,
	Remove = function() end,
}

local timers = {}
timer = {
	Create = function(name, _, _, callback) timers[name] = callback end,
	Remove = function(name) timers[name] = nil end,
}

local function makeGun()
	return {
		valid = true,
		AutoSound = "ace/test.wav",
		sounds = {},
		EmitSound = function(self, sound, level, pitch)
			table.insert(self.sounds, { sound, level, pitch })
		end,
	}
end

function IsValid(gun) return gun and gun.valid == true end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_gun_autosound_scheduler.lua")
local scheduler = ACE.Scheduler

local function clearTimers()
	for name in pairs(timers) do timers[name] = nil end
end

local function reset()
	if scheduler.Enabled then scheduler.Disable() end
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	scheduler.LastStats = {}
	clearTimers()
	ACE.GunAutoSoundSchedulerState.Records = {}
	ACE.GunAutoSoundSchedulerState.NextId = 0
end

reset()
local fallbackGun = makeGun()
now = 0
assert(ACE.ScheduleGunAutoSound(fallbackGun, 0.6), "fallback request was rejected")
local fallbackName, fallbackCallback = next(timers)
assert(fallbackName and scheduler.GetSize() == 0, "disabled request did not use fallback timer")
now = 0.6
fallbackCallback()
assert(#fallbackGun.sounds == 1 and fallbackGun.sounds[1][1] == "ace/test.wav", "fallback sound did not emit")
assert(fallbackGun.sounds[1][2] == 73 and fallbackGun.sounds[1][3] >= 84 and fallbackGun.sounds[1][3] <= 86, "fallback sound arguments changed")

reset()
assert(scheduler.Enable(), "scheduler did not enable")
local heapGun = makeGun()
now = 10
assert(ACE.ScheduleGunAutoSound(heapGun, 0.6), "first heap request was rejected")
assert(ACE.ScheduleGunAutoSound(heapGun, 0.7), "second heap request was rejected")
assert(next(timers) == nil and scheduler.GetSize() == 2, "independent shots were coalesced")
assert(scheduler.Run(10.59).Ran == 0 and #heapGun.sounds == 0, "heap sound ran early")
assert(scheduler.Run(10.6).Ran == 1 and #heapGun.sounds == 1, "first heap sound did not emit")
assert(scheduler.Run(10.7).Ran == 1 and #heapGun.sounds == 2, "second heap sound did not emit")

local invalidGun = makeGun()
invalidGun.valid = false
assert(scheduler.Run(20).Ran == 0, "empty scheduler dispatched unexpectedly")
assert(not ACE.ScheduleGunAutoSound(invalidGun, 1), "invalid gun was accepted")
assert(not ACE.ScheduleGunAutoSound(heapGun, math.huge), "infinite delay was accepted")

local removedBeforeDelivery = makeGun()
now = 40
assert(ACE.ScheduleGunAutoSound(removedBeforeDelivery, 1), "lifecycle request was rejected")
removedBeforeDelivery.valid = false
assert(scheduler.Run(41).Ran == 1 and #removedBeforeDelivery.sounds == 0, "invalidated gun still emitted")

local reloadGun = makeGun()
now = 50
assert(ACE.ScheduleGunAutoSound(reloadGun, 0.5), "reload request was rejected")
reloadGun.valid = false
dofile(root .. "/lua/ace/server/sv_ace_gun_autosound_scheduler.lua")
assert(scheduler.GetSize() == 0 and #reloadGun.sounds == 0, "reload left invalid pending heap sound")

local reloadedGun = makeGun()
now = 55
assert(ACE.ScheduleGunAutoSound(reloadedGun, 0.5), "post-reload request was rejected")
assert(scheduler.GetSize() == 1, "post-reload request did not use heap")
assert(scheduler.Run(55.5).Ran == 1 and #reloadedGun.sounds == 1, "reloaded adapter did not preserve pending sound")

reset()
assert(scheduler.Enable(), "scheduler did not re-enable")
local toggledGun = makeGun()
now = 30
assert(ACE.ScheduleGunAutoSound(toggledGun, 1), "toggle request was rejected")
assert(scheduler.Disable(), "scheduler did not disable")
assert(scheduler.GetSize() == 0 and next(timers) ~= nil, "disable did not restore fallback")
local _, toggleCallback = next(timers)
now = 31
toggleCallback()
assert(#toggledGun.sounds == 1, "fallback after disable did not emit")

reset()
print("ACE gun auto-sound scheduler LuaJIT self-test: PASS")
