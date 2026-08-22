local root = assert(arg[1], "usage: active_input_persistence_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local text = file:read("*a")
	file:close()
	return text
end

local function assertEqual(actual, expected, label)
	assert(actual == expected, ("%s: expected %s, got %s"):format(label, tostring(expected), tostring(actual)))
end

local shared = read("lua/ace/shared/sh_ace_functions.lua")
shared = shared:gsub("\r\n", "\n")
local start = assert(shared:find("local function GetDefaultActiveInput(ent,", 1, true))
local finish = assert(shared:find("\n\n-- Radar/IRST-specific functions", start, true))

ACE = {}
SERVER = false

function IsValid(ent)
	return ent and ent.valid == true
end

assert(loadstring(shared:sub(start, finish - 1), "active input helper"))()

local ent = { valid = true, Legal = true, Inputs = { Active = {} } }
local input = ent.Inputs.Active

assertEqual(ACE.GetDefaultActiveInputState(ent), true, "unwired default is active")
assertEqual(ACE.SetDefaultActiveInputState(ent, 0), true, "unwired off command is accepted")
assertEqual(ACE.GetDefaultActiveInputState(ent), false, "unwired off command persists")
assertEqual(ACE.SetDefaultActiveInputState(ent, 1), true, "unwired on command is accepted")
assertEqual(ACE.GetDefaultActiveInputState(ent), true, "unwired on command persists")

input.Src = true
input.Value = 0
assertEqual(ACE.SetDefaultActiveInputState(ent, 0), false, "wired off command is rejected")
assertEqual(ACE.GetDefaultActiveInputState(ent), false, "wire value is authoritative")
input.Src = nil
assertEqual(ACE.GetDefaultActiveInputState(ent), true, "stored state returns after wire removal")

ent.Legal = false
assertEqual(ACE.GetDefaultActiveInputState(ent), false, "illegal entities cannot be active")
ent.Legal = true
assertEqual(ACE.GetDefaultActiveInputState(ent), true, "stored state returns after legality recovery")

local engine = read("lua/entities/acf_engine/init.lua")
assert(engine:find("ACE.HasDefaultActiveInputState(self)", 1, true), "engine refreshes explicit stored state")
assert(engine:find("ACE.GetDefaultActiveInputState(self) and 1 or 0", 1, true), "engine legality recovery preserves requested off")
assert(read("lua/entities/gmod_wire_expression2/core/custom/acf.lua"):find("ACE.SetDefaultActiveInputState(this, on)", 1, true), "E2 stores state")
assert(read("lua/starfall/libs_sv/acf.lua"):find("ACE.SetDefaultActiveInputState(this, on and 1 or 0)", 1, true), "Starfall stores state")

print("ACF Active persistence self-test: PASS (16 assertions)")
