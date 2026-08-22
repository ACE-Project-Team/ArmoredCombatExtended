local root = assert(arg[1], "usage: ace_entity_state_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
function istable(value) return type(value) == "table" end
dofile(root .. "/lua/ace/shared/sh_ace_entity_state.lua")

local legacy = { Health = 10 }
local fromLegacy = { ACF = legacy }
assert(ACE.GetEntityState(fromLegacy) == legacy, "legacy state was not adopted")
assert(fromLegacy.ACE == legacy, "legacy state was not aliased under ACE")

local modern = { ACE = { Health = 20 } }
assert(ACE.GetEntityState(modern) == modern.ACE, "modern state was not returned")
assert(modern.ACF == modern.ACE, "modern state did not repair the legacy alias")

local split = { ACE = { Health = 30 }, ACF = { Health = 40 } }
assert(ACE.GetEntityState(split) == split.ACE, "ACE state lost precedence over a stale legacy table")
assert(split.ACF == split.ACE, "stale legacy table was not rebound")

local created = {}
local createdState = ACE.GetEntityState(created, true)
assert(createdState == created.ACE and created.ACF == createdState, "state creation did not bind both names")

local replacement = { Health = 50 }
assert(ACE.SetEntityState(created, replacement) == replacement, "state replacement returned the wrong table")
assert(created.ACE == replacement and created.ACF == replacement, "state replacement split the aliases")

print("ACE entity state LuaJIT self-test: PASS")
