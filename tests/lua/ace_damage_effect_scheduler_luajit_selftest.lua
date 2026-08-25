local root = assert(arg[1], "usage: ace_damage_effect_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
function CurTime() return now end

hook = { Add = function() end, Remove = function() end }
local timers = {}
timer = {
	Create = function(name, _, _, callback) timers[name] = callback end,
	Remove = function(name) timers[name] = nil end,
}

vector_up = setmetatable({}, { __unm = function(value) return value end })
local effects = {}
util = { Effect = function(name, flash) effects[#effects + 1] = { name = name, flash = flash } end }

function EffectData()
	return {
		SetAttachment = function(self, value) self.attachment = value end,
		SetOrigin = function(self, value) self.origin = value end,
		SetNormal = function(self, value) self.normal = value end,
		SetRadius = function(self, value) self.radius = value end,
	}
end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_damage_effect_scheduler.lua")
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
	ACE.DamageDetonationEffectSchedulerState.Records = {}
	ACE.DamageDetonationEffectSchedulerState.NextId = 0
end

local function assertEffect(index, origin, radius)
	local effect = effects[index]
	assert(effect and effect.name == "ACE_Scaled_Detonation", "wrong or missing detonation effect")
	assert(effect.flash.attachment == 1 and effect.flash.origin == origin, "effect origin/attachment changed")
	assert(effect.flash.radius == radius, "effect radius changed")
end

reset()
local fallbackOrigin = { id = "fallback" }
assert(ACE.ScheduleDamageDetonationEffect(fallbackOrigin, 0, 0.001), "fallback request was rejected")
local _, fallbackCallback = next(timers)
assert(fallbackCallback and scheduler.GetSize() == 0, "disabled request did not use fallback timer")
now = 0.001
fallbackCallback()
assertEffect(1, fallbackOrigin, 1)

reset()
assert(scheduler.Enable(), "scheduler did not enable")
local firstOrigin = { id = "first" }
local secondOrigin = { id = "second" }
now = 10
assert(ACE.ScheduleDamageDetonationEffect(firstOrigin, 2, 0.001), "first heap request was rejected")
assert(ACE.ScheduleDamageDetonationEffect(secondOrigin, 3, 0.002), "second heap request was rejected")
assert(next(timers) == nil and scheduler.GetSize() == 2, "independent effects were coalesced")
assert(scheduler.Run(10.0009).Ran == 0 and #effects == 0, "heap effect ran early")
assert(scheduler.Run(10.001).Ran == 1 and #effects == 1, "first heap effect did not emit")
assertEffect(1, firstOrigin, 2)
assert(scheduler.Run(10.002).Ran == 1 and #effects == 2, "second heap effect did not emit")
assertEffect(2, secondOrigin, 3)

reset()
assert(scheduler.Enable(), "scheduler did not re-enable")
local reloadOrigin = { id = "reload" }
now = 20
assert(ACE.ScheduleDamageDetonationEffect(reloadOrigin, 4, 1), "reload request was rejected")
dofile(root .. "/lua/ace/server/sv_ace_damage_effect_scheduler.lua")
assert(scheduler.GetSize() == 1 and next(timers) == nil, "reload did not restore pending heap effect")
assert(scheduler.Run(21).Ran == 1, "reloaded detonation effect did not run")
assertEffect(1, reloadOrigin, 4)

local disableOrigin = { id = "disable" }
now = 30
assert(ACE.ScheduleDamageDetonationEffect(disableOrigin, 5, 1), "disable request was rejected")
assert(scheduler.Disable(), "scheduler did not disable")
local _, disableCallback = next(timers)
assert(disableCallback, "disable did not restore timer fallback")
now = 31
disableCallback()
assertEffect(2, disableOrigin, 5)

print("ACE damage detonation effect scheduler LuaJIT self-test: PASS")
