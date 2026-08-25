local root = assert(arg[1], "usage: ace_scalability_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
function CurTime() return now end
function IsValid(value) return value and value.Valid == true end
engine = { TickInterval = function() return 0.015 end }

local timers = {}
timer = {
	Create = function(name, _, _, callback) timers[name] = callback end,
	Remove = function(name) timers[name] = nil end,
	Run = function(name)
		local callback = assert(timers[name], "missing timer " .. name)
		timers[name] = nil
		callback()
	end,
}

hook = {
	Handlers = {},
	Add = function(name, identifier, callback)
		hook.Handlers[name] = hook.Handlers[name] or {}
		hook.Handlers[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if hook.Handlers[name] then hook.Handlers[name][identifier] = nil end
	end,
}

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_scalability_scheduler.lua")

local scheduler = ACE.Scheduler
local state = ACE.ScalableResyncSchedulerState
local sent = {}
ACE.NetworkScalableScale = function(entity, _, player)
	sent[#sent + 1] = { entity = entity, player = player, now = now }
end

local function player()
	return { Valid = true }
end

local function entity(id)
	return { Valid = true, IsScalable = true, Id = id, ScaleData = { Scale = {} } }
end

local first = entity("first")
local second = entity("second")
local third = entity("third")
ACE.ScalableEnts = { first, second, third }
local one = player()
local two = player()

assert(scheduler.Enable(), "scheduler did not enable")
assert(ACE.ScheduleScalableResync(one), "first resync was not scheduled")
local firstJob = state.Jobs[one]
assert(firstJob and firstJob.Cursor == 3, "legacy reverse-order cursor was not initialized")

now = 0.015
assert(scheduler.Run(now).Ran == 1 and sent[1].entity == third and sent[1].player == one, "first heap send was wrong")
now = 0.030
assert(scheduler.Run(now).Ran == 1 and sent[2].entity == second, "second heap send was wrong")

local requestEntities = firstJob.Entities
ACE.ScalableEnts = { entity("replacement") }
requestEntities[3] = nil
assert(firstJob.Entities == requestEntities and firstJob.Entities ~= ACE.ScalableEnts, "request did not retain the legacy table reference")
now = 0.045
assert(scheduler.Run(now).Ran == 1 and sent[3].entity == first, "live scalable table mutation changed legacy ordering")

ACE.ScalableEnts = { first, second, third }
assert(ACE.ScheduleScalableResync(two), "second-player resync was not scheduled")
local twoJob = state.Jobs[two]
assert(twoJob and twoJob.Key ~= firstJob.Key, "players did not receive independent keys")
assert(ACE.ScheduleScalableResync(one), "replacement resync was not scheduled")
assert(state.Jobs[one] ~= firstJob and scheduler.GetNode(firstJob.Key) == nil, "replacement stranded the old job")

assert(scheduler.Disable(), "scheduler did not disable")
assert(not scheduler.GetNode(twoJob.Key), "disable left a heap job attached")
assert(timers["ACE_ScalableResync_" .. twoJob.Id], "disable did not install timer fallback")
assert(ACE.ScheduleScalableResync(two), "fallback replacement resync was not scheduled")
local replacementJob = state.Jobs[two]
assert(replacementJob ~= twoJob and not timers["ACE_ScalableResync_" .. twoJob.Id], "fallback replacement stranded the old timer")
now = 1
timer.Run("ACE_ScalableResync_" .. replacementJob.Id)
assert(sent[#sent].player == two, "fallback sent to the wrong player")

ACE.ScalableEnts = { first, second }
assert(scheduler.Enable(), "scheduler did not enable before reload")
assert(ACE.ScheduleScalableResync(one), "reload setup resync was not scheduled")
local reloadJob = state.Jobs[one]
assert(reloadJob, "reload setup job was not retained")
ACE.ScalableEnts = { third }
dofile(root .. "/lua/ace/server/sv_ace_scalability_scheduler.lua")
assert(ACE.ScalableResyncSchedulerState.Jobs[one] == nil, "reload retained an outstanding job")
assert(ACE.ScalableResyncSchedulerState.Jobs[two] == nil, "enabled reload retained the other outstanding job")

local disconnect = hook.Handlers.PlayerDisconnected.ACE_ScalableResyncDisconnect
assert(disconnect, "disconnect cleanup hook was not registered")
disconnect(one)
assert(state.Jobs[one] == nil, "disconnect retained the player's job")

assert(scheduler.Enabled, "scheduler was not still enabled after reload")
disconnect(two)
assert(ACE.ScalableResyncSchedulerState.Jobs[two] == nil and next(timers) == nil, "disconnect left a stale timer or job")
assert(scheduler.Disable(), "final scheduler disable failed")
print("ACE scalability scheduler LuaJIT self-test: PASS")
