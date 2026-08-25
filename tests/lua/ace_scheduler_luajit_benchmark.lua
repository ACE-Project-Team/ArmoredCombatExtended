local root = assert(arg[1], "usage: ace_scheduler_luajit_benchmark.lua <ACE repo> [callbacks] [rounds]")
root = root:gsub("\\\\", "/"):gsub("/$", "")
local callbacks = tonumber(arg[2]) or 1000
local rounds = tonumber(arg[3]) or 100

CLIENT = false
hook = { Add = function() end, Remove = function() end }
dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local scheduler = ACE.Scheduler

local function run(label, callback)
	local started = os.clock()
	callback()
	local elapsed = os.clock() - started
	print(string.format("%s callbacks=%d rounds=%d seconds=%.9f us_per_callback=%.3f", label, callbacks, rounds, elapsed, elapsed * 1000000 / (callbacks * rounds)))
end

local directCount = 0
local directCallback = function() directCount = directCount + 1 end
run("direct", function()
	for _ = 1, rounds do
		for _ = 1, callbacks do directCallback() end
	end
end)

local queuedCount = 0
local queuedCallback = function() queuedCount = queuedCount + 1 end
run("heap_attach_run", function()
	for _ = 1, rounds do
		for index = 1, callbacks do scheduler.Attach(index, queuedCallback, 0) end
		scheduler.Run(0)
	end
end)

assert(directCount == callbacks * rounds, "direct benchmark count mismatch")
assert(queuedCount == callbacks * rounds, "scheduler benchmark count mismatch")
assert(scheduler.GetSize() == 0, "scheduler benchmark left queued work")
print("These are LuaJIT scheduler overhead measurements, not server-lag measurements.")
