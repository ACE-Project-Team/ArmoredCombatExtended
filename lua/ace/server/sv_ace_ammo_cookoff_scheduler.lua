if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.AmmoCookoffFlash"
local State = ACE.AmmoCookoffFlashSchedulerState or {
	Records = {},
	NextId = 0,
	Enabled = false,
}

ACE.AmmoCookoffFlashSchedulerState = State
State.Records = State.Records or {}
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

local function TimerName(record)
	return "ACE_AmmoCookoffFlash_" .. record.Id
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

	local ammo = record.Ammo
	if not IsValid(ammo) then return end

	local flash = EffectData()
	flash:SetOrigin(ammo.BulletData.Pos)
	flash:SetNormal(-vector_up)
	flash:SetRadius(record.Radius)
	util.Effect("ACE_Scaled_Explosion", flash)
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
		if IsValid(record.Ammo) then
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
		if IsValid(record.Ammo) then
			if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
			Fallback(record)
		else
			Forget(record)
		end
	end
end

State.Cleanup = Disable

--- Schedules one delayed ammunition cookoff flash through the optional heap.
-- @param ammo Entity Ammunition entity owning the effect.
-- @param delay number Seconds until the effect is emitted.
-- @param radius number Effect radius captured by the original callback.
-- @return boolean Whether the request was accepted.
function ACE.ScheduleAmmoCookoffFlash(ammo, delay, radius)
	if not IsValid(ammo) or type(delay) ~= "number" or delay ~= delay or delay == math.huge or delay == -math.huge then
		return false
	end

	State.NextId = State.NextId + 1
	local record = {
		Ammo = ammo,
		Due = CurTime() + math.max(0, delay),
		Id = State.NextId,
		Key = AdapterKey .. "." .. State.NextId,
		Radius = radius,
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
