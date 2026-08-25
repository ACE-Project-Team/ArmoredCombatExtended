local root = assert(arg[1], "usage: ace_wind_sensor_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local entitySource = assert(io.open(root .. "/lua/entities/ace_wind_sensor/init.lua", "r")):read("*a")
assert(entitySource:find("function ENT:OnRemove%(%).-%s+BaseClass%.OnRemove%(self%)"), "wind sensor removal does not preserve Wire base cleanup")
assert(entitySource:find("CallOnRemove%(%\"ACE_WindSensorScheduler\".-UnregisterWindSensor%(self%)"), "wind sensor removal hook does not capture the entity")

CLIENT = false
local now = 0
function CurTime() return now end
function IsValid(ent) return ent and ent.Valid == true end
local registeredHooks = {}
hook = {
	Add = function(name, identifier, callback)
		registeredHooks[name] = registeredHooks[name] or {}
		registeredHooks[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if registeredHooks[name] then registeredHooks[name][identifier] = nil end
	end,
}

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
dofile(root .. "/lua/ace/server/sv_ace_wind_sensor_scheduler.lua")
local scheduler = ACE.Scheduler
local state = ACE.WindSensorSchedulerState

local function makeSensor()
	return {
		Valid = true,
		ThinkDelay = 0.1,
		Updates = 0,
		NextThinkAt = nil,
		UpdateOutputs = function(self) self.Updates = self.Updates + 1 end,
		UpdateOverlayText = function() end,
		NextThink = function(self, due) self.NextThinkAt = due end,
	}
end

local first = makeSensor()
ACE.RegisterWindSensor(first)
assert(next(state.Records) == first, "wind sensor was not registered")
assert(scheduler.Enable(), "scheduler did not enable")
local firstRecord = state.Records[first]
assert(first.ACE_WindSensorSchedulerOwned and scheduler.GetNode(firstRecord.Key), "sensor did not attach")
assert(first.NextThinkAt == 3600, "engine fallback was not put to sleep")

now = 0.1
assert(scheduler.Run(now).Ran == 1 and first.Updates == 1, "scheduled sensor update did not run")
assert(scheduler.GetNode(firstRecord.Key).Due == 0.2, "sensor cadence was not rescheduled")

now = 0.15
assert(scheduler.Disable(), "scheduler did not disable")
assert(not first.ACE_WindSensorSchedulerOwned and not scheduler.GetNode(firstRecord.Key), "disable left sensor owned by heap")
assert(first.NextThinkAt == 0.2, "disable did not preserve the next fallback phase: " .. tostring(first.NextThinkAt))
now = 0.2
first:UpdateOutputs()
ACE.MarkWindSensorFallback(first, now)
assert(first.Updates == 2, "mid-period fallback update did not run exactly once")

assert(scheduler.Enable(), "scheduler did not re-enable")
assert(math.abs(scheduler.GetNode(firstRecord.Key).Due - 0.3) < 0.000001, "fallback phase was not preserved: " .. tostring(scheduler.GetNode(firstRecord.Key).Due))

local oldKey = firstRecord.Key
local oldNode = scheduler.GetNode(oldKey)
local oldCallback = oldNode.Callback
dofile(root .. "/lua/ace/server/sv_ace_wind_sensor_scheduler.lua")
state = ACE.WindSensorSchedulerState
assert(scheduler.GetNode(oldKey) ~= oldNode, "reload did not replace the old sensor node")
local reloadedRecord = state.Records[first]
assert(reloadedRecord and scheduler.GetNode(reloadedRecord.Key), "reload stranded the live sensor")
local updatesBeforeStaleCallback = first.Updates
oldCallback(oldKey, 0.3, 0.3)
assert(first.Updates == updatesBeforeStaleCallback, "stale reload callback updated the sensor")

first.Valid = false
assert(registeredHooks.EntityRemoved and registeredHooks.EntityRemoved.ACE_WindSensorSchedulerEntityRemoved, "wind sensor removal hook was not registered")
registeredHooks.EntityRemoved.ACE_WindSensorSchedulerEntityRemoved(first)
assert(not scheduler.GetNode(reloadedRecord.Key), "removed sensor retained a heap node")
assert(state.Records[first] == nil, "removed sensor retained scheduler state")

local replacement = makeSensor()
ACE.RegisterWindSensor(replacement)
local replacementRecord = state.Records[replacement]
assert(replacementRecord.Key ~= oldKey, "sensor key was reused across entity instances")
assert(scheduler.GetNode(replacementRecord.Key), "replacement sensor did not attach")

assert(scheduler.Disable(), "final scheduler disable failed")
print("ACE wind sensor scheduler LuaJIT self-test: PASS")
