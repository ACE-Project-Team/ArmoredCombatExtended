local root = assert(arg[1], "usage: ace_legality_contract_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local function read(path)
	local file = assert(io.open(root .. path, "r"))
	local value = file:read("*a")
	file:close()
	return value
end

local legality = read("/lua/acf/server/sv_legality.lua")
local parent = read("/lua/acf/shared/sh_ace_functions.lua")
local gun = read("/lua/entities/acf_gun/init.lua")
local rack = read("/lua/entities/acf_rack/init.lua")

assert(legality:find("function ACE.RequireLegal", 1, true), "synchronous legality gate is missing")
assert(legality:find("return false, \"Invalid Ent\"", 1, true), "invalid entities must fail closed")
assert(legality:find("Invalid mass", 1, true), "invalid mass must fail legality")
assert(parent:find("Depth < 64", 1, true), "physical-parent traversal must be bounded")
assert(gun:find("ACE.RequireLegal(self", 1, true), "guns need a synchronous pre-fire gate")
assert(rack:find("ACE.RequireLegal(self", 1, true), "racks need a synchronous pre-fire gate")
assert(not gun:find("self.legal", 1, true), "gun legality scheduling must use the live Legal field")
assert(not rack:find("self.legal", 1, true), "rack legality scheduling must use the live Legal field")

print("ACE legality contract LuaJIT self-test: PASS")
