local root = assert(arg[1], "usage: ace_vheat_source_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
function CurTime() return now end
engine = { TickInterval = function() return 0.015 end }
math.Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end

hook = { Handlers = {}, Add = function(name, id, callback)
	hook.Handlers[name] = hook.Handlers[name] or {}
	hook.Handlers[name][id] = callback
end, Remove = function(name, id)
	if hook.Handlers[name] then hook.Handlers[name][id] = nil end
end }

timer = { Remove = function() end }
local entities = {}
ents = { FindByClass = function() return entities end }
local trace = {}
WireLib = { Outputs = {}, TriggerOutput = function(ent, name, value)
	WireLib.Outputs[#WireLib.Outputs + 1] = { ent = ent, name = name, value = value, at = now }
	trace[#trace + 1] = "wire:" .. ent.Id
end }

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_vheat_source_scheduler.lua")

ACE.AmbientTemp = 20
local function makeEntity(id, active, heat, maxTemperature, heating, cooling)
	local ent = {
		Valid = true, Id = id, ThinkDelay = 0.1, Active = active, Heat = heat,
		MaxTemperature = maxTemperature, HeatingRate = heating, CoolingRate = cooling,
		OverlayUpdates = 0, NextThinkAt = nil,
	}
	function ent:UpdateOverlayText() self.OverlayUpdates = self.OverlayUpdates + 1 trace[#trace + 1] = "overlay:" .. self.Id end
	function ent:NextThink(at) self.NextThinkAt = at end
	return ent
end
function IsValid(ent) return ent and ent.Valid == true end

local first = makeEntity("first", true, 20, 25, 100, 5)
local second = makeEntity("second", false, 20.5, 21, 100, 5)
entities = { first, second }
local scheduler = ACE.Scheduler
assert(scheduler.Enable(), "scheduler did not enable")
local state = ACE.VHeatSourceSchedulerState
assert(state.Records[first] and state.Records[second], "entities were not registered on enable")
assert(first.ACE_VHeatSourceSchedulerOwned and second.ACE_VHeatSourceSchedulerOwned, "ownership was not claimed")

now = 0.1
assert(scheduler.Run(now).Ran == 2, "two independent updates did not run")
assert(first.Heat == 25 and second.Heat == 21, "fixed-step heat parity or clamp failed: " .. tostring(first.Heat) .. "," .. tostring(second.Heat))
assert(#WireLib.Outputs == 2 and first.OverlayUpdates == 1 and second.OverlayUpdates == 1, "output/overlay sequence failed")
assert((trace[1] == "wire:first" and trace[2] == "overlay:first" and trace[3] == "wire:second" and trace[4] == "overlay:second")
		or (trace[1] == "wire:second" and trace[2] == "overlay:second" and trace[3] == "wire:first" and trace[4] == "overlay:first"), "Wire/overlay order failed: " .. table.concat(trace, ","))
assert(scheduler.GetNode(state.Records[first].Key) and scheduler.GetNode(state.Records[second].Key), "recurring nodes were not retained")

local firstRecord = state.Records[first]
local firstTokenBeforeReload = firstRecord.Token
local secondRecord = state.Records[second]
assert(scheduler.Disable(), "scheduler did not disable")
assert(not first.ACE_VHeatSourceSchedulerOwned and not second.ACE_VHeatSourceSchedulerOwned, "disable retained engine ownership")
assert(scheduler.GetNode(firstRecord.Key) == nil and scheduler.GetNode(secondRecord.Key) == nil, "disable stranded heap nodes")
assert(first.NextThinkAt == 0.2 and second.NextThinkAt == 0.2, "disable did not preserve pending due time")

now = 0.2
ACE.UpdateVHeatSource(first)
ACE.MarkVHeatSourceFallback(first, now)
first:NextThink(now + first.ThinkDelay)
assert(first.Heat == 25 and #WireLib.Outputs == 3, "fallback update changed fixed-step parity")

assert(scheduler.Enable(), "scheduler did not re-enable")
now = 0.2
assert(scheduler.Run(now).Ran == 1 and second.Heat == 21, "fallback phase was not preserved for second entity")
now = 0.301
local resumed = scheduler.Run(now)
assert(resumed.Ran == 2 and first.Heat == 25 and second.Heat == 21, "fallback phase was not preserved: ran=" .. tostring(resumed.Ran) .. ",heat=" .. tostring(first.Heat) .. "," .. tostring(second.Heat))

local late = makeEntity("late", true, 20, 30, 50, 5)
entities[#entities + 1] = late
ACE.RegisterVHeatSource(late)
local lateRecord = state.Records[late]
assert(lateRecord and math.abs(lateRecord.NextDue - (now + engine.TickInterval())) < 0.000001, "enabled spawn did not preserve first engine-tick phase")
now = now + engine.TickInterval()
assert(scheduler.Run(now).Ran == 1 and late.Heat == 25, "enabled spawn first update did not run at its phase")
late.Valid = false
local removeHook = hook.Handlers.EntityRemoved.ACE_VHeatSourceSchedulerEntityRemoved
removeHook(late)

local remove = hook.Handlers.EntityRemoved.ACE_VHeatSourceSchedulerEntityRemoved
assert(remove, "entity removal hook was not registered")
remove(second)
assert(state.Records[second] == nil and scheduler.GetNode(secondRecord.Key) == nil, "removal left stale state")
assert(state.Records[first] and scheduler.GetNode(firstRecord.Key), "removing one entity damaged the other")

dofile(root .. "/lua/ace/server/sv_ace_vheat_source_scheduler.lua")
assert(scheduler.GetNode(state.Records[first].Key), "enabled adapter reload stranded the live node")
assert(state.Records[first].Token > firstTokenBeforeReload, "reload did not invalidate the old callback")

scheduler.Disable()
print("ACE vheat source scheduler LuaJIT self-test: PASS")
