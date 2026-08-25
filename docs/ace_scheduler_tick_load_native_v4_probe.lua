if not SERVER then return end

include("ace/server/sv_ace_scheduler.lua")
RunConsoleCommand("sv_hibernate_think", "1")

local DIR = "ace_scheduler_runtime_probe_v1"
local result = { schema = 1, errors = {}, started_at = SysTime(), phases = {} }
local scheduler = ACE and ACE.Scheduler
local workloads = { 0, 1000, 5000, 10000 }
local warmupTicks = 10
local measuredTicks = 60
local phaseIndex = 1
local phaseTick = 0
local lastTick
local activePhase
local activeSamples, activeWorkSamples, activeDispatchSamples = {}, {}, {}
local callback = function() end
file.CreateDir(DIR)

local function write(name, value) file.Write(DIR .. "/" .. name, value) end
local function addError(message) result.errors[#result.errors + 1] = message end
local function median(values)
	if #values == 0 then return 0 end
	table.sort(values)
	return values[math.ceil(#values * 0.5)]
end
local function maxValue(values)
	if #values == 0 then return 0 end
	return math.max(unpack(values))
end

local function finishPhase()
	result.phases[#result.phases + 1] = {
		size = activePhase,
		warmup_ticks = warmupTicks,
		measured_ticks = #activeSamples,
		tick_interval_ms_median = median(activeSamples),
		tick_interval_ms_max = maxValue(activeSamples),
		scheduler_work_ms_median = median(activeWorkSamples),
		scheduler_work_ms_max = maxValue(activeWorkSamples),
		dispatch_ms_median = median(activeDispatchSamples),
		dispatch_ms_max = maxValue(activeDispatchSamples)
	}
	phaseIndex = phaseIndex + 1
	phaseTick = 0
	lastTick = nil
	activeSamples, activeWorkSamples, activeDispatchSamples = {}, {}, {}
end

local function startPhase()
	activePhase = workloads[phaseIndex]
	if not activePhase then
		hook.Remove("Tick", "ACE_SchedulerTickLoadProbe")
		if scheduler and scheduler.GetSize() ~= 0 then addError("scheduler retained final work") end
		result.elapsed_ms = (SysTime() - result.started_at) * 1000
		result.ok = #result.errors == 0 and scheduler ~= nil and scheduler.GetSize() == 0
		write("manifest.json", util.TableToJSON(result, true))
		write("done.txt", result.ok and "ok" or "error")
		return
	end
	activeSamples, activeWorkSamples, activeDispatchSamples = {}, {}, {}
end

local function runPhase()
	if not scheduler then addError("ACE.Scheduler missing") return end
	local tickNow = SysTime()
	if lastTick then
		local intervalMs = (tickNow - lastTick) * 1000
		if phaseTick > warmupTicks then activeSamples[#activeSamples + 1] = intervalMs end
	end
	lastTick = tickNow
	phaseTick = phaseTick + 1

	local workStart = SysTime()
	local stats
	if activePhase > 0 then
		local prefix = "ACE.TickLoad." .. activePhase .. "." .. phaseTick .. "."
		for index = 1, activePhase do scheduler.Attach(prefix .. index, callback, CurTime()) end
		scheduler.Measure = true
		stats = scheduler.Run(CurTime())
		local workMs = (SysTime() - workStart) * 1000
		if phaseTick > warmupTicks then
			activeWorkSamples[#activeWorkSamples + 1] = workMs
			activeDispatchSamples[#activeDispatchSamples + 1] = (stats.DispatchTime or 0) * 1000
		end
		if stats.Ran ~= activePhase or scheduler.GetSize() ~= 0 then addError("incorrect drain at size " .. activePhase) end
	end

	if phaseTick >= warmupTicks + measuredTicks then
		finishPhase()
		startPhase()
	end
end

hook.Add("Tick", "ACE_SchedulerTickLoadProbe", function()
	if not activePhase then startPhase() end
	runPhase()
end)

hook.Add("InitPostEntity", "ACE_SchedulerTickLoadProbeStart", function()
	timer.Simple(2, function()
		if not scheduler then addError("ACE.Scheduler missing after load") end
		startPhase()
	end)
end)
