if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.ScalableResync"
local State = ACE.ScalableResyncSchedulerState or {
	Jobs = setmetatable({}, { __mode = "k" }),
	NextId = 0,
}

ACE.ScalableResyncSchedulerState = State
State.Jobs = State.Jobs or setmetatable({}, { __mode = "k" })
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

local function TimerName(job)
	return "ACE_ScalableResync_" .. job.Id
end

local function Detach(job)
	if ACE.Scheduler then ACE.Scheduler.Detach(job.Key) end
	timer.Remove(TimerName(job))
end

local function Cancel(player, job)
	if not job then return end
	if State.Jobs[player] ~= job then return end
	Detach(job)
	State.Jobs[player] = nil
end

local function Step(player, job, now)
	if State.Jobs[player] ~= job then return end
	if not IsValid(player) then
		Cancel(player, job)
		return
	end

	local entity = job.Entities[job.Cursor]
	job.Cursor = job.Cursor - 1

	if IsValid(entity) and entity.IsScalable and ACE.NetworkScalableScale then
		local scaleData = entity.ScaleData
		if scaleData then ACE.NetworkScalableScale(entity, scaleData.Scale, player) end
	end

	if job.Cursor < 1 then
		State.Jobs[player] = nil
		if ACE.Scheduler then ACE.Scheduler.Detach(job.Key) end
		timer.Remove(TimerName(job))
		return
	end

	job.Due = now + engine.TickInterval()
	if ACE.Scheduler and ACE.Scheduler.Enabled then
		ACE.Scheduler.Reschedule(job.Key, job.Due)
	else
		timer.Create(TimerName(job), math.max(0, job.Due - CurTime()), 1, function()
			Step(player, job, CurTime())
		end)
	end
end

local function Attach(player, job)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	scheduler.Attach(job.Key, function(_, now)
		Step(player, job, now)
	end, job.Due)
end

local function Enable()
	for player, job in pairs(State.Jobs) do
		if IsValid(player) then
			timer.Remove(TimerName(job))
			Attach(player, job)
		else
			Cancel(player, job)
		end
	end
end

local function Disable()
	for player, job in pairs(State.Jobs) do
		if IsValid(player) then
			if ACE.Scheduler then ACE.Scheduler.Detach(job.Key) end
			timer.Create(TimerName(job), math.max(0, job.Due - CurTime()), 1, function()
				Step(player, job, CurTime())
			end)
		else
			Cancel(player, job)
		end
	end
end

State.Cleanup = function()
	for player, job in pairs(State.Jobs) do
		Cancel(player, job)
	end
end

function ACE.ScheduleScalableResync(player)
	if not IsValid(player) then return false end

	local previous = State.Jobs[player]
	if previous then Cancel(player, previous) end

	local entities = ACE.ScalableEnts
	local count = #entities
	if count == 0 then return true end

	State.NextId = State.NextId + 1
	local job = {
		Id = State.NextId,
		Key = AdapterKey .. "." .. State.NextId,
		Entities = entities,
		Cursor = count,
		Due = CurTime() + engine.TickInterval(),
	}
	State.Jobs[player] = job

	if ACE.Scheduler and ACE.Scheduler.Enabled then
		Attach(player, job)
	else
		timer.Create(TimerName(job), math.max(0, job.Due - CurTime()), 1, function()
			Step(player, job, CurTime())
		end)
	end
	return true
end

hook.Add("PlayerDisconnected", "ACE_ScalableResyncDisconnect", function(player)
	Cancel(player, State.Jobs[player])
end)

local Adapter = { Enable = Enable, Disable = Disable }
if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(AdapterKey, Enable, Disable)
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[AdapterKey] = Adapter
end
