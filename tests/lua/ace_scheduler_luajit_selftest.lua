local root = assert(arg[1], "usage: ace_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local hookHandlers = {}
local convars = {}
local convarCallbacks = {}
hook = {
	Add = function(name, identifier, callback)
		hookHandlers[name] = hookHandlers[name] or {}
		hookHandlers[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if hookHandlers[name] then hookHandlers[name][identifier] = nil end
	end,
}

cvars = {
	AddChangeCallback = function(name, callback, identifier)
		convarCallbacks[name] = { callback = callback, identifier = identifier }
	end,
	RemoveChangeCallback = function(name)
		convarCallbacks[name] = nil
	end,
}

function GetConVar(name) return convars[name] end
function CreateConVar(name)
	local convar = { value = "1", GetBool = function(self) return self.value ~= "0" end }
	convars[name] = convar
	return convar
end

function CurTime() return 0 end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local scheduler = ACE.Scheduler
assert(ACE.Scheduling == scheduler, "stable scheduling surface did not bind to the scheduler")

local function reset()
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	scheduler.Enabled = false
	scheduler.LastStats = {}
end

local function expectError(callback)
	local ok = pcall(callback)
	assert(not ok, "expected an error")
end

reset()
local order = {}
scheduler.Attach("a", function() order[#order + 1] = "a" end, 10)
scheduler.Attach("b", function() order[#order + 1] = "b" end, 10)
scheduler.Attach("c", function() order[#order + 1] = "c" end, 10)
local stats = scheduler.Run(10)
assert(table.concat(order) == "abc", "equal due times must preserve FIFO order")
assert(stats.Due == 3 and stats.Ran == 3 and scheduler.GetSize() == 0 and next(scheduler.Nodes) == nil, "basic dispatch stats mismatch")

reset()
local priorityOrder = {}
scheduler.Attach("normal", function() priorityOrder[#priorityOrder + 1] = "normal" end, 10)
scheduler.Attach("late", function() priorityOrder[#priorityOrder + 1] = "late" end, 10, { priority = 10 })
scheduler.Attach("early", function() priorityOrder[#priorityOrder + 1] = "early" end, 10, { priority = -10 })
scheduler.Attach("same-priority", function() priorityOrder[#priorityOrder + 1] = "same" end, 10, { priority = -10 })
assert(scheduler.Run(10).Ran == 4 and table.concat(priorityOrder) == "earlysamenormallate", "priority ordering did not preserve priority then FIFO")

reset()
local rescheduled = 0
scheduler.Attach("move", function()
	rescheduled = rescheduled + 1
	if rescheduled == 1 then scheduler.Reschedule("move", 30) end
end, 20)
scheduler.Attach("early", function() order[#order + 1] = "early" end, 30)
scheduler.Reschedule("early", 5)
assert(scheduler.Run(10).Ran == 1, "rescheduled heap node ran at the wrong time")
assert(rescheduled == 0, "future callback ran too early")
assert(scheduler.Run(20).Ran == 1 and rescheduled == 1, "callback did not run")
assert(scheduler.Run(30).Ran == 1 and rescheduled == 2, "explicit reschedule did not run")

reset()
local snapshotDue
scheduler.Attach("reschedule-other", function()
	scheduler.Reschedule("other", 10)
end, 0)
scheduler.Attach("other", function(_, _, due) snapshotDue = due end, 0)
local crossStats = scheduler.Run(0)
assert(crossStats.Ran == 1 and crossStats.Skipped == 1 and snapshotDue == nil, "rescheduled callback ran in the same snapshot")
assert(scheduler.GetSize() == 1, "cross-node reschedule was lost")
assert(scheduler.Run(10).Ran == 1 and snapshotDue == 10, "rescheduled callback did not run at its new due time")
scheduler.Detach("other")

reset()
local snapshotCount = 0
scheduler.Attach("first", function()
	snapshotCount = snapshotCount + 1
	scheduler.Detach("second")
	scheduler.Attach("new", function() snapshotCount = snapshotCount + 10 end, 0)
end, 0)
scheduler.Attach("second", function() snapshotCount = snapshotCount + 100 end, 0)
assert(scheduler.Run(0).Ran == 1 and snapshotCount == 1, "new due work ran in the same snapshot")
assert(scheduler.Run(0).Ran == 1 and snapshotCount == 11, "deferred work did not run on the next pass")

reset()
local limitedOrder = {}
for _, key in ipairs({ "first", "second", "third" }) do
	scheduler.Attach(key, function() limitedOrder[#limitedOrder + 1] = key end, 0)
end
local limitedStats = scheduler.Run(0, 2)
assert(limitedStats.Due == 2 and limitedStats.Ran == 2, "callback budget did not limit the current snapshot")
assert(scheduler.GetSize() == 1 and table.concat(limitedOrder) == "firstsecond", "limited dispatch changed FIFO behavior")
assert(scheduler.Run(0).Ran == 1 and table.concat(limitedOrder) == "firstsecondthird", "budgeted work was lost or duplicated")

reset()
local replaced = 0
scheduler.Attach("same", function() replaced = replaced + 1 end, 5)
scheduler.Attach("same", function() replaced = replaced + 10 end, 5)
assert(scheduler.Run(5).Ran == 1 and replaced == 10, "reattach left a stale node")

reset()
local failures = 0
scheduler.Attach("drop", function() error("expected callback failure") end, 0)
local errorStats = scheduler.Run(0)
assert(errorStats.Errors == 1 and scheduler.GetNode("drop") == nil, "failed callback was not isolated")
scheduler.Attach("retry", function()
	failures = failures + 1
	if failures == 1 then
		scheduler.Reschedule("retry", 1)
		error("expected retry")
	end
end, 0, { retryOnError = true })
assert(scheduler.Run(0).Errors == 1 and scheduler.GetSize() == 1, "retry policy did not preserve rescheduled work")
assert(scheduler.Run(1).Ran == 1 and failures == 2, "retry policy did not retry")

reset()
local replacementRan = 0
scheduler.Attach("replace-on-error", function()
	scheduler.Attach("replace-on-error", function() replacementRan = replacementRan + 1 end, 1)
	error("expected replacement failure")
end, 0)
assert(scheduler.Run(0).Errors == 1 and scheduler.GetSize() == 1, "callback failure detached its replacement")
assert(scheduler.Run(1).Ran == 1 and replacementRan == 1, "replacement did not survive callback failure")

reset()
expectError(function() scheduler.Attach("bad", function() end, math.huge) end)
expectError(function() scheduler.Attach("bad-priority", function() end, 0, { priority = 1.5 }) end)
expectError(function() scheduler.Run(0, 0) end)
expectError(function() scheduler.Run(0, 1.5) end)
expectError(function() scheduler.Run(0, math.huge) end)
expectError(function() scheduler.Reschedule("missing", 0 / 0) end)

assert(scheduler.Enable(), "scheduler adapter did not enable")
assert(not scheduler.Enable(), "scheduler adapter enabled twice")
assert(hookHandlers.Think and hookHandlers.Think.ACE_SchedulerDispatch, "scheduler hook was not registered")
scheduler = dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua") or ACE.Scheduler
assert(hookHandlers.Think and hookHandlers.Think.ACE_SchedulerDispatch, "reload did not restore the scheduler hook")
assert(ACE.Scheduler.Enabled, "reloaded scheduler did not honor the enabled convar")
scheduler = ACE.Scheduler
assert(scheduler.Disable(), "scheduler did not disable")
assert(not hookHandlers.Think.ACE_SchedulerDispatch, "scheduler hook was not removed")

local switchConVar = GetConVar("ace_scheduler_enabled")
assert(switchConVar and switchConVar:GetBool(), "scheduler switch did not default on")
convarCallbacks.ace_scheduler_enabled.callback("ace_scheduler_enabled", "1", "0")
assert(not scheduler.Enabled, "scheduler switch did not disable")
convarCallbacks.ace_scheduler_enabled.callback("ace_scheduler_enabled", "0", "1")
assert(scheduler.Enabled, "scheduler switch did not re-enable")

print("ACE scheduler LuaJIT self-test: PASS")
