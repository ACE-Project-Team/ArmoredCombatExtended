if CLIENT then return end

ACE = ACE or {}

local AdapterKey = "ACE.DamageDetonationEffect"
local State = ACE.DamageDetonationEffectSchedulerState or {
	Records = {},
	NextId = 0,
	Enabled = false,
}

ACE.DamageDetonationEffectSchedulerState = State
State.Records = State.Records or {}
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

local function TimerName(record)
	return "ACE_DamageDetonationEffect_" .. record.Id
end

local function Remove(record)
	if State.Records[record.Id] ~= record then return end

	State.Records[record.Id] = nil
	timer.Remove(TimerName(record))
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end

	local flash = EffectData()
	flash:SetAttachment(1)
	flash:SetOrigin(record.Origin)
	flash:SetNormal(-vector_up)
	flash:SetRadius(math.max(record.Radius, 1))
	util.Effect("ACE_Scaled_Detonation", flash)
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
		timer.Remove(TimerName(record))
		Attach(record)
	end
end

local function Disable()
	State.Enabled = false
	for _, record in pairs(State.Records) do
		if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
		Fallback(record)
	end
end

State.Cleanup = Disable

--- Schedules one delayed detonation effect through the optional heap.
-- @param origin Vector Effect origin captured by the authoritative explosion.
-- @param radius number Visual radius passed to the original effect callback.
-- @param delay number Seconds until the effect is emitted.
-- @return boolean Whether the request was accepted.
function ACE.ScheduleDamageDetonationEffect(origin, radius, delay)
	if origin == nil or type(radius) ~= "number" or radius ~= radius or radius == math.huge or radius == -math.huge then
		return false
	end
	if type(delay) ~= "number" or delay ~= delay or delay == math.huge or delay == -math.huge then return false end

	State.NextId = State.NextId + 1
	local record = {
		Origin = origin,
		Radius = radius,
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
