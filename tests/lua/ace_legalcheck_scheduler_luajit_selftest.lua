local root = assert(arg[1], "usage: ace_legalcheck_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
local timerCallbacks = {}
timer = {
	Simple = function(delay, callback)
		timerCallbacks[#timerCallbacks + 1] = { delay = delay, callback = callback }
	end,
}
function CurTime() return now end
function IsValid(ent) return ent and ent.valid == true end

hook = {
	Add = function() end,
	Remove = function() end,
}

ACE = {}
dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local firstScheduler = ACE.Scheduler
firstScheduler.Disable()

ACE.Scheduler = nil
ACE.SchedulerAdapterDefinitions = {}
dofile(root .. "/lua/ace/server/sv_ace_legalcheck.lua")
assert(ACE.SchedulerAdapterDefinitions["ACE.ContraptionLegalCheck"], "legality adapter was not queued")

local ent = { valid = true, CanLegalCheck = false }
ACE.ScheduleLegalCheckReset(ent, 3)
assert(#timerCallbacks == 1 and timerCallbacks[1].delay == 3, "disabled legality cooldown did not retain timer fallback")

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local scheduler = ACE.Scheduler
assert(scheduler.Adapters["ACE.ContraptionLegalCheck"], "legality adapter was not registered")
assert(scheduler.Enable(), "scheduler did not enable")
local node = scheduler.Heap[1]
assert(node and scheduler.GetNode(node.Key), "legality cooldown was not attached to heap")
timerCallbacks[1].callback()
assert(not ent.CanLegalCheck and scheduler.GetNode(node.Key), "stale pre-enable timer stole heap ownership")
now = node.Due
scheduler.Run(now)
assert(ent.CanLegalCheck and next(ACE.ContraptionLegalCheckState.Pending) == nil, "scheduled legality cooldown did not finish")

ent.CanLegalCheck = false
ACE.ScheduleLegalCheckReset(ent, 2)
local replacement = scheduler.Heap[1]
assert(replacement, "enabled legality cooldown was not attached")
dofile(root .. "/lua/ace/server/sv_ace_legalcheck.lua")
replacement = scheduler.Heap[1]
assert(replacement, "legality cooldown was not replaced on reload")
now = replacement.Due
scheduler.Run(now)
assert(ent.CanLegalCheck, "reloaded legality cooldown did not finish")

ent.CanLegalCheck = false
ACE.ScheduleLegalCheckReset(ent, 4)
local disabledNode = scheduler.Heap[1]
assert(disabledNode, "legality cooldown was not attached before disable")
assert(scheduler.Disable(), "scheduler did not disable")
assert(scheduler.GetNode(disabledNode.Key) == nil, "legality cooldown node remained after disable")
assert(#timerCallbacks == 2 and timerCallbacks[2].delay == 4, "disable did not restore legality timer fallback")
assert(scheduler.Enable(), "scheduler did not re-enable after disable")
local reenabled = scheduler.Heap[1]
timerCallbacks[2].callback()
assert(not ent.CanLegalCheck and scheduler.GetNode(reenabled.Key), "stale post-disable timer stole heap ownership")
now = reenabled.Due
scheduler.Run(now)
assert(ent.CanLegalCheck, "re-enabled legality cooldown did not finish")
assert(scheduler.Disable(), "scheduler did not disable after stale-timer check")
timerCallbacks[2].callback()
assert(ent.CanLegalCheck, "current legality state was changed by stale timer")

ent.CanLegalCheck = false
ACE.ScheduleLegalCheckReset(ent, 3)
assert(#timerCallbacks == 3 and timerCallbacks[3].delay == 3, "disabled reload case did not retain timer fallback")
dofile(root .. "/lua/ace/server/sv_ace_legalcheck.lua")
assert(scheduler.Enable(), "scheduler did not enable after disabled reload")
local reloadNode = scheduler.Heap[1]
assert(reloadNode, "disabled reload case did not attach a heap node")
timerCallbacks[3].callback()
assert(not ent.CanLegalCheck and scheduler.GetNode(reloadNode.Key), "disabled-reload stale timer stole heap ownership")
now = reloadNode.Due
scheduler.Run(now)
assert(ent.CanLegalCheck, "disabled-reload legality cooldown did not finish")
assert(scheduler.Disable(), "scheduler did not disable after disabled reload case")

local removed = { valid = false, CanLegalCheck = false }
ACE.ScheduleLegalCheckReset(removed, 1)
timerCallbacks[4].callback()
assert(not removed.CanLegalCheck, "invalid entity received a legality cooldown reset")

print("ACE legality scheduler LuaJIT self-test: PASS")
