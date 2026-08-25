if CLIENT then return end

ACE = ACE or {}

local RenderSchedulerKey = "ACE.RenderPropDamage"
if ACE.Scheduler then ACE.Scheduler.Detach(RenderSchedulerKey) end

local function GetRenderState(Entity)
	if ACE.GetEntityState then return ACE.GetEntityState(Entity, true) end
	return Entity["ACE"] or Entity["ACF"]
end

local SendDelay = 0.001
local RenderProps = ACE.RenderPropDamageState or {
	Entities = {},
	Clock = 0
}
ACE.RenderPropDamageState = RenderProps

local function ScheduleRenderDispatch(delay)
	local scheduler = ACE.Scheduler
	if not (scheduler and scheduler.Enabled) then return false end

	local due = CurTime() + delay
	local node = scheduler.GetNode(RenderSchedulerKey)
	if node then
		if node.Index == 0 or node.Due > due then scheduler.Reschedule(RenderSchedulerKey, due) end
	else
		scheduler.Attach(RenderSchedulerKey, ACE_SendVisualDamage, due)
	end

	return true
end

--- Dispatches one queued visual-health update, preserving the legacy 1 ms spacing.
-- @return nil
function ACE_SendVisualDamage()
	local Time = CurTime()
	if not next(RenderProps.Entities) then return end

	if Time < RenderProps.Clock then
		ScheduleRenderDispatch(RenderProps.Clock - Time)
		return
	end

	for index = #RenderProps.Entities, 1, -1 do
		local Entity = RenderProps.Entities[index]
		if not Entity:IsValid() then table.remove(RenderProps.Entities, index) end
	end

	local Entity = RenderProps.Entities[1]
	if IsValid(Entity) then
		local state = GetRenderState(Entity)
		net.Start("ACE_RenderDamage", true) -- Visual-only; dropping under extreme load is acceptable.
			net.WriteUInt(Entity:EntIndex(), 13)
			net.WriteFloat(state.MaxHealth)
			net.WriteFloat(state.Health)
		net.Broadcast()

		state.OnRenderQueue = nil
	end
	table.remove(RenderProps.Entities, 1)

	RenderProps.Clock = Time + SendDelay
	if next(RenderProps.Entities) then
		ScheduleRenderDispatch(SendDelay)
	end
end

--- Queues a visual-health update once per entity until it is dispatched.
-- @param Entity Entity receiving the visual-health update.
-- @return nil
function ACE_UpdateVisualHealth(Entity)
	local state = GetRenderState(Entity)
	if not state.OnRenderQueue then
		table.insert(RenderProps.Entities, Entity)
		state.OnRenderQueue = true
		ScheduleRenderDispatch(0)
	end
end

-- Keep the ACE-namespaced entry points used by the damage and weapon paths while
-- retaining the legacy flat names for addons that still call them directly.
ACE.UpdateVisualHealth = ACE_UpdateVisualHealth
ACE.SendVisualDamage = ACE_SendVisualDamage

local function EnableRenderScheduler()
	hook.Remove("Think", "ACE_RenderPropDamage")
	if next(RenderProps.Entities) then
		local delay = math.max(RenderProps.Clock - CurTime(), 0)
		ScheduleRenderDispatch(delay)
	end
end

local function DisableRenderScheduler()
	if ACE.Scheduler then ACE.Scheduler.Detach(RenderSchedulerKey) end
	hook.Add("Think", "ACE_RenderPropDamage", ACE_SendVisualDamage)
end

local RenderSchedulerAdapter = {
	Enable = EnableRenderScheduler,
	Disable = DisableRenderScheduler,
}

if ACE.Scheduler then
	ACE.Scheduler.RegisterAdapter(RenderSchedulerKey, EnableRenderScheduler, DisableRenderScheduler)
else
	ACE.SchedulerAdapterDefinitions = ACE.SchedulerAdapterDefinitions or {}
	ACE.SchedulerAdapterDefinitions[RenderSchedulerKey] = RenderSchedulerAdapter
end

if not (ACE.Scheduler and ACE.Scheduler.Enabled) then
	hook.Add("Think", "ACE_RenderPropDamage", ACE_SendVisualDamage)
end
