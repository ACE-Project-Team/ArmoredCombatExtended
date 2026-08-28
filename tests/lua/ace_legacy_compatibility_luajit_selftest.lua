local root = assert(arg[1], "usage: ace_legacy_compatibility_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local function exists(path)
	local file = io.open(root .. path, "r")
	if file then file:close() return true end
	return false
end

assert(not exists("/lua/autorun/ace_legacy_tools.lua"), "legacy tool bridge remains")
assert(not exists("/lua/autorun/ace_legacy_convars.lua"), "legacy convar bridge remains")

local vehicles = assert(io.open(root .. "/lua/autorun/ace_legacy_vehicles.lua", "r")):read("*a")
assert(vehicles:find('key == "acf_pod"', 1, true), "legacy pod vehicle alias is missing")
assert(vehicles:find('key == "acf_pilotseat"', 1, true), "legacy pilot seat alias is missing")

local globals = assert(io.open(root .. "/lua/autorun/acf_globals.lua", "r")):read("*a")
assert(globals:find("__ACECompatibilityView", 1, true), "ACF compatibility metatable is missing")
assert(globals:find("ACF_MuzzleVelocity", 1, true), "legacy ACF calculation bridge is missing")
assert(globals:find("ACF_Kinetic", 1, true), "legacy ACF kinetic bridge is missing")
assert(not globals:find("rawget(_G, \"ACE_\"", 1, true), "ACE metatable fallback remains")

print("ACE namespace compatibility self-test: PASS")
