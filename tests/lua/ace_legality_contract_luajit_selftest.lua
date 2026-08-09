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
local crew = read("/lua/acf/server/sv_crewseat_base.lua")
local pointEvents = read("/lua/acf/server/sv_contraptionlegality.lua")

assert(legality:find("function ACE.RequireLegal", 1, true), "synchronous legality gate is missing")
assert(legality:find("return false, \"Invalid Ent\"", 1, true), "invalid entities must fail closed")
assert(legality:find("Invalid mass", 1, true), "invalid mass must fail legality")
assert(legality:find("Linked contraption group over points limit", 1, true),
	"linked weapon/ammo contraptions must share the operational points limit")
assert(legality:find("PointsLimitEnforced", 1, true),
	"points enforcement must be controlled by the server setting")
local globals = read("/lua/autorun/acf_globals.lua")
assert(globals:find("ace_legality_pointslimit_enforced", 1, true),
	"points enforcement convar is missing")
assert(legality:find("pointQueue", 1, true), "points enforcement must traverse linked contraptions")
assert(pointEvents:find("ACEPointsOperationalCache = nil", 1, true),
	"point mutations must clear operational legality caches only on affected entities")
assert(pointEvents:find("member.AmmoLink", 1, true) and pointEvents:find("member.CrewLink", 1, true),
	"point invalidation must expand through linked weapon/ammo/crew contraptions")
assert(pointEvents:find("member.Master", 1, true),
	"point invalidation must follow reverse links from ammo and crew endpoints")
assert(legality:find("pointMemberQueue", 1, true),
	"operational legality must scan adopted orphan weapons as graph members")
assert(pointEvents:find("source.ACEPointsOperationalCache = nil", 1, true),
	"point invalidation must clear adopted orphan weapon caches at the source")
assert(pointEvents:find("affectedEntities", 1, true),
	"point invalidation must traverse linked endpoint entities, including adopted orphans")
assert(parent:find("Depth < 64", 1, true), "physical-parent traversal must be bounded")
assert(gun:find("ACE.RequireLegal(self", 1, true), "guns need a synchronous pre-fire gate")
assert(rack:find("ACE.RequireLegal(self", 1, true), "racks need a synchronous pre-fire gate")
assert(crew:find("BumpOperationalVersion", 1, true), "crew legality transitions must invalidate operational points")
assert(not gun:find("self.legal", 1, true), "gun legality scheduling must use the live Legal field")
assert(not rack:find("self.legal", 1, true), "rack legality scheduling must use the live Legal field")
assert(pointEvents:find("ACE_IsFiniteNumber", 1, true),
	"point warnings must reject non-finite transient totals")
assert(pointEvents:find("ACE_DeferPointWarningCheck", 1, true),
	"point warnings must settle after contraption transitions")
assert(pointEvents:find("ACEPointWarningCheckPending", 1, true),
	"point warning debounce must block same-tick emission")
assert(pointEvents:find("pointsLimit ~= math.huge", 1, true),
	"point warning checks must preserve the no-limit sentinel")

print("ACE legality contract LuaJIT self-test: PASS")
