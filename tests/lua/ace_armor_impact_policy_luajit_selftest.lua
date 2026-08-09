local root = assert(arg[1], "usage: ace_armor_impact_policy_luajit_selftest.lua <ACE repo>")

ACE = {}
SERVER = false
CLIENT = true

function AddCSLuaFile() end
function istable(value) return type(value) == "table" end
function math.Clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

dofile(root .. "/lua/acf/shared/sh_ace_armor_behaviors.lua")

local Policy = assert(ACE.ArmorImpactPolicy, "armor impact policy was not registered")

assert(Policy.ConditionLoss({ Damage = 100, Outcome = "stopped" }, 100, 1000, 1000) == 0,
	"deeply sub-threshold hits must not degrade armor")
assert(Policy.ConditionLoss({ Damage = 100, Outcome = "stopped" }, 649, 1000, 1000) == 0,
	"hits below the persistent-damage threshold must not degrade armor")

local nearStopped = Policy.ConditionLoss({ Damage = 100, Outcome = "stopped" }, 800, 1000, 1000)
assert(nearStopped > 0 and nearStopped < 0.02,
	"near-threshold stopped damage must be localized and bounded")

local penetrated = Policy.ConditionLoss({ Damage = 1000, Outcome = "penetrated" }, 1500, 1000, 1000)
assert(penetrated > 0 and penetrated <= Policy.MaxLossPerImpact,
	"penetrating damage must be bounded per impact")

assert(Policy.ConditionLoss({ Damage = 100, Outcome = "invalid" }, 2000, 1000, 1000) == 0,
	"invalid impacts must not create armor condition damage")
assert(Policy.ConditionLoss({ Damage = 100, Outcome = "penetrated" }, 0, 1000, 1000) == 0,
	"zero-penetration impacts must not create armor condition damage")

local state = { Cells = {}, Count = 0 }
for index = 1, 32 do
	Policy.ApplyCellLoss(state, "cell" .. index, 0.1, index, 32)
end
assert(state.Count == 32, "armor impact cell state must stay within its configured limit")
Policy.ApplyCellLoss(state, "replacement", 0.1, 33, 32)
assert(state.Count == 32 and state.Cells.cell1 == nil and state.Cells.replacement ~= nil,
	"armor impact cell state must evict the oldest location")
local first = state.Cells.replacement.Condition
Policy.ApplyCellLoss(state, "replacement", 0.1, 34, 32)
assert(state.Cells.replacement.Condition > first,
	"repeated impacts at one location must accumulate locally")
assert(state.Cells.cell2.Condition == 0.1,
	"damage at one location must not affect another location")

print("ACE armor impact policy LuaJIT self-test: PASS")
