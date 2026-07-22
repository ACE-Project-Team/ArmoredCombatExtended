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

	_G.ACF_CheckClips = function(entity, hit_pos)
		return entity and entity.clip == true and entity.clip_pos == hit_pos
	end

	local trace = dofile(trace_path)
	local result = trace("start", "end", filter)

	assert(calls == expected_calls, name .. ": unexpected trace count")
	assert(result.Entity == expected_entity, name .. ": wrong terminal entity")
	assert(#filter == expected_clip_count + 1, name .. ": wrong filtered clip count")
end

local clip_a = {clip = true}
clip_a.clip_pos = "clip-a"
local solid = {clip = false}
local world = {world = true}

run_case("clipped-only", {{Entity = clip_a, HitPos = "clip-a"}, {Entity = world}}, 2, world, 1)
run_case("clipped-then-solid", {{Entity = clip_a, HitPos = "clip-a"}, {Entity = solid}}, 2, solid, 1)
run_case("normal-hit", {{Entity = solid, HitPos = "solid"}}, 1, solid, 0)
run_case("world-hit", {{Entity = world, HitPos = "world"}}, 1, world, 0)
run_case("no-hit", {{Entity = nil, HitPos = "none"}}, 1, nil, 0)

local many_clips = {}
for i = 1, 50 do
	many_clips[i] = {Entity = {clip = true, clip_pos = i}, HitPos = i}
end

run_case("fifty-clip-bound", many_clips, 50, many_clips[50].Entity, 50)

print("Missile visclip trace self-test: PASS")
