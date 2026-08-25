if CLIENT then return end

ACE = ACE or {}

local LegalCheckKey = "ACE.ContraptionLegalCheck"
local State = ACE.ContraptionLegalCheckState or { Pending = {} }
ACE.ContraptionLegalCheckState = State
State.Pending = State.Pending or {}
State.NextToken = State.NextToken or 0

local function Finish(ent, record, token)
	if State.Pending[ent] ~= record or record.Token ~= token then return end

	State.Pending[ent] = nil
	if IsValid(ent) then ent.CanLegalCheck = true end
end

local function Attach(ent, record)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	local token = record.Token
	scheduler.Attach(record.Key, function()
		Finish(ent, record, token)
	end, record.Due)
end

local function NewRecord(previous)
	State.NextToken = State.NextToken + 1
	return {
		Key = previous and previous.Key or {},
		Due = previous and previous.Due,
		Token = State.NextToken,
	}
end

local function Enable()
	for ent, previous in pairs(State.Pending) do
		local record = NewRecord(previous)
		State.Pending[ent] = record
		Attach(ent, record)
	end
end

local function Disable()
	local scheduler = ACE.Scheduler

	for ent, previous in pairs(State.Pending) do
		local record = NewRecord(previous)
		State.Pending[ent] = record
		if scheduler then scheduler.Detach(previous.Key) end

		local delay = math.max(0, record.Due - CurTime())
		timer.Simple(delay, function()
			Finish(ent, record, record.Token)
		end)
	end
end

--- Schedules the cooldown reset for an ACE legality check.
-- @param ent Entity whose legality-check cooldown is being reset.
-- @param delay number Seconds until the next check is allowed.
function ACE.ScheduleLegalCheckReset(ent, delay)
	local previous = State.Pending[ent]
	local scheduler = ACE.Scheduler

	if previous and scheduler then scheduler.Detach(previous.Key) end

	local record = NewRecord(previous)
	record.Due = CurTime() + delay
	State.Pending[ent] = record

	if scheduler and scheduler.Enabled then
		Attach(ent, record)
		return
	end

	timer.Simple(delay, function()
		Finish(ent, record, record.Token)
	end)
end

local Adapter = { Enable = Enable, Disable = Disable }
if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(LegalCheckKey, Enable, Disable)
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[LegalCheckKey] = Adapter
end
