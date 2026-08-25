if CLIENT then return end

ACE = ACE or {}

local WindSensorAdapterKey = "ACE.WindSensorThink"
local State = ACE.WindSensorSchedulerState or {
	Records = setmetatable({}, { __mode = "k" }),
	NextId = 0,
	Enabled = false,
}

ACE.WindSensorSchedulerState = State
State.Records = State.Records or setmetatable({}, { __mode = "k" })
State.NextId = State.NextId or 0

if State.RemovalHookInstalled and hook then
	hook.Remove("EntityRemoved", "ACE_WindSensorSchedulerEntityRemoved")
end

if State.Cleanup then State.Cleanup() end

local function DetachRecord(record)
	local scheduler = ACE.Scheduler
	if scheduler then scheduler.Detach(record.Key) end
	record.Token = record.Token + 1
end

local function AttachRecord(ent, record)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	local token = record.Token
	local due = record.NextDue or CurTime() + record.Delay

	scheduler.Attach(record.Key, function(_, now)
		if not State.Enabled or State.Records[ent] ~= record or record.Token ~= token then return end
		if not IsValid(ent) or not ent.ACE_WindSensorSchedulerOwned then return end

		ent:UpdateOutputs()
		ent:UpdateOverlayText()
		record.NextDue = now + record.Delay

		if State.Enabled and State.Records[ent] == record and record.Token == token then
			scheduler.Reschedule(record.Key, record.NextDue)
		end
	end, due)

	ent.ACE_WindSensorSchedulerOwned = true
	ent:NextThink(CurTime() + 3600)
end

local function EnableWindSensorScheduler()
	State.Enabled = true

	for ent, record in pairs(State.Records) do
		if IsValid(ent) then
			record.Token = record.Token + 1
			record.NextDue = record.NextDue or CurTime() + record.Delay
			AttachRecord(ent, record)
		else
			State.Records[ent] = nil
		end
	end
end

local function DisableWindSensorScheduler()
	State.Enabled = false

	for ent, record in pairs(State.Records) do
		DetachRecord(record)
		if IsValid(ent) then
			ent.ACE_WindSensorSchedulerOwned = false
			local wakeAt = record.NextDue or CurTime()
			ent:NextThink(math.max(wakeAt, CurTime()))
		end
	end
end

State.Cleanup = DisableWindSensorScheduler

function ACE.RegisterWindSensor(ent)
	if not IsValid(ent) then return end
	if State.Records[ent] then return end

	State.NextId = State.NextId + 1
	local record = {
		Key = WindSensorAdapterKey .. "." .. State.NextId,
		Delay = ent.ThinkDelay or 0.1,
		NextDue = CurTime() + (ent.ThinkDelay or 0.1),
		Token = 0,
	}

	State.Records[ent] = record
	if State.Enabled then AttachRecord(ent, record) end
end

function ACE.UnregisterWindSensor(ent)
	local record = State.Records[ent]
	if not record then return end

	DetachRecord(record)
	State.Records[ent] = nil
end

function ACE.MarkWindSensorFallback(ent, now)
	local record = State.Records[ent]
	if record then record.NextDue = now + record.Delay end
end

hook.Add("EntityRemoved", "ACE_WindSensorSchedulerEntityRemoved", function(ent)
	ACE.UnregisterWindSensor(ent)
end)
State.RemovalHookInstalled = true

local WindSensorAdapter = {
	Enable = EnableWindSensorScheduler,
	Disable = DisableWindSensorScheduler,
}

if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(WindSensorAdapterKey, EnableWindSensorScheduler, DisableWindSensorScheduler)
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[WindSensorAdapterKey] = WindSensorAdapter
end
