local root = assert(arg[1], "usage: ace_legacy_compatibility_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local function exists(path)
	local file = io.open(root .. path, "r")
	if file then file:close() return true end
	return false
end

assert(not exists("/lua/autorun/ace_legacy_tools.lua"), "legacy tool bridge remains")
assert(not exists("/lua/autorun/ace_legacy_vehicles.lua"), "legacy vehicle bridge remains")
assert(not exists("/lua/autorun/ace_legacy_convars.lua"), "legacy convar bridge remains")

local globals = assert(io.open(root .. "/lua/autorun/acf_globals.lua", "r")):read("*a")
assert(not globals:find("LegacyCompatibility", 1, true), "global legacy compatibility remains")
assert(not globals:find("__ACECompatibilityView", 1, true), "ACF compatibility metatable remains")
assert(not globals:find("rawget(_G, \"ACE_\"", 1, true), "ACE metatable fallback remains")

print("ACE namespace compatibility-removal LuaJIT self-test: PASS")
