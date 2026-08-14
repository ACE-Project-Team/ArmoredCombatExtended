local root = assert(arg[1], "usage: ace_armor_damage_contract_luajit_selftest.lua <ACE repo>")

local function read(path)
	local file = assert(io.open(root .. "/" .. path, "rb"))
	local contents = file:read("*a")
	file:close()
	return contents
end

local base = read("lua/acf/server/sv_acfbase.lua")
local damage = read("lua/acf/server/sv_acfdamage.lua")
local resolver = read("lua/acf/shared/sh_ace_armor_behaviors.lua")

assert(base:find("function ACE_Damage%(.-HitPos%)"), "damage entry point must carry the real hit position")
assert(base:find("function ACE_CalcDamage%(.-HitPos%)"), "armor resolver must receive the real hit position")
assert(base:find("rawArmor <= 0", 1, true), "non-positive armor must fail closed before resolver math")
assert(base:find("GetArmorImpactCell"), "armor damage must use localized impact state")
assert(base:find("ArmorCellLimit = 32", 1, true), "localized armor state must have a bounded cell cache")
assert(resolver:find("state.Count >= limit", 1, true), "localized armor state must evict instead of growing without bound")
assert(base:find("ApplyArmorImpactCondition"), "armor damage must use the bounded condition policy")
assert(base:find("ApplyCellLoss", 1, true), "armor damage must use the shared bounded cell-state helper")
assert(base:find("armorData.Material", 1, true) and base:find("armorData.MaxArmour", 1, true),
	"localized armor state must invalidate when armor configuration changes")
assert(base:find("Entity.ACEImpactHitPos", 1, true), "special damage must preserve hit position for nested prop damage")
assert(base:find("ArmorConditionLoss"), "damage results must expose applied armor condition damage")
assert(not base:find("Entity%.ACF%.Armour = Entity%.ACF%.MaxArmour %* %(0%.5 %+ Entity%.ACF%.Health"),
	"global health-to-armor erosion must not return")
assert(not base:find("State%.Armour == armor", 1, true), "health-only reactivation must not discard localized cell state")
assert(base:find("local ArmorPercent = Entity.ACEArmorImpactState and 1 or Percent", 1, true),
	"health-only reactivation must not turn localized armor damage into global armor erosion")
assert(damage:find("Bullet") and damage:find("Type") and damage:find("HitPos"), "kinetic impacts must pass hit position into damage")
assert(damage:find("Spall") and damage:find("SpallRes%.HitPos"), "spall impacts must pass their hit position into damage")
assert(resolver:find("impactCondition"), "modular resolver must consume localized condition")
assert(resolver:find("ArmorResolution = function%(Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type, impactCondition%)"),
	"modular armor wrapper must accept localized condition")
assert(resolver:find("Ductility"), "legacy ductility must remain part of modular damage resolution")

print("ACE armor damage contract LuaJIT self-test: PASS")
