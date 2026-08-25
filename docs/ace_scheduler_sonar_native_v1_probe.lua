if not SERVER then return end

local DIR = "ace_debris_runtime_probe_v1"
local result = { schema = 1, errors = {}, started_at = SysTime(), records = {} }
file.CreateDir(DIR)

local function write(name, value) file.Write(DIR .. "/" .. name, value) end
local function fail(message) result.errors[#result.errors + 1] = message end

local scheduler
local beginRequested = false
local tracked = {}

local function heapHasKey(key)
	for _, node in ipairs(scheduler.Heap) do
		if node.Key == key then return true end
	end
	return false
end

local function sonarHeapSize()
	local count = 0
	for _, node in ipairs(scheduler.Heap) do
		if string.sub(node.Key, 1, #"ACE.SonarTravelSound.") == "ACE.SonarTravelSound." then count = count + 1 end
	end
	return count
end

local function recordInfo(id)
	local record = ACE.SonarTravelSoundSchedulerState.Records[id]
	if not record then return nil end
	return {
		id = record.Id,
		key = record.Key,
		due = record.Due,
		heap_present = heapHasKey(record.Key),
		timer_present = timer.Exists("ACE_SonarTravelSound_" .. record.Id)
	}
end

local function makeBase()
	local ent = ents.Create("prop_physics")
	if not IsValid(ent) then error("could not create base entity") end
	ent:SetModel("models/props_junk/garbage_metalcan001a.mdl")
	ent:SetPos(Vector(0, 0, 0))
	ent:Spawn()
	tracked[#tracked + 1] = ent
	return ent
end

local function latestRecord()
	return ACE.SonarTravelSoundSchedulerState.NextId
end

local function cleanup()
	if scheduler and scheduler.Enabled then scheduler.Disable() end
	for _, ent in ipairs(tracked) do if IsValid(ent) then ent:Remove() end end
	timer.Simple(0.05, function()
		result.post_cleanup_heap_size = scheduler and sonarHeapSize() or -1
		result.post_cleanup_records = 0
		for _ in pairs(ACE.SonarTravelSoundSchedulerState.Records) do result.post_cleanup_records = result.post_cleanup_records + 1 end
		result.post_cleanup_valid_entities = 0
		for _, ent in ipairs(tracked) do if IsValid(ent) then result.post_cleanup_valid_entities = result.post_cleanup_valid_entities + 1 end end
		result.elapsed_ms = (SysTime() - result.started_at) * 1000
		result.ok = #result.errors == 0 and result.post_cleanup_heap_size == 0 and result.post_cleanup_records == 0 and result.post_cleanup_valid_entities == 0
		write("manifest.json", util.TableToJSON(result, true))
		write("done.txt", result.ok and "ok" or "error")
	end)
end

local function begin()
	scheduler = ACE and ACE.Scheduler
	if not scheduler or not ACE.ScheduleSonarTravelSound then fail("sonar scheduler missing") return cleanup() end
	if scheduler.Enabled then scheduler.Disable() end

	local fallback = makeBase()
	if not ACE.ScheduleSonarTravelSound(fallback, 0.08, Vector(0, 0, 0), Vector(10, 0, 0), "acf_extra/ACE/sensors/Sonar/coldwaters.wav", 101, 0.75, 130, CHAN_WEAPON, Color(255, 0, 183), 0.08) then fail("fallback request rejected") end
	local fallbackId = latestRecord()
	result.records.fallback = recordInfo(fallbackId)
	if result.records.fallback.heap_present or not result.records.fallback.timer_present then fail("fallback did not use timer path") end

	if not scheduler.Enable() then fail("scheduler did not enable") end
	local heap = makeBase()
	if not ACE.ScheduleSonarTravelSound(heap, 0.2, Vector(0, 0, 0), Vector(20, 0, 0), "acf_extra/ACE/sensors/Sonar/coldwaters.wav", 110, 0.5, 100, CHAN_AUTO, Color(43, 0, 255), 0.2) then fail("heap request rejected") end
	local heapId = latestRecord()
	result.records.heap = recordInfo(heapId)
	if not result.records.heap.heap_present or result.records.heap.timer_present then fail("enabled request did not use heap path") end

	if not scheduler.Disable() then fail("scheduler did not disable") end
	result.after_disable_heap_size = sonarHeapSize()
	local disabledInfo = recordInfo(heapId)
	result.records.disabled = disabledInfo
	if result.after_disable_heap_size ~= 0 or not disabledInfo.timer_present or disabledInfo.heap_present then fail("disable did not restore timer fallback") end
	if not scheduler.Enable() then fail("scheduler did not re-enable") end
	result.records.reenabled = recordInfo(heapId)
	if not result.records.reenabled.heap_present or result.records.reenabled.timer_present then fail("re-enable did not restore heap path") end

	local invalid = makeBase()
	if not ACE.ScheduleSonarTravelSound(invalid, 0.1, Vector(0, 0, 0), Vector(30, 0, 0), "acf_extra/ACE/sensors/Sonar/coldwaters.wav", 90, 0.4, 100, CHAN_AUTO, Color(0, 255, 38), 0.1) then fail("invalidation request rejected") end
	local invalidId = latestRecord()
	invalid:Remove()
	timer.Simple(0.2, function()
		result.invalid_record_present_after_due = ACE.SonarTravelSoundSchedulerState.Records[invalidId] ~= nil
		if result.invalid_record_present_after_due then fail("invalid entity record survived delivery") end
	end)

	timer.Simple(0.35, function()
		result.heap_after_delivery = sonarHeapSize()
		if result.heap_after_delivery ~= 0 then fail("sonar heap retained delivered work") end
		cleanup()
	end)
end

hook.Add("Think", "ACE_SonarRuntimeProbeStart", function()
	if beginRequested or CurTime() < 2 then return end
	beginRequested = true
	hook.Remove("Think", "ACE_SonarRuntimeProbeStart")
	local ok, err = pcall(begin)
	if not ok then fail(tostring(err)) cleanup() end
end)
