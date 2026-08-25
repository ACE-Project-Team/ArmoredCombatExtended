local root = assert(arg[1], "usage: ace_ammo_cookoff_scheduler_luajit_selftest.lua <ACE repo>")
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

vector_up = setmetatable({}, { __unm = function(value) return value end })
local effects = {}
util = {
	Effect = function(name, flash) effects[#effects + 1] = { name = name, flash = flash } end,
}

function EffectData()
	return {
		SetOrigin = function(self, value) self.origin = value end,
		SetNormal = function(self, value) self.normal = value end,
		SetRadius = function(self, value) self.radius = value end,
	}
end

local function makeAmmo()
	return { valid = true, BulletData = { Pos = "initial" } }
end

local function makeGun()
	return {
		valid = true,
		AutoSound = "ace/test.wav",
		sounds = {},
		EmitSound = function(self, sound, level, pitch)
			self.sounds[#self.sounds + 1] = { sound, level, pitch }
		end,
	}
end

function IsValid(ammo) return ammo and ammo.valid == true end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua")
local scheduler = ACE.Scheduler

local function reset()
	if scheduler.Enabled then scheduler.Disable() end
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	scheduler.LastStats = {}
	for name in pairs(timers) do timers[name] = nil end
	for index = #effects, 1, -1 do effects[index] = nil end
	ACE.AmmoCookoffFlashSchedulerState.Records = {}
	ACE.AmmoCookoffFlashSchedulerState.NextId = 0
end

reset()
local fallbackAmmo = makeAmmo()
now = 0
assert(ACE.ScheduleAmmoCookoffFlash(fallbackAmmo, 0.001, 4), "fallback request was rejected")
local _, fallbackCallback = next(timers)
assert(fallbackCallback and scheduler.GetSize() == 0, "disabled request did not use fallback timer")
fallbackAmmo.BulletData.Pos = "fallback-pos"
now = 0.001
fallbackCallback()
assert(#effects == 1 and effects[1].name == "ACE_Scaled_Explosion", "fallback effect did not emit")
assert(effects[1].flash.origin == "fallback-pos" and effects[1].flash.radius == 4, "fallback effect arguments changed")

reset()
assert(scheduler.Enable(), "scheduler did not enable")
local heapAmmo = makeAmmo()
now = 10
assert(ACE.ScheduleAmmoCookoffFlash(heapAmmo, 0.001, 2), "first heap request was rejected")
assert(ACE.ScheduleAmmoCookoffFlash(heapAmmo, 0.002, 3), "second heap request was rejected")
assert(next(timers) == nil and scheduler.GetSize() == 2, "independent effects were coalesced")
assert(scheduler.Run(10.0009).Ran == 0 and #effects == 0, "heap effect ran early")
heapAmmo.BulletData.Pos = "heap-pos"
assert(scheduler.Run(10.001).Ran == 1 and #effects == 1 and effects[1].flash.radius == 2 and effects[1].flash.origin == "heap-pos", "first heap effect did not preserve dynamic position")
assert(scheduler.Run(10.002).Ran == 1 and #effects == 2 and effects[2].flash.radius == 3, "second heap effect did not emit")

local invalidAmmo = makeAmmo()
now = 20
assert(ACE.ScheduleAmmoCookoffFlash(invalidAmmo, 1, 2), "lifecycle request was rejected")
invalidAmmo.valid = false
assert(scheduler.Run(21).Ran == 1 and #effects == 2, "invalidated ammo still emitted")

local reloadAmmo = makeAmmo()
now = 30
assert(ACE.ScheduleAmmoCookoffFlash(reloadAmmo, 1, 5), "reload request was rejected")
reloadAmmo.valid = false
dofile(root .. "/lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua")
assert(scheduler.GetSize() == 0, "reload left invalid pending effect")

local toggledAmmo = makeAmmo()
now = 40
assert(ACE.ScheduleAmmoCookoffFlash(toggledAmmo, 1, 6), "toggle request was rejected")
assert(scheduler.Disable(), "scheduler did not disable")
local _, toggleCallback = next(timers)
now = 41
toggleCallback()
assert(#effects == 3 and effects[3].flash.radius == 6, "fallback after disable did not emit")

assert(scheduler.Enable(), "scheduler did not re-enable for combined cleanup")
dofile(root .. "/lua/ace/server/sv_ace_gun_autosound_scheduler.lua")
local combinedAmmo = makeAmmo()
local combinedGun = makeGun()
now = 50
assert(ACE.ScheduleAmmoCookoffFlash(combinedAmmo, 1, 7), "combined ammo request was rejected")
assert(ACE.ScheduleGunAutoSound(combinedGun, 1), "combined gun request was rejected")
combinedAmmo.valid = false
dofile(root .. "/lua/ace/server/sv_ace_ammo_cookoff_scheduler.lua")
assert(scheduler.GetSize() == 1, "ammo reload disturbed the gun heap record")
assert(scheduler.Run(51).Ran == 1 and #combinedGun.sounds == 1 and #effects == 3, "combined cleanup did not isolate adapters")

local reverseAmmo = makeAmmo()
local reverseGun = makeGun()
now = 60
assert(ACE.ScheduleAmmoCookoffFlash(reverseAmmo, 1, 8), "reverse ammo request was rejected")
assert(ACE.ScheduleGunAutoSound(reverseGun, 1), "reverse gun request was rejected")
reverseGun.valid = false
dofile(root .. "/lua/ace/server/sv_ace_gun_autosound_scheduler.lua")
assert(scheduler.GetSize() == 1, "gun reload disturbed the ammo heap record")
assert(scheduler.Run(61).Ran == 1 and #effects == 4 and #reverseGun.sounds == 0, "reverse cleanup did not isolate adapters")

reset()
print("ACE ammo cookoff scheduler LuaJIT self-test: PASS")
