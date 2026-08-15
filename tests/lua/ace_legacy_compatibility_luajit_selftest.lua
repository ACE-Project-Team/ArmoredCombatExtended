local root = assert(arg[1], "usage: ace_legacy_compatibility_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local function read(path)
	local file = assert(io.open(root .. path, "r"))
	local source = file:read("*a")
	file:close()
	return source
end

local toolBridge = read("/lua/autorun/ace_legacy_tools.lua")
assert(toolBridge:find("local LegacyTools =", 1, true),
	"explicit legacy tool map is missing")
assert(toolBridge:find("toolmode_allow_", 1, true),
	"legacy tool activation cvars are missing")
assert(toolBridge:find("acfmenu = \"acemenu\"", 1, true),
	"legacy tool map is not explicit")
assert(toolBridge:find("legacyTool.AddToMenu = false", 1, true),
	"legacy aliases must stay hidden from the spawn-menu entry")
assert(not toolBridge:find("tool.AddToMenu = false", 1, true),
	"canonical ACE entries must remain visible in the spawn menu")
assert(toolBridge:find("legacyTool.Allowed = function()", 1, true),
	"legacy aliases must use canonical ACE permission state")

local registeredHook
hook = { Add = function(_, name, callback)
	if name == "ACE_LegacyToolAliases" then registeredHook = callback end
end }
SWEP = { Tool = {} }
local convars = {}
function GetConVar(name) return convars[name] end
function CreateConVar(name)
	local convar = { GetBool = function() return true end }
	convars[name] = convar
	return convar
end
table.Copy = function(source)
	local copy = {}
	for key, value in pairs(source) do copy[key] = value end
	return copy
end

local function newTool(mode)
	return {
		Mode = mode,
		ClientConVar = { type = "gun", id = "7.62mmMG", data15 = 0 },
		CreateConVars = function(self)
			self.ClientConVars = table.Copy(self.ClientConVar)
		end,
	}
end

assert(dofile(root .. "/lua/autorun/ace_legacy_tools.lua") == nil)
for _, mode in ipairs({ "acearmorprop", "acechaircam", "acecopy", "acemenu", "acesound" }) do
		SWEP.Tool = {}
		local tool = newTool(mode)
		registeredHook(tool, mode)
		local alias = SWEP.Tool["acf" .. mode:sub(4)]
		assert(alias and alias.Mode == "acf" .. mode:sub(4), "missing alias for " .. mode)
		if mode == "acemenu" then
			assert(alias.ClientConVar.type and alias.ClientConVar.id and alias.ClientConVar.data15,
				"legacy menu alias did not preserve its client convars")
		end
		assert(alias.AddToMenu == false, "alias was added to the menu for " .. mode)
		assert(tool.AddToMenu == nil, "canonical ACE entry was removed from the menu for " .. mode)
		convars["toolmode_allow_" .. mode] = { GetBool = function() return true end }
		convars["toolmode_allow_acf" .. mode:sub(4)] = { GetBool = function() return true end }
		assert(alias:Allowed(), "alias did not use the canonical permission cvar for " .. mode)
	end

local vehicle = read("/lua/autorun/battlepod.lua")
local vehicleCompat = read("/lua/autorun/ace_legacy_vehicles.lua")
assert(vehicle:find("list.Set( \"Vehicles\", \"ACE_pilotseat\", V )", 1, true),
	"current pilot-seat registry key is missing")
assert(vehicleCompat:find("key == \"acf_pod\"", 1, true),
	"legacy driver-pod registry key is missing")
assert(vehicleCompat:find("key == \"acf_pilotseat\"", 1, true),
	"legacy pilot-seat registry key is missing")
assert(vehicle:find("vehiclescript%s*=%s*\"scripts/vehicles/prisoner_pod.txt\""),
	"pilot seat vehicle script changed unexpectedly")
assert(vehicle:find("limitview%s*=%s*\"0\""),
	"pilot seat view-limit compatibility changed")

local armorTool = read("/lua/weapons/gmod_tool/stools/acearmorprop.lua")
assert(not armorTool:find("function hook.Call", 1, true),
	"canonical armor tool still replaces the global hook dispatcher")
assert(toolBridge:find("toolmode == \"acfarmorprop\"", 1, true),
	"armor read-only compatibility path does not accept the legacy tool mode")
assert(toolBridge:find("hook.Call = function", 1, true),
	"legacy tool bridge does not preserve the deterministic CanTool bypass")
assert(toolBridge:find("button == 3", 1, true),
	"legacy CanTool bypass is not limited to reload actions")

print("ACE legacy compatibility LuaJIT self-test: PASS")
