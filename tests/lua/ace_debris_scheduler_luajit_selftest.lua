local root = assert(arg[1], "usage: ace_debris_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local hookHandlers = {}
hook = {
	Add = function(name, identifier, callback)
		hookHandlers[name] = hookHandlers[name] or {}
		hookHandlers[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if hookHandlers[name] then hookHandlers[name][identifier] = nil end
	end,
}

local now = 0
function CurTime() return now end

local timers = {}
timer = {
	Create = function(name, _, _, callback) timers[name] = callback end,
	Remove = function(name) timers[name] = nil end,
}

local function makeEntity()
	return { valid = true, removed = 0, Remove = function(self) self.valid = false self.removed = self.removed + 1 end }
end

function IsValid(ent) return ent and ent.valid == true end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_debris_scheduler.lua")
local scheduler = ACE.Scheduler

local function reset()
	if scheduler.Enabled then scheduler.Disable() end
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	scheduler.LastStats = {}
	for key in pairs(timers) do timers[key] = nil end
	ACE.DebrisRemovalSchedulerState.Records = setmetatable({}, { __mode = "k" })
	ACE.DebrisRemovalSchedulerState.NextId = 0
end

reset()
local scheduled = makeEntity()
assert(ACE.ScheduleDebrisRemoval(scheduled, 5), "disabled scheduling was rejected")
assert(next(timers) ~= nil and scheduler.GetSize() == 0, "disabled scheduling did not use fallback timer")
local _, fallbackCallback = next(timers)
now = 5
fallbackCallback()
assert(scheduled.removed == 1 and not IsValid(scheduled), "fallback did not remove debris")

reset()
assert(scheduler.Enable(), "scheduler did not enable")
local heapEntity = makeEntity()
now = 0
assert(ACE.ScheduleDebrisRemoval(heapEntity, 5), "enabled scheduling was rejected")
assert(next(timers) == nil and scheduler.GetSize() == 1, "enabled scheduling did not use heap")
assert(scheduler.Run(4).Ran == 0 and heapEntity.removed == 0, "heap callback ran early")
assert(scheduler.Run(5).Ran == 1 and heapEntity.removed == 1, "heap callback did not remove debris")

local flare = makeEntity()
now = 10
assert(ACE.ScheduleEntityRemoval(flare, 2, "Flare"), "generic flare scheduling was rejected")
assert(scheduler.Run(11).Ran == 0 and flare.removed == 0, "flare callback ran early")
assert(scheduler.Run(12).Ran == 1 and flare.removed == 1, "generic flare callback did not remove entity")

local toggled = makeEntity()
now = 10
assert(ACE.ScheduleDebrisRemoval(toggled, 5), "toggle fixture was rejected")
assert(scheduler.Disable(), "scheduler did not disable")
assert(scheduler.GetSize() == 0 and next(timers) ~= nil, "disable did not restore fallback")
local _, toggleCallback = next(timers)
now = 15
toggleCallback()
assert(toggled.removed == 1, "fallback after disable did not remove debris")

reset()
assert(scheduler.Enable(), "scheduler did not re-enable")
local replaced = makeEntity()
now = 20
assert(ACE.ScheduleDebrisRemoval(replaced, 10), "replacement fixture was rejected")
assert(ACE.ScheduleDebrisRemoval(replaced, 2), "replacement request was rejected")
assert(scheduler.GetSize() == 1, "replacement left stale heap work")
assert(scheduler.Run(21).Ran == 0 and replaced.removed == 0, "replacement ran early")
assert(scheduler.Run(22).Ran == 1 and replaced.removed == 1, "replacement did not use new due time")

local canceled = makeEntity()
assert(ACE.ScheduleDebrisRemoval(canceled, 1), "cancel fixture was rejected")
ACE.UnregisterDebrisRemoval(canceled)
assert(scheduler.GetSize() == 0, "unregister left heap work")
assert(scheduler.Run(100).Ran == 0 and canceled.removed == 0, "unregister did not cancel removal")
assert(not ACE.ScheduleDebrisRemoval(canceled, math.huge), "infinite delay was accepted")

scheduler.Disable()
print("ACE debris scheduler LuaJIT self-test: PASS")
