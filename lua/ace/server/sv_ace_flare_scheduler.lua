if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.FlareThink"
local UpdatePeriod = 0.2
local ParkDelay = 1000000
local State = ACE.FlareThinkSchedulerState or {
	Records = setmetatable({}, { __mode = "k" }),
	NextId = 0,
	Enabled = false,
}

ACE.FlareThinkSchedulerState = State
State.Records = State.Records or setmetatable({}, { __mode = "k" })
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

local function IsRecordCurrent(ent, record)
	return State.Records[ent] == record and record.Token == record.ActiveToken
end

local function IsFlare(ent)
	return IsValid(ent) and (not ent.GetClass or ent:GetClass() == "ace_flare")
end

local function Detach(record)
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	record.Token = record.Token + 1
end

local function Park(ent)
	if IsValid(ent) then ent:NextThink(CurTime() + ParkDelay) end
end

local function Update(ent, record, now)
	if State.Records[ent] ~= record or not IsValid(ent) then return end

	if ent:WaterLevel() == 3 then
		ent.Thermal = 0
		ent:StopParticles()
		record.NextDue = now + UpdatePeriod
		if State.Enabled and ACE.Scheduler then
			ACE.Scheduler.Reschedule(record.Key, record.NextDue)
		end
		return false
	end

	local aliveTime = (ACE.CurTime or now) - ent.FirstTime
	local effectiveness = 1 - (aliveTime / ent.Life)
	ent.Thermal = ent.FirstThermal * effectiveness
	ent.RadarSig = ent.FirstRadarSig * effectiveness
	record.NextDue = now + UpdatePeriod

	if State.Enabled and ACE.Scheduler then
		ACE.Scheduler.Reschedule(record.Key, record.NextDue)
	end
end

local function Attach(ent, record, due)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	record.ActiveToken = record.Token
	scheduler.Attach(record.Key, function(_, now)
		if not State.Enabled or not IsRecordCurrent(ent, record) then return end
		Update(ent, record, now)
	end, due)
	Park(ent)
end

local function Cancel(ent, record)
	if not record or State.Records[ent] ~= record then return end
	Detach(record)
	State.Records[ent] = nil
end

local function Register(ent)
	if not IsFlare(ent) then return false end

	local previous = State.Records[ent]
	if previous then Cancel(ent, previous) end

	State.NextId = State.NextId + 1
	local record = {
		Key = AdapterKey .. "." .. State.NextId,
		NextDue = CurTime(),
		Token = 0,
		ActiveToken = 0,
	}
	State.Records[ent] = record

	if State.Enabled then
		Attach(ent, record, record.NextDue)
	end
	return true
end

local function Enable()
	State.Enabled = true

	for ent in pairs(ACE.CMTable or {}) do
		if IsFlare(ent) and not State.Records[ent] then Register(ent) end
	end

	for ent, record in pairs(State.Records) do
		if not IsValid(ent) then
			Cancel(ent, record)
		else
			Attach(ent, record, math.max(record.NextDue, CurTime()))
		end
	end
end

local function Disable()
	State.Enabled = false

	for ent, record in pairs(State.Records) do
		if not IsValid(ent) then
			Cancel(ent, record)
		else
			Detach(record)
			ent:NextThink(math.max(record.NextDue, CurTime()))
		end
	end
end

State.Cleanup = Disable

--- Registers an ace_flare for optional heap-backed signature updates.
-- @param ent Entity Flare entity to register.
-- @return boolean Whether the entity was accepted.
function ACE.RegisterFlareThink(ent)
	return Register(ent)
end

--- Removes an ace_flare from the optional heap-backed signature updates.
-- @param ent Entity Flare entity to unregister.
function ACE.UnregisterFlareThink(ent)
	Cancel(ent, State.Records[ent])
end

--- Runs the native fallback or parks a flare while the heap owns its cadence.
-- @param ent Entity Flare entity whose Think callback is running.
-- @return boolean|nil Whether the entity should continue native Think processing.
function ACE.FlareThink(ent)
	local record = State.Records[ent]
	if not record then return nil end
	if State.Enabled then
		Park(ent)
		return true
	end

	local now = CurTime()
	local active = Update(ent, record, now)
	if active == false then return false end
	ent:NextThink(record.NextDue)
	return true
end

local Adapter = { Enable = Enable, Disable = Disable }
if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(AdapterKey, Enable, Disable)
	if ACE.Scheduler.Enabled then Enable() end
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[AdapterKey] = Adapter
end
