local root = assert(arg[1], "usage: ace_safezone_scheduler_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
local now = 0
local hookHandlers = {}
local timerCallbacks = {}
timer = {
	Simple = function(delay, callback)
		timerCallbacks[#timerCallbacks + 1] = { delay = delay, callback = callback }
	end,
}
hook = {
	Add = function(name, identifier, callback)
		hookHandlers[name] = hookHandlers[name] or {}
		hookHandlers[name][identifier] = callback
	end,
	Remove = function(name, identifier)
		if hookHandlers[name] then hookHandlers[name][identifier] = nil end
	end,
	Call = function(name, ...)
		if name == "ACE_PlayerChangedZone" then
			_G.transitionCount = _G.transitionCount + 1
		end
	end,
}
engine = { TickInterval = function() return 0.015 end }
function CurTime() return now end
GAMEMODE = {}

local fakePlayer = {
	zone = false,
	SteamID = function() return "STEAM_0:1:SAFEZONE" end,
	GetPos = function(self) return { zone = self.zone } end,
}
player = { GetAll = function() return { fakePlayer } end }

ACE = { Permissions = {} }
ACE.Permissions.IsInSafezone = function(pos) return pos.zone end
local visualizationCount = 0
ACE.Permissions.visualizeSafeZones = function() visualizationCount = visualizationCount + 1 end
_G.transitionCount = 0

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local firstScheduler = ACE.Scheduler
firstScheduler.Disable()

-- The adapter must survive loading before the scheduler module and be picked up later.
ACE.Scheduler = nil
ACE.SchedulerAdapterDefinitions = {}
dofile(root .. "/lua/ace/server/sv_ace_safezone.lua")
assert(ACE.SchedulerAdapterDefinitions["ACE.SafezoneTransition"], "safe-zone adapter was not queued")
assert(ACE.SchedulerAdapterDefinitions["ACE.SafezoneVisualization"], "safe-zone visualization adapter was not queued")
assert(hookHandlers.Think and hookHandlers.Think.ACE_DetectSZTransition, "fallback Think hook missing")

ACE.ScheduleSafezoneVisualization(5)
assert(#timerCallbacks == 1 and timerCallbacks[1].delay == 5, "disabled visualization did not retain timer fallback")

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local scheduler = ACE.Scheduler
assert(scheduler.Adapters["ACE.SafezoneTransition"], "pending safe-zone adapter was not registered")
assert(hookHandlers.Think.ACE_DetectSZTransition, "fallback hook was not retained after scheduler load")

assert(scheduler.Enable(), "scheduler did not enable")
assert(not hookHandlers.Think.ACE_DetectSZTransition, "safe-zone Think hook remained enabled")
local visualizationNode = scheduler.GetNode("ACE.SafezoneVisualization")
assert(visualizationNode, "safe-zone visualization heap node was not attached")
now = visualizationNode.Due
scheduler.Run(now)
assert(visualizationCount == 1, "scheduled safe-zone visualization did not run")
assert(scheduler.GetNode("ACE.SafezoneVisualization") == nil, "one-shot visualization node was not retired")
local node = scheduler.GetNode("ACE.SafezoneTransition")
assert(node, "safe-zone heap node was not attached")
local firstDue = node.Due

now = firstDue
fakePlayer.zone = false
scheduler.Run(now)
assert(_G.transitionCount == 0, "outside-to-outside poll emitted a transition")
node = scheduler.GetNode("ACE.SafezoneTransition")
assert(node and math.abs((node.Due - firstDue) - 0.015) < 1e-9, "safe-zone cadence was not tick-preserving")

fakePlayer.zone = "probe_zone"
now = node.Due
scheduler.Run(now)
assert(_G.transitionCount == 1, "scheduled safe-zone entry was not delivered")

node = scheduler.GetNode("ACE.SafezoneTransition")
fakePlayer.zone = false
now = node.Due
scheduler.Run(now)
assert(_G.transitionCount == 2, "scheduled safe-zone exit was not delivered")

fakePlayer.zone = "probe_zone"
node = scheduler.GetNode("ACE.SafezoneTransition")
now = node.Due
scheduler.Run(now)
assert(_G.transitionCount == 3, "scheduled safe-zone re-entry was not delivered")

-- Enabled reload must preserve an already-observed zone and replace the keyed node in place.
dofile(root .. "/lua/ace/server/sv_ace_safezone.lua")
assert(not hookHandlers.Think.ACE_DetectSZTransition, "enabled reload restored the safe-zone Think hook")
node = scheduler.GetNode("ACE.SafezoneTransition")
assert(node, "enabled reload did not replace the safe-zone node")
now = node.Due
scheduler.Run(now)
assert(_G.transitionCount == 3, "enabled reload emitted a duplicate safe-zone entry")

ACE.ScheduleSafezoneVisualization(4)
local pendingVisualization = scheduler.GetNode("ACE.SafezoneVisualization")
assert(pendingVisualization, "enabled visualization was not attached")
dofile(root .. "/lua/ace/server/sv_ace_safezone.lua")
pendingVisualization = scheduler.GetNode("ACE.SafezoneVisualization")
assert(pendingVisualization, "visualization node was not replaced on reload")
now = pendingVisualization.Due
scheduler.Run(now)
assert(visualizationCount == 2, "visualization reload emitted a duplicate or lost callback")

assert(scheduler.Disable(), "scheduler did not disable")
assert(scheduler.GetNode("ACE.SafezoneTransition") == nil, "safe-zone node remained after disable")
assert(hookHandlers.Think.ACE_DetectSZTransition, "safe-zone fallback hook was not restored")

ACE.ScheduleSafezoneVisualization(2)
assert(#timerCallbacks == 2 and timerCallbacks[2].delay == 2, "disabled visualization did not restore timer fallback")
timerCallbacks[2].callback()
assert(visualizationCount == 3, "restored visualization timer did not run")

-- Re-inclusion while disabled must replace the fallback callback without duplicating behavior.
dofile(root .. "/lua/ace/server/sv_ace_safezone.lua")
assert(scheduler.Enable(), "scheduler did not re-enable after adapter reload")
assert(not hookHandlers.Think.ACE_DetectSZTransition, "reloaded safe-zone hook remained enabled")
assert(scheduler.GetNode("ACE.SafezoneTransition"), "reloaded safe-zone node was not attached")
assert(scheduler.Disable(), "scheduler did not disable after adapter reload")

local disconnectState = ACE.SafezoneTransitionState.Plyzones
disconnectState["STEAM_0:1:DISCONNECT"] = "stale_zone"
assert(hookHandlers.PlayerDisconnected and hookHandlers.PlayerDisconnected.ACE_SafezoneDisconnect, "safe-zone disconnect hook missing")
hookHandlers.PlayerDisconnected.ACE_SafezoneDisconnect({
	SteamID = function() return "STEAM_0:1:DISCONNECT" end,
})
assert(disconnectState["STEAM_0:1:DISCONNECT"] == nil, "safe-zone disconnect state was not cleared")

print("ACE safe-zone scheduler LuaJIT self-test: PASS")
