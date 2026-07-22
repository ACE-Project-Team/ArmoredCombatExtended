local root = assert(arg[1], "usage: missile_visclip_selftest.lua <ACE repo>")
local trace_path = root .. "/lua/acf/shared/sh_ace_missiletrace.lua"

local function run_case(name, results, expected_calls, expected_entity, expected_clip_count)
	local calls = 0
	local filter = {"missile"}
	local trace_index = 0

	_G.util = {
		TraceLine = function(data)
			calls = calls + 1
			trace_index = trace_index + 1
			local result = results[trace_index]
			assert(result, name .. ": trace loop exceeded the supplied results")
			assert(data.filter == filter, name .. ": trace filter table was not reused")
			return result
		end
	}

	_G.ACF_CheckClips = function(entity)
		return entity and entity.clip == true
	end

	local trace = dofile(trace_path)
	local result = trace("start", "end", filter)

	assert(calls == expected_calls, name .. ": unexpected trace count")
	assert(result.Entity == expected_entity, name .. ": wrong terminal entity")
	assert(#filter == expected_clip_count + 1, name .. ": wrong filtered clip count")
end

local clip_a = {clip = true}
local clip_b = {clip = true}
local solid = {clip = false}
local world = {clip = false}

run_case("clipped-only", {{Entity = clip_a}, {Entity = world}}, 2, world, 1)
run_case("clipped-then-solid", {{Entity = clip_a}, {Entity = solid}}, 2, solid, 1)
run_case("normal-hit", {{Entity = solid}}, 1, solid, 0)
run_case("world-or-no-hit", {{Entity = false}}, 1, false, 0)

local many_clips = {}
for i = 1, 50 do
	many_clips[i] = {Entity = {clip = true}}
end

run_case("fifty-clip-bound", many_clips, 50, many_clips[50].Entity, 50)

print("Missile visclip trace self-test: PASS")
