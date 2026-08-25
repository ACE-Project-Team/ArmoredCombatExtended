local root = assert(arg[1], "usage: ace_gforce_meter_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
function CurTime() return now end
engine = { TickInterval = function() return 0.015 end }

hook = { Handlers = {}, Add = function(name, id, callback)
	hook.Handlers[name] = hook.Handlers[name] or {}
	hook.Handlers[name][id] = callback
end, Remove = function(name, id)
	if hook.Handlers[name] then hook.Handlers[name][id] = nil end
end }
WireLib = {}
ents = { FindByClass = function() return {} end }
function IsValid(ent) return ent and ent.Valid == true end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_gforce_meter_scheduler.lua")

local function makeEntity(id)
	local ent = { Id = id, Valid = true, ThinkDelay = 0.05, NextThinkAt = nil, Trace = {}, Updates = 0 }
	function ent:CalculateGForce() self.Updates = self.Updates + 1; self.Trace[#self.Trace + 1] = "calculate" end
	function ent:UpdateOutputs() self.Trace[#self.Trace + 1] = "outputs" end
	function ent:UpdateOverlayText() self.Trace[#self.Trace + 1] = "overlay" end
	function ent:NextThink(at) self.NextThinkAt = at end
	return ent
end

local scheduler = ACE.Scheduler
local first = makeEntity("first")
local second = makeEntity("second")
local entities = { first, second }
ents.FindByClass = function() return entities end
assert(scheduler.Enable(), "scheduler did not enable")
local state = ACE.GForceMeterSchedulerState
assert(state.Records[first] and state.Records[second], "meters were not registered")
assert(first.ACE_GForceMeterSchedulerOwned and second.ACE_GForceMeterSchedulerOwned, "ownership was not claimed")

now = 0.05
assert(scheduler.Run(now).Ran == 2, "independent updates did not run")
assert(first.Updates == 1 and first.Trace[1] == "calculate" and first.Trace[3] == "overlay", "update ordering failed")
assert(scheduler.GetNode(state.Records[first].Key), "recurring node was not retained")

local firstRecord = state.Records[first]
assert(scheduler.Disable(), "scheduler did not disable")
assert(not first.ACE_GForceMeterSchedulerOwned and scheduler.GetNode(firstRecord.Key) == nil, "disable stranded ownership")
assert(first.NextThinkAt == 0.1, "disable did not preserve next due")

ACE.UpdateGForceMeter(first)
ACE.MarkGForceMeterFallback(first, now)
first:NextThink(now + first.ThinkDelay)
assert(first.Updates == 2, "fallback update did not execute")
assert(scheduler.Enable(), "scheduler did not re-enable")
now = 0.1
assert(scheduler.Run(now).Ran == 2, "fallback phase did not resume")

local late = makeEntity("late")
entities[#entities + 1] = late
ACE.RegisterGForceMeter(late)
assert(math.abs(state.Records[late].NextDue - (now + engine.TickInterval())) < 0.000001, "spawn phase was not tick-aligned")
now = now + engine.TickInterval()
assert(scheduler.Run(now).Ran == 1 and late.Updates == 1, "spawn phase did not dispatch")

local remove = hook.Handlers.EntityRemoved.ACE_GForceMeterSchedulerEntityRemoved
remove(second)
assert(state.Records[second] == nil, "removal retained record")
assert(state.Records[first] and scheduler.GetNode(firstRecord.Key), "removal damaged another meter")

dofile(root .. "/lua/ace/server/sv_ace_gforce_meter_scheduler.lua")
assert(scheduler.GetNode(state.Records[first].Key), "reload stranded live node")
scheduler.Disable()
print("ACE g-force meter scheduler LuaJIT self-test: PASS")
