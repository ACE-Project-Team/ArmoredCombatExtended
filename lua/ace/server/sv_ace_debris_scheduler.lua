if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.EntityRemoval"
local State = ACE.EntityRemovalSchedulerState or ACE.DebrisRemovalSchedulerState or {
	Records = setmetatable({}, { __mode = "k" }),
	NextId = 0,
	Enabled = false,
}

ACE.EntityRemovalSchedulerState = State
ACE.DebrisRemovalSchedulerState = State
State.Records = State.Records or setmetatable({}, { __mode = "k" })
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

local function TimerName(record)
	return "ACE_EntityRemoval_" .. record.Id
end

local function Detach(record)
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	timer.Remove(TimerName(record))
	record.Token = record.Token + 1
end

local function Cancel(ent, record)
	if not record or State.Records[ent] ~= record then return end
	Detach(record)
	State.Records[ent] = nil
end

local function Remove(ent, record)
	if State.Records[ent] ~= record then return end
	State.Records[ent] = nil
	timer.Remove(TimerName(record))
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	if IsValid(ent) then ent:Remove() end
end

local function Fallback(ent, record)
	timer.Create(TimerName(record), math.max(0, record.Due - CurTime()), 1, function()
		if State.Records[ent] ~= record or record.Token ~= record.ActiveToken then return end
		Remove(ent, record)
	end)
end

local function Attach(ent, record)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	local token = record.Token
	record.ActiveToken = token
	scheduler.Attach(record.Key, function()
		if not State.Enabled or State.Records[ent] ~= record or record.Token ~= token then return end
		Remove(ent, record)
	end, record.Due)
end

local function Enable()
	State.Enabled = true
	for ent, record in pairs(State.Records) do
		if IsValid(ent) then
			timer.Remove(TimerName(record))
			Attach(ent, record)
		else
			Cancel(ent, record)
		end
	end
end

local function Disable()
	State.Enabled = false
	for ent, record in pairs(State.Records) do
		if IsValid(ent) then
			if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
			Fallback(ent, record)
		else
			Cancel(ent, record)
		end
	end
end

State.Cleanup = Disable

--- Schedules one-shot entity removal through the optional heap.
-- @param ent Entity Entity to remove after its lifetime.
-- @param delay number Lifetime in seconds; values below zero are clamped to now.
-- @param kind string Stable adapter key category for the entity class.
-- @return boolean Whether the request was accepted.
function ACE.ScheduleEntityRemoval(ent, delay, kind)
	if not IsValid(ent) or type(delay) ~= "number" or delay ~= delay or delay == math.huge or delay == -math.huge then
		return false
	end

	local previous = State.Records[ent]
	if previous then Cancel(ent, previous) end

	State.NextId = State.NextId + 1
	local record = {
		Id = State.NextId,
		Key = AdapterKey .. "." .. (kind or "Entity") .. "." .. State.NextId,
		Due = CurTime() + math.max(0, delay),
		Token = 0,
		ActiveToken = 0,
	}
	State.Records[ent] = record

	if State.Enabled then
		Attach(ent, record)
	else
		Fallback(ent, record)
	end
	return true
end

--- Cancels a pending entity lifetime removal.
-- @param ent Entity Entity whose removal should be canceled.
function ACE.UnregisterEntityRemoval(ent)
	Cancel(ent, State.Records[ent])
end

ACE.ScheduleDebrisRemoval = function(ent, delay)
	return ACE.ScheduleEntityRemoval(ent, delay, "Debris")
end
ACE.UnregisterDebrisRemoval = ACE.UnregisterEntityRemoval

local Adapter = { Enable = Enable, Disable = Disable }
if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(AdapterKey, Enable, Disable)
	if ACE.Scheduler.Enabled then Enable() end
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[AdapterKey] = Adapter
end
