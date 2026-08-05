local root = assert(arg[1], "usage: ace_legality_all_entities_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local function read(path)
	local file = assert(io.open(root .. path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local legality = read("/lua/acf/server/sv_legality.lua")
assert(legality:find("function ACE.RequireEntityLegal", 1, true), "entity legality gate is missing")
assert(legality:find("function ACE.WithMutationScope", 1, true), "mutation scope is missing")
assert(legality:find("function ENTITY:SetModel", 1, true), "model mutation barrier is missing")
assert(legality:find("function ENTITY:SetCollisionGroup", 1, true), "collision-group barrier is missing")
assert(legality:find("Illegal physical parent", 1, true), "parent legality is missing")

local entities = {
	"ace_ecm", "ace_irst", "ace_rwr_dir", "ace_rwr_sphere", "ace_searchradar",
	"ace_sonar", "ace_trackingradar", "acf_ammo", "acf_engine", "acf_fueltank",
	"acf_gearbox", "acf_gun", "acf_missileradar", "acf_rack",
}

for _, class in ipairs(entities) do
	local source = read("/lua/entities/" .. class .. "/init.lua")
	assert(not source:find("ACE_CheckLegal(", 1, true), class .. " bypasses the canonical legality gate")
	assert(not source:find("self.legal", 1, true), class .. " reads the stale lowercase legality field")
	assert(source:find("ACE.RequireLegal", 1, true), class .. " has no synchronous legality check")
end

print("ACE all-entity legality LuaJIT self-test: PASS")
