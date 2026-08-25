if not SERVER then return end

include("ace/server/sv_ace_scheduler.lua")

local DIR = "ace_scheduler_runtime_probe_v1"
local result = { schema = 1, errors = {}, started_at = SysTime(), trials = {} }
local requestedSizes = { 0, 1, 10, 100, 1000, 5000, 10000 }
local repetitions = 21
file.CreateDir(DIR)

local function write(name, value)
	file.Write(DIR .. "/" .. name, value)
end

local function addError(message)
	result.errors[#result.errors + 1] = message
end

local function median(values)
	table.sort(values)
	return values[math.ceil(#values * 0.5)]
end

local function sample(size, trial)
	local scheduler = ACE and ACE.Scheduler
	if not scheduler then addError("ACE.Scheduler missing") return end

	local prefix = "ACE.LoadProbe." .. size .. "." .. trial .. "."
	local attachStart = SysTime()
	for index = 1, size do
		scheduler.Attach(prefix .. index, function() end, 0)
	end
	local attachMs = (SysTime() - attachStart) * 1000
	local runStart = SysTime()
	local stats = scheduler.Run(0)
	local runMs = (SysTime() - runStart) * 1000
	if scheduler.GetSize() ~= 0 then addError("scheduler retained work at size " .. size) end
	return attachMs, runMs, (stats.DispatchTime or 0) * 1000, stats.Ran, stats.Due
end

local function begin()
	local scheduler = ACE and ACE.Scheduler
	if not scheduler then addError("ACE.Scheduler missing at start") return end
	scheduler.Measure = true
	if scheduler.Enabled then scheduler.Disable() end

	local baseline = {}
	for trial = 1, repetitions do
		local _, runMs = sample(0, trial)
		baseline[#baseline + 1] = runMs
	end
	result.baseline_run_ms_median = median(baseline)

	for _, size in ipairs(requestedSizes) do
		local attachSamples, runSamples, dispatchSamples = {}, {}, {}
		local ran, due
		for trial = 1, repetitions do
			local attachMs, runMs, dispatchMs, sampleRan, sampleDue = sample(size, trial)
			attachSamples[#attachSamples + 1] = attachMs
			runSamples[#runSamples + 1] = runMs
			dispatchSamples[#dispatchSamples + 1] = dispatchMs
			ran, due = sampleRan, sampleDue
		end
		result.trials[#result.trials + 1] = {
			size = size,
			repetitions = repetitions,
			ran = ran,
			due = due,
			attach_ms_median = median(attachSamples),
			run_ms_median = median(runSamples),
			dispatch_ms_median = median(dispatchSamples),
			attach_ms_max = math.max(unpack(attachSamples)),
			run_ms_max = math.max(unpack(runSamples)),
			dispatch_ms_max = math.max(unpack(dispatchSamples))
		}
		if ran ~= size or due ~= size then addError("incorrect callback count at size " .. size) end
	end

	scheduler.Measure = false
	result.elapsed_ms = (SysTime() - result.started_at) * 1000
	result.ok = #result.errors == 0 and scheduler.GetSize() == 0
	write("manifest.json", util.TableToJSON(result, true))
	write("done.txt", result.ok and "ok" or "error")
end

hook.Add("InitPostEntity", "ACE_SchedulerLoadProbeStart", function()
	timer.Simple(2, begin)
end)
