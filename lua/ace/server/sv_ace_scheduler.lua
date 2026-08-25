if CLIENT then return end

ACE = ACE or {}

local PreviousScheduler = ACE.Scheduler
if PreviousScheduler and PreviousScheduler.Enabled and PreviousScheduler.Disable then
	PreviousScheduler.Disable()
elseif PreviousScheduler and PreviousScheduler.Enabled and hook and hook.Remove then
	hook.Remove("Think", "ACE_SchedulerDispatch")
end

-- Prototype only: callers own cadence and must explicitly call Reschedule.
-- This module does not replace engine hooks, timers, physics, or lifecycle callbacks.
local Clock = SysTime or os.clock

local Scheduler = {
	Heap = {},
	Nodes = {},
	Sequence = 0,
	Running = false,
	Enabled = false,
	Measure = false,
	LastStats = {},
	Adapters = ACE.SchedulerAdapterDefinitions or {},
	AdapterSequence = 0,
}

ACE.Scheduler = Scheduler
ACE.SchedulerAdapterDefinitions = Scheduler.Adapters

for _, adapter in pairs(Scheduler.Adapters) do
	if type(adapter.Order) == "number" and adapter.Order > Scheduler.AdapterSequence then
		Scheduler.AdapterSequence = adapter.Order
	end
end

local function IsEarlier(left, right)
	if left.Due ~= right.Due then return left.Due < right.Due end
	if left.Priority ~= right.Priority then return left.Priority < right.Priority end
	return left.Sequence < right.Sequence
end

local function Swap(first, second)
	local heap = Scheduler.Heap
	local left = heap[first]
	local right = heap[second]

	heap[first], heap[second] = right, left
	left.Index, right.Index = second, first
end

local function SiftUp(index)
	local heap = Scheduler.Heap

	while index > 1 do
		local parent = math.floor(index * 0.5)
		if not IsEarlier(heap[index], heap[parent]) then break end

		Swap(index, parent)
		index = parent
	end
end

local function SiftDown(index)
	local heap = Scheduler.Heap
	local count = #heap

	while true do
		local left = index * 2
		if left > count then return end

		local child = left
		local right = left + 1
		if right <= count and IsEarlier(heap[right], heap[left]) then
			child = right
		end

		if not IsEarlier(heap[child], heap[index]) then return end

		Swap(index, child)
		index = child
	end
end

local function Push(node)
	local heap = Scheduler.Heap

	heap[#heap + 1] = node
	node.Index = #heap
	SiftUp(node.Index)
end

local function RemoveAt(index)
	local heap = Scheduler.Heap
	local count = #heap
	local node = heap[index]
	local replacement = heap[count]

	heap[count] = nil
	node.Index = 0

	if index == count then return node end

	heap[index] = replacement
	replacement.Index = index

	if index > 1 and IsEarlier(replacement, heap[math.floor(index * 0.5)]) then
		SiftUp(index)
	else
		SiftDown(index)
	end

	return node
end

local function PushNode(node, due)
	Scheduler.Sequence = Scheduler.Sequence + 1
	node.Due = due
	node.Sequence = Scheduler.Sequence
	node.Active = true
	Push(node)
end

local function IsFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function ValidateDue(due)
	if not IsFiniteNumber(due) then error("ACE.Scheduler due time must be finite", 3) end
end

local function ValidatePriority(priority)
	if not IsFiniteNumber(priority) or priority % 1 ~= 0 then
		error("ACE.Scheduler priority must be a finite integer", 3)
	end
end

local function ForEachAdapter(callback)
	local keys = {}
	for key in pairs(Scheduler.Adapters) do keys[#keys + 1] = key end
	table.sort(keys, function(left, right)
		local leftType = type(left)
		local rightType = type(right)
		if leftType ~= rightType then return leftType < rightType end
		if leftType == "number" and left ~= right then
			local leftNaN = left ~= left
			local rightNaN = right ~= right
			if leftNaN ~= rightNaN then return not leftNaN end
			if not leftNaN then return left < right end
		end
		if leftType == "string" and left ~= right then return left < right end

		local leftAdapter = Scheduler.Adapters[left]
		local rightAdapter = Scheduler.Adapters[right]
		local leftOrder = leftAdapter.Order or 0
		local rightOrder = rightAdapter.Order or 0
		if leftOrder ~= rightOrder then return leftOrder < rightOrder end
		return tostring(left) < tostring(right)
	end)

	for index = 1, #keys do
		callback(Scheduler.Adapters[keys[index]], keys[index])
	end
end

function Scheduler.Attach(key, callback, due, options)
	if key == nil then error("ACE.Scheduler key must not be nil", 2) end
	if type(callback) ~= "function" then error("ACE.Scheduler callback must be a function", 2) end
	ValidateDue(due)
	local priority = options and options.priority or 0
	ValidatePriority(priority)

	if Scheduler.Nodes[key] then Scheduler.Detach(key) end

	local node = {
		Key = key,
		Callback = callback,
		Priority = priority,
		RetryOnError = options and options.retryOnError == true or false,
		Generation = 1,
		Index = 0,
		Active = false,
		InBatch = false,
	}

	Scheduler.Nodes[key] = node
	PushNode(node, due)
	return node
end

function Scheduler.Detach(key)
	local node = Scheduler.Nodes[key]
	if not node then return false end

	Scheduler.Nodes[key] = nil
	node.Generation = node.Generation + 1
	node.Active = false
	node.InBatch = false

	if node.Index > 0 then RemoveAt(node.Index) end
	return true
end

function Scheduler.Reschedule(key, due)
	ValidateDue(due)

	local node = Scheduler.Nodes[key]
	if not node then return false end

	if node.Index > 0 then RemoveAt(node.Index) end
	node.InBatch = false
	PushNode(node, due)
	return true
end

function Scheduler.GetNode(key)
	return Scheduler.Nodes[key]
end

function Scheduler.RegisterAdapter(key, enable, disable)
	if key == nil then error("ACE.Scheduler adapter key must not be nil", 2) end
	if type(enable) ~= "function" or type(disable) ~= "function" then
		error("ACE.Scheduler adapter callbacks must be functions", 2)
	end

	Scheduler.AdapterSequence = Scheduler.AdapterSequence + 1
	local previous = Scheduler.Adapters[key]
	Scheduler.Adapters[key] = {
		Enable = enable,
		Disable = disable,
		Order = previous and previous.Order or Scheduler.AdapterSequence,
	}
	if Scheduler.Enabled then enable() end
	return true
end

function Scheduler.GetSize()
	return #Scheduler.Heap
end

function Scheduler.Run(now, maxCallbacks)
	ValidateDue(now)
	if maxCallbacks ~= nil and (not IsFiniteNumber(maxCallbacks) or maxCallbacks < 1 or maxCallbacks % 1 ~= 0) then
		error("ACE.Scheduler maxCallbacks must be a positive number", 2)
	end
	if Scheduler.Running then error("ACE.Scheduler cannot run recursively", 2) end

	local batch = {}
	local limit = maxCallbacks or math.huge

	while #batch < limit do
		local node = Scheduler.Heap[1]
		if not node or node.Due > now then break end

		RemoveAt(1)
		node.Active = false
		node.InBatch = true
		batch[#batch + 1] = { Node = node, Due = node.Due }
	end

	local stats = {
		Now = now,
		Due = #batch,
		Ran = 0,
		Skipped = 0,
		Errors = 0,
		Late = 0,
		MaxLateness = 0,
		DispatchTime = 0,
		CallbackTime = 0,
		ErrorMessages = {},
	}

	Scheduler.LastStats = stats
	Scheduler.Running = true
	local dispatchStart = Scheduler.Measure and Clock()

	for index = 1, #batch do
		local event = batch[index]
		local node = event.Node
		local current = Scheduler.Nodes[node.Key]

		if current == node and node.Generation == current.Generation and node.InBatch then
			node.InBatch = false
			local lateness = now - event.Due
			if lateness > 0 then
				stats.Late = stats.Late + 1
				if lateness > stats.MaxLateness then stats.MaxLateness = lateness end
			end

			local callbackStart = Scheduler.Measure and Clock()
			local ok, errorMessage = pcall(node.Callback, node.Key, now, event.Due)
			if callbackStart then stats.CallbackTime = stats.CallbackTime + Clock() - callbackStart end
			stats.Ran = stats.Ran + 1

			if not ok then
				stats.Errors = stats.Errors + 1
				stats.ErrorMessages[#stats.ErrorMessages + 1] = tostring(errorMessage)
				if Scheduler.Nodes[node.Key] == node then
					if node.RetryOnError then
						if node.Index == 0 then PushNode(node, now) end
					else
						Scheduler.Detach(node.Key)
					end
				end
			elseif Scheduler.Nodes[node.Key] == node and node.Index == 0 then
				-- Successful callbacks are one-shot unless they explicitly reschedule.
				-- Retire the node so Nodes cannot retain completed work indefinitely.
				Scheduler.Nodes[node.Key] = nil
				node.Generation = node.Generation + 1
			end
		elseif current == node and node.Generation == current.Generation then
			stats.Skipped = stats.Skipped + 1
		end
	end

	if dispatchStart then stats.DispatchTime = Clock() - dispatchStart end
	Scheduler.Running = false
	return stats
end

function Scheduler.Enable()
	if Scheduler.Enabled then return false end

	Scheduler.Enabled = true
	hook.Add("Think", "ACE_SchedulerDispatch", function()
		Scheduler.Run(CurTime())
	end)
	ForEachAdapter(function(adapter) adapter.Enable() end)

	return true
end

function Scheduler.Disable()
	if not Scheduler.Enabled then return false end

	Scheduler.Enabled = false
	ForEachAdapter(function(adapter) adapter.Disable() end)
	hook.Remove("Think", "ACE_SchedulerDispatch")
	return true
end
