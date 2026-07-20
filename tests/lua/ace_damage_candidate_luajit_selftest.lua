local root = assert(arg[1], "usage: ace_damage_candidate_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local source = assert(io.open(root .. "/lua/acf/server/sv_acfdamage.lua", "r")):read("*a")
local start = assert(source:find("local function ACF_InsertNearestDamageCandidate"))
local finish = assert(source:find("function ACF_HEFind", start))
local chunk = assert(loadstring(source:sub(start, finish - 1) .. "\nreturn ACF_InsertNearestDamageCandidate, ACF_SortDamageCandidates"))
local insert, sort = chunk()

local function entity(index)
	return { EntIndex = function() return index end }
end

local targets, distances, indices = {}, {}, {}
for i = 1, 5 do
	local accepted = insert(targets, distances, indices, entity(i), i * 10, 3)
	assert(accepted == (i <= 3))
end
assert(#targets == 3)

assert(insert(targets, distances, indices, entity(99), 1, 3))
sort(targets, distances, indices)
assert(#targets == 3)
assert(targets[1]:EntIndex() == 99)
assert(targets[2]:EntIndex() == 1)
assert(targets[3]:EntIndex() == 2)

local pending, pendingDistances, pendingIndices = {}, {}, {}
local fresh, freshDistances, freshIndices = {}, {}, {}
for _, item in ipairs({ { 1, 1 }, { 3, 3 }, { 5, 5 } }) do
	assert(insert(pending, pendingDistances, pendingIndices, entity(item[1]), item[2], 5))
end
for _, item in ipairs({ { 2, 2 }, { 4, 4 }, { 6, 5 }, { 8, 6 } }) do
	assert(insert(fresh, freshDistances, freshIndices, entity(item[1]), item[2], 4))
end
sort(pending, pendingDistances, pendingIndices)
sort(fresh, freshDistances, freshIndices)
assert(#pending <= 5)
assert(#fresh <= 4)
assert(#pending + #fresh <= 9)

local active = { 1, 2, 3, 4 }
local frame = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
local activeCount = #active
local currentSlot = 0
local processed = {}

local function removeBullet(index)
	for slot = 1, activeCount do
		if active[slot] == index then
			local last = active[activeCount]
			active[slot] = last
			active[activeCount] = nil
			activeCount = activeCount - 1
			if slot < currentSlot then currentSlot = slot end
			return
		end
	end
end

local slot = 1
while slot <= activeCount do
	currentSlot = slot
	local index = active[slot]
	if frame[index] ~= 1 then
		frame[index] = 1
		processed[index] = (processed[index] or 0) + 1
		if index == 3 then removeBullet(1) end
		if index == 4 then removeBullet(4) end
	end
	if currentSlot < slot then
		slot = currentSlot
	elseif active[slot] == index then
		slot = slot + 1
	end
end
assert(processed[1] == 1 and processed[2] == 1 and processed[3] == 1 and processed[4] == 1)

local merged = {}
local pendingAt, freshAt = 1, 1
while pendingAt <= #pending or freshAt <= #fresh do
	local usePending = freshAt > #fresh
	if not usePending and pendingAt <= #pending then
		usePending = pendingDistances[pendingAt] < freshDistances[freshAt]
		if pendingDistances[pendingAt] == freshDistances[freshAt] then
			usePending = pendingIndices[pendingAt] <= freshIndices[freshAt]
		end
	end
	if usePending then
		merged[#merged + 1] = pending[pendingAt]:EntIndex()
		pendingAt = pendingAt + 1
	else
		merged[#merged + 1] = fresh[freshAt]:EntIndex()
		freshAt = freshAt + 1
	end
end
assert(#merged == #pending + #fresh)
assert(merged[1] == 1 and merged[2] == 2 and merged[3] == 3 and merged[4] == 4)
assert(merged[5] == 5 and merged[6] == 6 and merged[7] == 8)

print("ACE damage candidate LuaJIT self-test: PASS")
