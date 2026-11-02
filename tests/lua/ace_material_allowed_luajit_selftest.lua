-- Offline check for ACE.IsMaterialAllowed: existence, hidden flag and the ACE.Year limit.
local repo = assert(arg[1], "usage: luajit ace_material_allowed_luajit_selftest.lua <ace-repo>")

ACE = {
	Year = 2023,
	ArmorTypes = {
		RHA     = {},
		Cer     = { year = 1955 },
		Aramid  = { year = 1971, hidden = true },
		Future  = { year = 2100 },
	},
}

local source = assert(io.open(repo .. "/lua/ace/shared/sh_ace_functions.lua", "rb")):read("*a"):gsub("\r\n", "\n")
local first = assert(source:find("function ACE.IsMaterialAllowed(", 1, true), "ACE.IsMaterialAllowed not found")
local last = assert(source:find("\nend", first, true), "no end")
assert(loadstring(source:sub(first, last + 4), "ACE.IsMaterialAllowed"))()

assert(ACE.IsMaterialAllowed("RHA"), "plain material allowed")
assert(ACE.IsMaterialAllowed("Cer"), "year-restricted material inside the limit")
assert(not ACE.IsMaterialAllowed("Aramid"), "hidden material refused")
assert(not ACE.IsMaterialAllowed("Foo"), "unknown material refused")
assert(not ACE.IsMaterialAllowed("Future"), "material past ACE.Year refused")
assert(not ACE.IsMaterialAllowed(nil), "nil refused")
assert(not ACE.IsMaterialAllowed(3), "numeric legacy id refused")

ACE.Year = 1950
assert(not ACE.IsMaterialAllowed("Cer"), "ACE.Year below the material's year refuses it")
assert(ACE.IsMaterialAllowed("RHA"), "year-less materials are unaffected by ACE.Year")

print("ACE.IsMaterialAllowed self-test passed")
