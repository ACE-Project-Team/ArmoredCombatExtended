local root = assert(arg[1], "usage: ace_rack_burst_contract_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local file = assert(io.open(root .. "/lua/entities/acf_rack/init.lua", "r"))
local source = file:read("*a")
file:close()

assert(source:find('"Burst ("', 1, true), "rack needs a Burst Wire input")
assert(source:find("BurstMode", 1, true), "rack needs persistent burst mode state")
assert(source:find("FireInputActive", 1, true), "burst mode must use Fire rising edges")
assert(source:find("BurstRemaining", 1, true), "burst mode needs a finite shot quota")
assert(source:find("return true", 1, true), "successful missile launches must report success")
assert(source:find("BurstDescription", 1, true), "rack overlay must expose burst mode")
assert(source:find("math.floor", 1, true), "burst input must be normalized to whole shots")

print("ACE rack burst contract LuaJIT self-test: PASS")
