local root = assert(arg[1], "usage: ace_scheduler_luajit_stress_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

CLIENT = false
hook = { Add = function() end, Remove = function() end }
function CurTime() return 0 end

dofile(root .. "/lua/ace/server/sv_ace_scheduler.lua")
local scheduler = ACE.Scheduler

local function reset()
	for key in pairs(scheduler.Nodes) do scheduler.Detach(key) end
	scheduler.Heap = {}
	scheduler.Sequence = 0
	scheduler.Running = false
	scheduler.Enabled = false
	scheduler.LastStats = {}
end

local function earlier(left, right)
	if left.Due ~= right.Due then return left.Due < right.Due end
	if left.Priority ~= right.Priority then return left.Priority < right.Priority end
	return left.Sequence < right.Sequence
end

local function assertHeap()
	for index, node in ipairs(scheduler.Heap) do
		assert(node.Index == index, "heap index reference drifted")
		local parent = math.floor(index * 0.5)
		if parent >= 1 then assert(not earlier(node, scheduler.Heap[parent]), "heap order invariant failed") end
		assert(scheduler.Nodes[node.Key] == node, "heap node lost its key mapping")
	end
	for _, node in pairs(scheduler.Nodes) do
		assert(node.Active and node.Index > 0, "active node is not attached")
		assert(scheduler.Heap[node.Index] == node, "node index does not point back to node")
	end
end

local function random(seed)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed, seed / 2147483648
end

reset()
local seed = 8675309
for round = 1, 40 do
	for step = 1, 250 do
		local value
	seed, value = random(seed)
	local key = "node-" .. ((seed + step * 17) % 64)
	local due
	local operation
	seed, operation = random(seed)
	due = math.floor(operation * 200)
	local priority
	seed, value = random(seed)
	priority = math.floor(value * 7) - 3

	if operation < 0.34 then
		scheduler.Attach(key, function() end, due, { priority = priority })
	elseif operation < 0.59 then
		scheduler.Reschedule(key, due)
	elseif operation < 0.77 then
		scheduler.Detach(key)
	else
		local now = due
		scheduler.Run(now, 7)
	end
	assertHeap()
	end

	local now = round * 200
	scheduler.Run(now, 1000)
	assertHeap()
end

print("ACE scheduler LuaJIT randomized heap stress: PASS")
