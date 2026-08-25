if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.GunAutoSound"
local State = ACE.GunAutoSoundSchedulerState or {
	Records = {},
	NextId = 0,
	Enabled = false,
}

ACE.GunAutoSoundSchedulerState = State
State.Records = State.Records or {}
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

local function TimerName(record)
	return "ACE_GunAutoSound_" .. record.Id
end

local function Detach(record)
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	timer.Remove(TimerName(record))
	record.Token = record.Token + 1
end

local function Remove(record)
	if State.Records[record.Id] ~= record then return end

	State.Records[record.Id] = nil
	timer.Remove(TimerName(record))
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end

	local gun = record.Gun
	if IsValid(gun) and gun.AutoSound and gun.AutoSound ~= "" then
		gun:EmitSound(gun.AutoSound, 73, math.random(84, 86))
	end
end

local function Fallback(record)
	timer.Create(TimerName(record), math.max(0, record.Due - CurTime()), 1, function()
		if State.Records[record.Id] ~= record or record.Token ~= record.ActiveToken then return end
		Remove(record)
	end)
end

local function Attach(record)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	local token = record.Token
	record.ActiveToken = token
	scheduler.Attach(record.Key, function()
		if not State.Enabled or State.Records[record.Id] ~= record or record.Token ~= token then return end
		Remove(record)
	end, record.Due)
end

local function Forget(record)
	Detach(record)
	State.Records[record.Id] = nil
end

local function Enable()
	State.Enabled = true
	for _, record in pairs(State.Records) do
		if IsValid(record.Gun) then
			timer.Remove(TimerName(record))
			Attach(record)
		else
			Forget(record)
		end
	end
end

local function Disable()
	State.Enabled = false
	for _, record in pairs(State.Records) do
		if IsValid(record.Gun) then
			if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
			Fallback(record)
		else
			Forget(record)
		end
	end
end

State.Cleanup = Disable

--- Schedules one delayed gun sound through the optional heap.
-- @param gun Entity Gun emitting the delayed sound.
-- @param delay number Seconds until the sound is emitted.
-- @return boolean Whether the request was accepted.
function ACE.ScheduleGunAutoSound(gun, delay)
	if not IsValid(gun) or type(delay) ~= "number" or delay ~= delay or delay == math.huge or delay == -math.huge then
		return false
	end

	State.NextId = State.NextId + 1
	local record = {
		Gun = gun,
		Due = CurTime() + math.max(0, delay),
		Id = State.NextId,
		Key = AdapterKey .. "." .. State.NextId,
		Token = 0,
		ActiveToken = 0,
	}
	State.Records[record.Id] = record

	if State.Enabled then
		Attach(record)
	else
		Fallback(record)
	end
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
