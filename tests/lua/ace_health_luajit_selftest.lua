local root = assert(arg[1], "usage: ace_health_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

local sourceFile = assert(io.open(root .. "/lua/ace/shared/sh_ace_functions.lua", "r"))
local source = sourceFile:read("*a")
sourceFile:close()

local functionStart = assert(source:find("function ACE.CalcHealth", 1, true),
	"ACE.CalcHealth definition is missing")
local functionEnd = assert(source:find("\nfunction ACE.MuzzleVelocity", functionStart, true),
	"ACE.CalcHealth boundary is missing")
local functionSource = source:sub(functionStart, functionEnd - 1)
local chunk = assert(loadstring("ACE = { Threshold = 264.7 }\n" .. functionSource))
local sandbox = { ACE = { Threshold = 264.7 } }
setfenv(chunk, sandbox)
chunk()

local function assertHealth(area, ductility, armour, expected)
	local actual = sandbox.ACE.CalcHealth(area, ductility, armour)
	assert(math.abs(actual - expected) < 1e-9,
		string.format("ACE.CalcHealth(%s, %s, %s) expected %s, got %s",
			tostring(area), tostring(ductility), tostring(armour), tostring(expected), tostring(actual)))
end

assertHealth(264.7, 0, 10, 1)
assertHealth(264.7, 0.8, 10, 1.8)
assertHealth(264.7, 0, 300, 1)
assertHealth(264.7, 0, 5, 1)
assertHealth(0, 0, 10, 0)
assertHealth(66.175, 0, 10, 0.25)
assertHealth(264.7 * 4.46 / 0.2, -0.8, 175, 4.46)

print("ACE health LuaJIT self-test: PASS")
