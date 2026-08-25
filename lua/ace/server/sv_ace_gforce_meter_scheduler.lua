ACE = ACE or {}

local AdapterKey = "ACE.GForceMeterThink"
local State = ACE.GForceMeterSchedulerState or {
	Records = setmetatable({}, { __mode = "k" }),
	NextId = 0,
	Enabled = false,
}

ACE.GForceMeterSchedulerState = State
State.Records = State.Records or setmetatable({}, { __mode = "k" })
State.NextId = State.NextId or 0

if State.Cleanup then State.Cleanup() end

--- Advances one fixed-step g-force-meter update and publishes its Wire/overlay state.
-- @param ent Entity G-force meter entity to update.
function ACE.UpdateGForceMeter(ent)
	ent:CalculateGForce()
	ent:UpdateOutputs()
	ent:UpdateOverlayText()
end

local function Detach(record)
	if ACE.Scheduler then ACE.Scheduler.Detach(record.Key) end
	record.Token = record.Token + 1
end

local function Attach(ent, record)
	local scheduler = ACE.Scheduler
	if not scheduler then return end

	local token = record.Token
	scheduler.Attach(record.Key, function(_, now)
		if not State.Enabled or State.Records[ent] ~= record or record.Token ~= token then return end
		if not IsValid(ent) or not ent.ACE_GForceMeterSchedulerOwned then return end

		ACE.UpdateGForceMeter(ent)
		record.NextDue = now + record.Delay
		if State.Enabled and State.Records[ent] == record and record.Token == token then
			scheduler.Reschedule(record.Key, record.NextDue)
		end
	end, record.NextDue)

	ent.ACE_GForceMeterSchedulerOwned = true
	ent:NextThink(CurTime() + 3600)
end

local function Enable()
	State.Enabled = true
	for _, ent in ipairs(ents.FindByClass("ace_gforce_meter")) do
		ACE.RegisterGForceMeter(ent)
	end
	for ent, record in pairs(State.Records) do
		if IsValid(ent) then
			record.Token = record.Token + 1
			record.NextDue = record.NextDue or CurTime() + record.Delay
			Attach(ent, record)
		else
			State.Records[ent] = nil
		end
	end
end

local function Disable()
	State.Enabled = false
	for ent, record in pairs(State.Records) do
		Detach(record)
		if IsValid(ent) then
			ent.ACE_GForceMeterSchedulerOwned = false
			ent:NextThink(math.max(record.NextDue or CurTime(), CurTime()))
		end
	end
end

State.Cleanup = Disable

--- Registers a g-force-meter entity with the optional cadence scheduler.
-- @param ent Entity G-force meter entity to register.
function ACE.RegisterGForceMeter(ent)
	if not IsValid(ent) or State.Records[ent] then return end

	State.NextId = State.NextId + 1
	local delay = ent.ThinkDelay or 0.05
	local firstDelay = engine and engine.TickInterval and engine.TickInterval() or delay
	local record = {
		Key = AdapterKey .. "." .. State.NextId,
		Delay = delay,
		NextDue = CurTime() + firstDelay,
		Token = 0,
	}
	State.Records[ent] = record
	if State.Enabled then Attach(ent, record) end
end

--- Removes a g-force-meter entity from scheduler ownership.
-- @param ent Entity G-force meter entity to unregister.
function ACE.UnregisterGForceMeter(ent)
	local record = State.Records[ent]
	if not record then return end
	Detach(record)
	State.Records[ent] = nil
end

--- Records the next fallback due time after an engine-driven update.
-- @param ent Entity G-force meter entity that updated through fallback.
-- @param now number Current server time at the fallback update.
function ACE.MarkGForceMeterFallback(ent, now)
	local record = State.Records[ent]
	if record then record.NextDue = now + record.Delay end
end

hook.Add("EntityRemoved", "ACE_GForceMeterSchedulerEntityRemoved", function(ent)
	ACE.UnregisterGForceMeter(ent)
end)

local Adapter = { Enable = Enable, Disable = Disable }
if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(AdapterKey, Enable, Disable)
	if ACE.Scheduler.Enabled then Enable() end
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[AdapterKey] = Adapter
end
