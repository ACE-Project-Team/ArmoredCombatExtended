if not SERVER then return end

local DIR = "ace_debris_runtime_probe_v1"
local result = { schema = 1, errors = {}, started_at = SysTime(), entities = {} }
file.CreateDir(DIR)

local function write(name, value) file.Write(DIR .. "/" .. name, value) end
local function fail(message) result.errors[#result.errors + 1] = message end

local scheduler
local phase = 0
local beginRequested = false
local pollTimer = "ACE_DebrisRuntimeProbePoll"
local tracked = {}

local function entityRemovalSize()
	local count = 0
	for _, node in ipairs(scheduler.Heap) do
		if string.sub(node.Key, 1, #"ACE.EntityRemoval.") == "ACE.EntityRemoval." then
			count = count + 1
		end
	end
	return count
end

local function heapHasKey(key)
	if not key then return false end
	for _, node in ipairs(scheduler.Heap) do
		if node.Key == key then return true end
	end
	return false
end

local function removalRecord(ent)
	local state = ACE.EntityRemovalSchedulerState
	local record = state and state.Records and state.Records[ent]
	if not record then return nil end
	return {
		key = record.Key,
		due = record.Due,
		heap_present = heapHasKey(record.Key),
		timer_present = timer.Exists("ACE_EntityRemoval_" .. record.Id)
	}
end

local function makeEntity(id)
	local ent = ents.Create("ace_debris")
	if not IsValid(ent) then error("could not create " .. id) end
	ent:SetModel("models/props_junk/garbage_metalcan001a.mdl")
	ent:SetPos(Vector(0, 0, 0))
	ent:Spawn()
	tracked[#tracked + 1] = ent
	result.entities[id] = {
		spawned_at = SysTime(),
		removed = false,
		scheduler_enabled_at_spawn = scheduler.Enabled,
		request = removalRecord(ent)
	}
	ent:CallOnRemove("ACE_DebrisRuntimeProbe_" .. id, function()
		local row = result.entities[id]
		if row then
			row.removed = true
			row.removed_at = SysTime()
			row.delay_ms = (row.removed_at - row.spawned_at) * 1000
		end
	end)
	return ent
end

local function cleanup()
	timer.Remove(pollTimer)
	if scheduler and scheduler.Enabled then scheduler.Disable() end
	for _, ent in ipairs(tracked) do if IsValid(ent) then ent:Remove() end end
	timer.Simple(0.05, function()
		result.post_cleanup_heap_size = entityRemovalSize()
		result.post_cleanup_valid_entities = 0
		for _, ent in ipairs(tracked) do if IsValid(ent) then result.post_cleanup_valid_entities = result.post_cleanup_valid_entities + 1 end end
		result.elapsed_ms = (SysTime() - result.started_at) * 1000
		result.ok = #result.errors == 0 and result.post_cleanup_heap_size == 0 and result.post_cleanup_valid_entities == 0
		write("manifest.json", util.TableToJSON(result, true))
		write("done.txt", result.ok and "ok" or "error")
	end)
end

local function begin()
	scheduler = ACE and ACE.Scheduler
	if not scheduler then fail("scheduler missing") return cleanup() end
	if scheduler.Enabled then scheduler.Disable() end
	ACE.DebrisLifeTime = 0.12
	print("[ACE Debris runtime probe] begin")

	makeEntity("fallback")
	phase = 1

	timer.Create("ACE_DebrisRuntimeProbeEnable", 0.25, 1, function()
		if not result.entities.fallback.removed then fail("fallback removal did not complete before enable") end
		if not scheduler.Enable() then fail("scheduler did not enable") end
		local first = makeEntity("scheduled_first")
		local second = makeEntity("scheduled_second")
		result.scheduled_first_index = first:EntIndex()
		result.scheduled_second_index = second:EntIndex()
		phase = 2
	end)

	timer.Create("ACE_DebrisRuntimeProbeDisable", 0.33, 1, function()
		if phase ~= 2 then return end
		if scheduler.Enabled then scheduler.Disable() end
		result.after_disable_heap_size = entityRemovalSize()
		if result.after_disable_heap_size ~= 0 then fail("disable retained entity-removal work") end
		local disabled = makeEntity("disabled_fallback")
		result.disabled_index = disabled:EntIndex()
		phase = 3
	end)

	timer.Create("ACE_DebrisRuntimeProbeCancel", 0.55, 1, function()
		if phase ~= 3 then return end
		if not result.entities.disabled_fallback.removed then fail("disabled fallback did not remove") end
		if not scheduler.Enable() then fail("scheduler did not re-enable") end
		local canceled = makeEntity("canceled")
		result.entities.canceled.request_key = result.entities.canceled.request and result.entities.canceled.request.key
		canceled:Remove()
		phase = 4
		timer.Simple(0.05, function()
			result.canceled_heap_size = entityRemovalSize()
			result.canceled_record_present = ACE.EntityRemovalSchedulerState.Records[canceled] ~= nil
			result.canceled_node_present = heapHasKey(result.entities.canceled.request_key)
			if result.canceled_heap_size ~= 0 then fail("entity removal did not cancel its heap node") end
			if result.canceled_record_present or result.canceled_node_present then fail("canceled entity removal record remained") end
		end)
	end)

	timer.Create("ACE_DebrisRuntimeProbeFinish", 0.85, 1, function()
		if phase ~= 4 then return end
		if not result.entities.scheduled_first.removed or not result.entities.scheduled_second.removed then fail("scheduled debris removal did not complete") end
		if not result.entities.canceled.removed then fail("canceled entity removal callback did not run") end
		result.disabled_heap_size = entityRemovalSize()
		if result.disabled_heap_size ~= 0 then fail("final entity-removal heap was not empty") end
		cleanup()
	end)
end

hook.Add("Think", "ACE_DebrisRuntimeProbeStart", function()
	if beginRequested or CurTime() < 2 then return end
	beginRequested = true
	hook.Remove("Think", "ACE_DebrisRuntimeProbeStart")
	local ok, err = pcall(begin)
	if not ok then fail(tostring(err)) cleanup() end
end)
