if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.SonarTravelSound"
local PingAdapterKey = "ACE.SonarPingExpiry"
local State = ACE.SonarTravelSoundSchedulerState or {
	Records = {},
	NextId = 0,
	Enabled = false,
}
local PingState = ACE.SonarPingExpirySchedulerState or {
	Records = {},
	NextId = 0,
	Enabled = false,
}

ACE.SonarTravelSoundSchedulerState = State
ACE.SonarPingExpirySchedulerState = PingState
State.Records = State.Records or {}
State.NextId = State.NextId or 0
PingState.Records = PingState.Records or {}
PingState.NextId = PingState.NextId or 0

if State.Cleanup then State.Cleanup() end
if PingState.Cleanup then PingState.Cleanup() end

local function TimerName(record)
	return "ACE_SonarTravelSound_" .. record.Id
end

local function Detach(record)
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	timer.Remove(TimerName(record))
	record.Token = record.Token + 1
end

local function Forget(record)
	Detach(record)
	State.Records[record.Id] = nil
end

local function Remove(record)
	if State.Records[record.Id] ~= record then return end

	State.Records[record.Id] = nil
	timer.Remove(TimerName(record))
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end

	if not IsValid(record.Base) then return end

	debugoverlay.Line(record.SelfPos, record.BasePos, record.DebugDuration, record.DebugColor, true)
	record.Base:EmitSound(record.ActiveSound, record.Level, record.ActivePitch, record.Ratio, record.Channel)
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

local function Enable()
	State.Enabled = true
	for _, record in pairs(State.Records) do
		if IsValid(record.Base) then
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
		if IsValid(record.Base) then
			if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
			Fallback(record)
		else
			Forget(record)
		end
	end
end

State.Cleanup = Disable

local function PingTimerName(record)
	return "ACE_SonarPingExpiry_" .. record.Id
end

local function DetachPing(record)
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	timer.Remove(PingTimerName(record))
	record.Token = record.Token + 1
end

local function ForgetPing(record)
	local records = PingState.Records[record.Contraption]
	if records and records[record.PingId] == record then
		records[record.PingId] = nil
		if next(records) == nil then PingState.Records[record.Contraption] = nil end
	end
	DetachPing(record)
end

local function RemovePing(record)
	local records = PingState.Records[record.Contraption]
	if not records or records[record.PingId] ~= record then return end

	records[record.PingId] = nil
	if next(records) == nil then PingState.Records[record.Contraption] = nil end
	timer.Remove(PingTimerName(record))
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end

	local base = record.Contraption:GetACEBaseplate()
	if not IsValid(base) then return end

	local pings = record.Contraption.SonarPings
	local ping = pings and pings[record.PingId]
	if ping and ACE.CurTime > ping.Time then
		pings[record.PingId] = nil
	end
end

local function FallbackPing(record)
	timer.Create(PingTimerName(record), math.max(0, record.Due - CurTime()), 1, function()
		if PingState.Records[record.Contraption] == nil
		or PingState.Records[record.Contraption][record.PingId] ~= record
		or record.Token ~= record.ActiveToken then return end
		RemovePing(record)
	end)
end

local function AttachPing(record)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	local token = record.Token
	record.ActiveToken = token
	scheduler.Attach(record.Key, function()
		local records = PingState.Records[record.Contraption]
		if not PingState.Enabled or not records or records[record.PingId] ~= record or record.Token ~= token then return end
		RemovePing(record)
	end, record.Due)
end

local function EnablePingExpiry()
	PingState.Enabled = true
	for _, records in pairs(PingState.Records) do
		for _, record in pairs(records) do
			if type(record.Contraption.GetACEBaseplate) == "function" then
				timer.Remove(PingTimerName(record))
				AttachPing(record)
			else
				ForgetPing(record)
			end
		end
	end
end

local function DisablePingExpiry()
	PingState.Enabled = false
	for _, records in pairs(PingState.Records) do
		for _, record in pairs(records) do
			if type(record.Contraption.GetACEBaseplate) == "function" then
				if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
				FallbackPing(record)
			else
				ForgetPing(record)
			end
		end
	end
end

PingState.Cleanup = DisablePingExpiry

--- Schedules one delayed sonar travel sound through the optional heap.
-- @param base Entity Baseplate receiving the sound.
-- @param delay number Seconds until the sound is emitted.
-- @param selfPos Vector Sonar origin captured by the original callback.
-- @param basePos Vector Target baseplate position captured by the original callback.
-- @param activeSound string Sound path.
-- @param activePitch number Sound pitch.
-- @param ratio number Sound volume ratio.
-- @return boolean Whether the request was accepted.
function ACE.ScheduleSonarTravelSound(base, delay, selfPos, basePos, activeSound, activePitch, ratio, level, channel, debugColor, debugDuration)
	if not IsValid(base) or type(delay) ~= "number" or delay ~= delay or delay == math.huge or delay == -math.huge then
		return false
	end

	State.NextId = State.NextId + 1
	local record = {
		Base = base,
		Due = CurTime() + math.max(0, delay),
		Id = State.NextId,
		Key = AdapterKey .. "." .. State.NextId,
		SelfPos = selfPos,
		BasePos = basePos,
		TravelTime = delay,
		ActiveSound = activeSound,
		ActivePitch = activePitch,
		Ratio = ratio,
		Level = level or 130,
		Channel = channel,
		DebugColor = debugColor,
		DebugDuration = debugDuration or delay,
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

--- Coalesces expiry of one contraption's sonar ping entry through the optional heap.
-- @param contraption Contraption owning the sonar ping cache.
-- @param pingId Stable sonar source identifier within the contraption cache.
-- @param delay Seconds until the original expiry callback would run.
-- @return boolean Whether the request was accepted.
function ACE.ScheduleSonarPingExpiry(contraption, pingId, delay)
	if not contraption or type(contraption.GetACEBaseplate) ~= "function" or not IsValid(contraption:GetACEBaseplate()) or contraption:GetACEBaseplate():IsMarkedForDeletion()
	or pingId == nil or type(delay) ~= "number" or delay ~= delay or delay == math.huge or delay == -math.huge then
		return false
	end

	local records = PingState.Records[contraption]
	if not records then
		records = {}
		PingState.Records[contraption] = records
	end

	local due = CurTime() + math.max(0, delay)
	local existing = records[pingId]
	if existing then
		-- Keep the latest expiry so a refreshed ping cannot lose its own
		-- legacy timer while an earlier coalesced record is pending.
		if existing.Due >= due then return true end
		ForgetPing(existing)
		records = PingState.Records[contraption] or {}
		PingState.Records[contraption] = records
	end

	PingState.NextId = PingState.NextId + 1
	local record = {
		Contraption = contraption,
		PingId = pingId,
		Due = due,
		Id = PingState.NextId,
		Key = PingAdapterKey .. "." .. PingState.NextId,
		Token = 0,
		ActiveToken = 0,
	}
	records[pingId] = record

	if PingState.Enabled then
		AttachPing(record)
	else
		FallbackPing(record)
	end
	return true
end

local Adapter = { Enable = Enable, Disable = Disable }
local PingAdapter = { Enable = EnablePingExpiry, Disable = DisablePingExpiry }
if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(AdapterKey, Enable, Disable)
	ACE.Scheduler.RegisterAdapter(PingAdapterKey, EnablePingExpiry, DisablePingExpiry)
	if ACE.Scheduler.Enabled then Enable() end
	if ACE.Scheduler.Enabled then EnablePingExpiry() end
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[AdapterKey] = Adapter
	ACE.SchedulerAdapterDefinitions[PingAdapterKey] = PingAdapter
end
