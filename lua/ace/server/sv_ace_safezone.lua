if CLIENT then return end

ACE = ACE or {}
local this = ACE.Permissions
local SafezoneState = ACE.SafezoneTransitionState or { Plyzones = {} }
ACE.SafezoneTransitionState = SafezoneState
local plyzones = SafezoneState.Plyzones

local SafezoneVisualizationKey = "ACE.SafezoneVisualization"
local SafezoneVisualizationState = ACE.SafezoneVisualizationState or {
	Generation = 0,
	Pending = false,
	Due = nil,
}
ACE.SafezoneVisualizationState = SafezoneVisualizationState

local function RunSafezoneVisualization(generation)
	if generation ~= SafezoneVisualizationState.Generation then return end

	SafezoneVisualizationState.Pending = false
	SafezoneVisualizationState.Due = nil
	if ACE.Permissions.visualizeSafeZones then ACE.Permissions.visualizeSafeZones() end
end

local function AttachSafezoneVisualization()
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	SafezoneVisualizationState.Generation = SafezoneVisualizationState.Generation + 1
	local generation = SafezoneVisualizationState.Generation
	local due = SafezoneVisualizationState.Due

	if not SafezoneVisualizationState.Pending or not due then return end

	scheduler.Attach(SafezoneVisualizationKey, function()
		RunSafezoneVisualization(generation)
	end, due)
end

local function DisableSafezoneVisualization()
	SafezoneVisualizationState.Generation = SafezoneVisualizationState.Generation + 1
	local generation = SafezoneVisualizationState.Generation
	local scheduler = ACE.Scheduler
	if scheduler then scheduler.Detach(SafezoneVisualizationKey) end

	if not SafezoneVisualizationState.Pending or not SafezoneVisualizationState.Due then return end

	local delay = math.max(0, SafezoneVisualizationState.Due - CurTime())
	timer.Simple(delay, function()
		RunSafezoneVisualization(generation)
	end)
end

--- Schedules delayed safe-zone visualization through the opt-in heap.
-- @param delay number Seconds until visualization runs.
function ACE.ScheduleSafezoneVisualization(delay)
	SafezoneVisualizationState.Generation = SafezoneVisualizationState.Generation + 1
	local generation = SafezoneVisualizationState.Generation
	SafezoneVisualizationState.Pending = true
	SafezoneVisualizationState.Due = CurTime() + delay

	if ACE.Scheduler and ACE.Scheduler.Enabled then
		AttachSafezoneVisualization()
		return
	end

	timer.Simple(delay, function()
		RunSafezoneVisualization(generation)
	end)
end

local SafezoneVisualizationAdapter = {
	Enable = AttachSafezoneVisualization,
	Disable = DisableSafezoneVisualization,
}

if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(SafezoneVisualizationKey, AttachSafezoneVisualization, DisableSafezoneVisualization)
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[SafezoneVisualizationKey] = SafezoneVisualizationAdapter
end

hook.Add("PlayerDisconnected", "ACE_SafezoneDisconnect", function(ply)
	plyzones[ply:SteamID()] = nil
end)
local SafezoneSchedulerKey = "ACE.SafezoneTransition"
local SafezoneThinkGeneration = 0
local SafezoneThinkDelay = engine.TickInterval()

local function DetectSafezoneTransition()
	for _, ply in pairs(player.GetAll()) do
		local sid = ply:SteamID()
		local pos = ply:GetPos()
		local oldzone = plyzones[sid]
		local zone = this.IsInSafezone(pos) or nil
		plyzones[sid] = zone

		if oldzone ~= zone then
			hook.Call("ACE_PlayerChangedZone", GAMEMODE, ply, zone, oldzone)
		end
	end
end

local function EnableSafezoneTransitionScheduler()
	SafezoneThinkGeneration = SafezoneThinkGeneration + 1
	hook.Remove("Think", "ACE_DetectSZTransition")
	local scheduler = ACE.Scheduler
	local generation = SafezoneThinkGeneration
	scheduler.Attach(SafezoneSchedulerKey, function(_, now)
		if generation ~= SafezoneThinkGeneration then return end
		DetectSafezoneTransition()
		scheduler.Reschedule(SafezoneSchedulerKey, now + SafezoneThinkDelay)
	end, CurTime() + SafezoneThinkDelay)
end

local function DisableSafezoneTransitionScheduler()
	SafezoneThinkGeneration = SafezoneThinkGeneration + 1
	if ACE.Scheduler then ACE.Scheduler.Detach(SafezoneSchedulerKey) end
	hook.Add("Think", "ACE_DetectSZTransition", DetectSafezoneTransition)
end

local SafezoneTransitionAdapter = {
	Enable = EnableSafezoneTransitionScheduler,
	Disable = DisableSafezoneTransitionScheduler,
}

if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(SafezoneSchedulerKey, EnableSafezoneTransitionScheduler, DisableSafezoneTransitionScheduler)
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[SafezoneSchedulerKey] = SafezoneTransitionAdapter
end

if not (ACE.Scheduler and ACE.Scheduler.Enabled) then
	hook.Add("Think", "ACE_DetectSZTransition", DetectSafezoneTransition)
end
