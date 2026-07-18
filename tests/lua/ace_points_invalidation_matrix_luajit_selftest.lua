local root = assert(arg[1], "usage: ace_points_invalidation_matrix_luajit_selftest.lua <ACE repo>")
root = root:gsub("\\\\", "/"):gsub("/$", "")

ACE = {}
ACF = { PointsLimit = math.huge, MaxWeight = math.huge }
CFW = {
	Classes = {
		Contraption = {
			Defuse = function(self)
				self._defuseCalled = true
				if self._defuseFailure then self._defuseFailure() end
			end,
		},
	},
}

local function isEntity(ent)
	return ent and ent.valid == true
end

function include(path)
	if path == "acf/server/sv_pointshandling.lua" then
		dofile(root .. "/lua/acf/server/sv_pointshandling.lua")
	end
end

function IsValid(ent) return isEntity(ent) end
function ACE.IsEnt(ent) return isEntity(ent) end
function isnumber(value) return type(value) == "number" end
function ACE.GetContraptionFromEntity(ent) return ent.con end
function ACE.GetWeaponAnchorContraption(ent) return ent.anchor end
function ACE.GetOwnerName() return "matrix-owner" end
function ACE.GetContraptionOwner() return nil end
function ACE.GetPtsType() return nil end
function ACE.GetEntPoints(ent) return ent.points or 0 end
function ACE.GetArmorPoints(ent) return ent.armorPoints or 0 end
function ACE.GetCrewSeatPointCost() return 0 end
function ACE.GetGunFirepowerPointsFor() return 0 end
function Color() return {} end
function chatMessageGlobal() end

table.IsEmpty = function(value) return next(value) == nil end
timer = { Simple = function() end }

local hookHandlers = {}
local hook = {
	Add = function(name, identifier, callback)
		hookHandlers[name] = hookHandlers[name] or {}
		hookHandlers[name][identifier] = callback
	end,
	Run = function(name, ...)
		for _, callback in pairs(hookHandlers[name] or {}) do callback(...) end
	end,
}
_G.hook = hook

local concommands = {}
concommand = {
	Add = function(name, callback) concommands[name] = callback end,
}

local physMeta = {
	SetMass = function(self, mass) self.mass = mass end,
	GetMass = function(self) return self.mass end,
	GetEntity = function(self) return self.entity end,
}
function FindMetaTable(name)
	assert(name == "PhysObj")
	return physMeta
end

local armorClears = {}
function ACE.ClearArmorPointCache(ent)
	armorClears[ent] = (armorClears[ent] or 0) + 1
	if ACE.ArmorPointCache and ent.index then ACE.ArmorPointCache[ent.index] = nil end
end

local function entitiesOf(con)
	local result = {}
	for key, value in pairs(con.ents or {}) do
		local ent = value == true and key or value
		if isEntity(ent) then result[#result + 1] = ent end
	end
	return result
end

function ACE.GetContraptionEntities(con)
	return entitiesOf(con)
end

dofile(root .. "/lua/acf/server/sv_contraptionlegality.lua")

local batches = {}
local compat = {}
local recalculated = {}
hook.Add("ACE_OnContraptionsPointsInvalidated", "matrix-batch", function(event)
	batches[#batches + 1] = event
end)
hook.Add("ACE_OnContraptionPointsInvalidated", "matrix-compat", function(con, change)
	compat[#compat + 1] = { con = con, change = change }
end)
hook.Add("ACE_OnContraptionPointsRecalculated", "matrix-recalculated", function(con, change)
	recalculated[#recalculated + 1] = { con = con, change = change }
end)

local knownContraptions = {}

local function newContraption(name)
	local con = { name = name, ents = {}, totalMass = 0 }
	ACE.EnsurePointsState(con)
	ACE.EnsureContraptionPoints(con, nil, false)
	knownContraptions[#knownContraptions + 1] = con
	return con
end

local function newEntity(con, className, fields)
	local ent = fields or {}
	ent.valid = true
	ent.con = con
	ent._ACEPointsConRef = con
	ent._ACEPointsOwnerConRef = con
	ent.GetClass = ent.GetClass or function() return className or "prop_physics" end
	ent.CFW_GetContraption = ent.CFW_GetContraption or function(self) return self.con end
	ent.GetPhysicsObject = ent.GetPhysicsObject or function(self)
		return {
			valid = true,
			GetMass = function() return self.mass or 10 end,
		}
	end
	return ent
end

local function clearLogs()
	batches = {}
	compat = {}
	recalculated = {}
end

local function indexOf(list, value)
	for index, item in ipairs(list) do
		if item == value then return index end
	end
	return nil
end

local function assertEvent(label, invoke, expected, categories, reason, opts)
	opts = opts or {}
	local beforeGeneration = {}
	local beforeCategoryGeneration = {}
	for _, con in ipairs(knownContraptions) do
		beforeGeneration[con] = con.ACEPointsGeneration or 0
		beforeCategoryGeneration[con] = {
			Armor = con.ACEArmorGeneration or 0,
			Ammo = con.ACEAmmoGeneration or 0,
			Firepower = con.ACEFirepowerGeneration or 0,
			ReadyRack = con.ACEReadyRackGeneration or 0,
			Warning = con.ACEWarningGeneration or 0,
		}
	end
	local batchBefore = #batches
	local compatBefore = #compat
	local recalcBefore = #recalculated
	local event = invoke()
	assert(#batches == batchBefore + 1, label .. ": expected one batch event")
	event = type(event) == "table" and event or batches[#batches]
	assert(event, label .. ": notifier returned no event")
	assert(batches[#batches] == event, label .. ": batch hook received a different event")
	assert(event.Reason == reason, label .. ": wrong reason")
	assert(event.Entity ~= nil, label .. ": source entity/contraption was not recorded")
	assert(#event.AffectedContraptions == #expected, label .. ": wrong affected count")
	for category, enabled in pairs(categories or {}) do
		assert(event.Categories[category] == enabled, label .. ": event category payload mismatch")
	end
	for _, con in ipairs(expected) do
		assert(indexOf(event.AffectedContraptions, con), label .. ": missing affected contraption")
		assert(con.ACEPointsGeneration == beforeGeneration[con] + 1,
			label .. ": affected generation did not advance once")
		local generations = event.CacheGenerations[con]
		assert(generations and generations.Points == con.ACEPointsGeneration,
			label .. ": cache generation payload is stale")
		assert(generations.Cache == con.ACECacheGeneration,
			label .. ": aggregate cache generation is stale")
		for category, enabled in pairs(categories or {}) do
			local field = "ACE" .. category .. "Generation"
			if category == "Warning" then field = "ACEWarningGeneration" end
			if category == "ReadyRack" then field = "ACEReadyRackGeneration" end
			if category == "Firepower" then field = "ACEFirepowerGeneration" end
			if category == "Ammo" then field = "ACEAmmoGeneration" end
			if category == "Armor" then field = "ACEArmorGeneration" end
			if enabled then
				assert(con[field] == con.ACEPointsGeneration,
					label .. ": enabled category did not advance")
			else
				assert(con[field] == beforeCategoryGeneration[con][category],
					label .. ": disabled category advanced")
			end
		end
	end
	for _, con in ipairs(knownContraptions) do
		if not indexOf(expected, con) then
			assert(con.ACEPointsGeneration == beforeGeneration[con],
				label .. ": unrelated contraption advanced")
		end
	end
	assert(#compat == compatBefore + #expected, label .. ": compatibility hook cardinality mismatch")
	local expectedRecalcs = opts.recalculations
	if expectedRecalcs == nil then expectedRecalcs = #expected end
	assert(#recalculated == recalcBefore + expectedRecalcs,
		label .. ": recalculation cardinality mismatch (got " .. (#recalculated - recalcBefore) .. ")")
	for index = compatBefore + 1, #compat do
		local change = compat[index].change
		assert(change.EventId == event.EventId, label .. ": compatibility event ID mismatch")
		assert(change.Reason == reason, label .. ": compatibility reason mismatch")
		assert(change.AffectedContraptions == expected or change.AffectedContraptions == event.AffectedContraptions,
			label .. ": compatibility affected list mismatch")
	end
	clearLogs()
	return event
end

local function assertNoEvent(label, invoke)
	local batchBefore = #batches
	local compatBefore = #compat
	local recalcBefore = #recalculated
	local result = invoke()
	assert(#batches == batchBefore and #compat == compatBefore and #recalculated == recalcBefore,
		label .. ": unexpected lifecycle event")
	return result
end

local conA = newContraption("A")
local conB = newContraption("B")
local conC = newContraption("C")
clearLogs()

-- Direct notifier forms and every category combination.
assertEvent("armor-only", function()
	return ACE.NotifyPointsInvalidated(conA, "armor-only", { Armor = true, Warning = true })
end, { conA }, { Armor = true, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "armor-only")
assert(not conA.ACEArmorDirty and not conA.ACENonArmorDirty,
	"warning consumer did not finish the armor-only rebuild")
local armorStateAfterArmorEvent = conA.ACEArmorCalculated

assertEvent("nonarmor-only", function()
	return ACE.NotifyPointsInvalidated(conA, "nonarmor-only", {
		Ammo = true, Firepower = true, ReadyRack = true, Warning = true,
	})
end, { conA }, { Armor = false, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "nonarmor-only")
assert(not conA.ACEArmorDirty and not conA.ACENonArmorDirty
		and conA.ACEArmorCalculated == armorStateAfterArmorEvent,
	"warning consumer did not finish the non-armor rebuild")

assertEvent("all-categories", function()
	return ACE.NotifyPointsInvalidated({ conA, conA, conB }, "all-categories", {
		Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true,
	})
end, { conA, conB }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "all-categories")

assertNoEvent("empty source list", function()
	return ACE.NotifyPointsInvalidated({}, "empty-source", { Warning = true })
end)

local explicit = { valid = true, con = conA, _ACEPointsOwnerConRef = conC, anchor = conA }
assertEvent("current-and-previous-owner", function()
	return ACE.PointsInputChanged(explicit, "owner-moved")
end, { conA, conC }, { Armor = false, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "owner-moved")

assertEvent("explicit-contraption", function()
	return ACE.NotifyPointsInvalidated(conA, "explicit-contraption", { Warning = true }, { conB })
end, { conA, conB }, { Armor = false, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "explicit-contraption", {
	recalculations = 0,
})

assertEvent("warning-only", function()
	return ACE.NotifyPointsInvalidated(conA, "warning-only", { Warning = true })
end, { conA }, { Armor = false, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "warning-only", {
	recalculations = 0,
})

local function maskHas(mask, bit)
	return math.floor(mask / bit) % 2 == 1
end

for mask = 0, 31 do
	local categories = {
		Armor = maskHas(mask, 1),
		Ammo = maskHas(mask, 2),
		Firepower = maskHas(mask, 4),
		ReadyRack = maskHas(mask, 8),
		Warning = maskHas(mask, 16),
	}
	local hasPointCategory = categories.Armor or categories.Ammo or categories.Firepower or categories.ReadyRack
	assertEvent("category-mask-" .. mask, function()
		return ACE.NotifyPointsInvalidated(conC, "category-mask-" .. mask, categories)
	end, { conC }, categories, "category-mask-" .. mask, {
		recalculations = hasPointCategory and 1 or 0,
	})
end

local cacheEntity = newEntity(conA, "prop_physics")
assertEvent("compatibility-dirty-wrapper", function()
	return ACE.MarkContraptionPointsDirty(conA, cacheEntity, false, true, "wrapper")
end, { conA }, { Armor = false, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "wrapper")

local armorEntity = newEntity(conA, "prop_physics")
assertEvent("armor-dirty-wrapper", function()
	return ACE.MarkArmorDirty(conA, armorEntity, "armor-wrapper")
end, { conA }, { Armor = true, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "armor-wrapper")
assert(armorClears[armorEntity] == 1, "armor wrapper did not clear the entity cache")

local orphan = { valid = true, index = 77 }
ACE.ArmorPointCache = { [orphan.index] = 99 }
assertNoEvent("orphan-armor-cache-clear", function()
	return ACE.MarkArmorDirty(nil, orphan, "orphan-armor")
end)
assert(ACE.ArmorPointCache[orphan.index] == nil, "orphan armor cache was not cleared")

-- Linked ammo and cross-contraption endpoint batches.
local linkedWeaponB = newEntity(conB, "acf_gun")
local ammo = newEntity(conA, "acf_ammo", { Master = { linkedWeaponB } })
assertEvent("linked-crate-batch", function()
	return ACE.NotifyCrateWeapons(ammo, "linked-crate")
end, { conA, conB }, { Armor = false, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "linked-crate")

local removalParent = newContraption("ammo-removal-parent")
local removalChild = newContraption("ammo-removal-child")
local removalGun = newEntity(conB, "acf_gun")
local removalAmmo = newEntity(removalParent, "acf_ammo", { Master = { removalGun } })
assertEvent("cross-contraption-ammo-removal", function()
	return ACE.PointsInputChanged({ removalAmmo, removalGun }, "ammo-removed")
end, { removalParent, conB }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "ammo-removed")
assertEvent("split-after-cross-contraption-ammo-removal", function()
	return hookHandlers["cfw.contraption.split"].ACE_InheritPointWarning(conB, removalChild)
end, { conB, removalChild }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-split")

-- Creation, add/remove, split, merge, and final removal hook ordering.
local created = { ents = {}, totalMass = 0 }
assertNoEvent("contraption-created-initialization", function()
	return hookHandlers["cfw.contraption.created"].ACE_InitPoints(created)
end)
assert(created.ACEInitDone and created.ACEPointsGeneration == 0, "creation did not initialize cleanly")
assert(ACE._ACEWrappedDefuse, "CFW Defuse wrapper was not installed after CFW became available")
CFW.Classes.Contraption.Defuse(created)
assert(created._defuseCalled and not created._ACEPointsDefusing,
	"CFW Defuse wrapper did not preserve and clear lifecycle state")
knownContraptions[#knownContraptions + 1] = created

local added = newEntity(created, "prop_physics")
assertEvent("entity-added", function()
	created.ents[added] = true
	return hookHandlers["cfw.contraption.entityAdded"].ACE_AddPoints(created, added)
end, { created }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "entity-added")

local removed = newEntity(conA, "prop_physics", {
	IsMarkedForDeletion = function() return true end,
})
assertEvent("entity-removed", function()
	return hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(conA, removed)
end, { conA }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "entity-removed")

local defuseCon = newContraption("defuse")
local defuseEnt = newEntity(defuseCon, "prop_physics")
defuseCon.ents[defuseEnt] = true
defuseCon._ACEPointsDefusing = true
assertNoEvent("defuse-intermediate-removal", function()
	return hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(defuseCon, defuseEnt)
end)
defuseCon.ents[defuseEnt] = nil
assertNoEvent("defuse-final-entity-removal", function()
	return hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(defuseCon, defuseEnt)
end)
assertEvent("defuse-contraption-removal", function()
	return hookHandlers["cfw.contraption.removed"].ACE_ContraptionRemoving(defuseCon)
end, { defuseCon }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-removed", {
	recalculations = 0,
})

local failedDefuseCon = newContraption("failed-defuse")
local failedDefuseEnt = newEntity(failedDefuseCon, "prop_physics")
failedDefuseCon.ents[failedDefuseEnt] = true
failedDefuseCon._defuseFailure = function()
	failedDefuseCon.ents[failedDefuseEnt] = nil
	hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(failedDefuseCon, failedDefuseEnt)
	error("simulated Defuse failure")
end
assertEvent("failed-defuse-recovers-one-invalidation", function()
	local ok = pcall(CFW.Classes.Contraption.Defuse, failedDefuseCon)
	assert(not ok, "simulated Defuse failure was swallowed")
end, { failedDefuseCon }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-defuse-aborted")
assert(not failedDefuseCon._ACEPointsDefusing and not failedDefuseCon._ACEPointsDefuseRemovalSeen,
	"failed Defuse did not clear temporary lifecycle state")

local finalizedDefuseCon = newContraption("finalized-defuse")
local finalizedDefuseEnt = newEntity(finalizedDefuseCon, "prop_physics")
finalizedDefuseCon.ents[finalizedDefuseEnt] = true
finalizedDefuseCon._defuseFailure = function()
	finalizedDefuseCon.ents[finalizedDefuseEnt] = nil
	hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(finalizedDefuseCon, finalizedDefuseEnt)
	hookHandlers["cfw.contraption.removed"].ACE_ContraptionRemoving(finalizedDefuseCon)
	error("simulated post-finalization Defuse failure")
end
assertEvent("post-finalization-defuse-failure-does-not-duplicate", function()
	local ok = pcall(CFW.Classes.Contraption.Defuse, finalizedDefuseCon)
	assert(not ok, "simulated post-finalization Defuse failure was swallowed")
end, { finalizedDefuseCon }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-removed", {
	recalculations = 0,
})
assert(not finalizedDefuseCon._ACEPointsDefusing and not finalizedDefuseCon._ACEPointsDefuseFinalized,
	"post-finalization Defuse failure did not clear temporary lifecycle state")

local multiDefuseCon = newContraption("multi-defuse")
local multiDefuseFirst = newEntity(multiDefuseCon, "prop_physics")
local multiDefuseSecond = newEntity(multiDefuseCon, "prop_physics")
multiDefuseCon.ents[multiDefuseFirst] = true
multiDefuseCon.ents[multiDefuseSecond] = true
assertNoEvent("multi-defuse-intermediate-removal", function()
	return hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(multiDefuseCon, multiDefuseFirst)
end)
assertEvent("multi-defuse-final-direct-removal", function()
	return hookHandlers["cfw.contraption.removed"].ACE_ContraptionRemoving(multiDefuseCon)
end, { multiDefuseCon }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-removed", {
	recalculations = 0,
})
assert(not ACE.PointContraptions[multiDefuseCon], "multi-defuse contraption remained active")

local emptyDefuseCon = newContraption("empty-defuse")
local emptyDefuseEnt = newEntity(emptyDefuseCon, "prop_physics")
emptyDefuseCon.ents[emptyDefuseEnt] = true
assertNoEvent("empty-defuse-intermediate-removal", function()
	return hookHandlers["cfw.contraption.entityRemoved"].ACE_RemPoints(emptyDefuseCon, emptyDefuseEnt)
end)
emptyDefuseCon.ents[emptyDefuseEnt] = nil
emptyDefuseCon._ACEPointsDefusing = true
assertEvent("empty-defuse-final-removal", function()
	return hookHandlers["cfw.contraption.removed"].ACE_ContraptionRemoving(emptyDefuseCon)
end, { emptyDefuseCon }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-removed", {
	recalculations = 0,
})
assert(not ACE.PointContraptions[emptyDefuseCon], "empty-defuse contraption remained active")

local splitParent = newContraption("split-parent")
local splitChild = newContraption("split-child")
assertEvent("normal-split", function()
	return hookHandlers["cfw.contraption.split"].ACE_InheritPointWarning(splitParent, splitChild)
end, { splitParent, splitChild }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-split")

splitParent.OTWarnings = { WarnedOverPoints = true }
splitChild.OTWarnings = { WarnedOverWeight = true }
assertEvent("recursive-warning-inheritance", function()
	return hookHandlers["cfw.contraption.split"].ACE_InheritPointWarning(splitParent, splitChild)
end, { splitParent, splitChild }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-split")
assert(splitChild.OTWarnings.WarnedOverPoints and splitChild.OTWarnings.WarnedOverWeight,
	"split warning inheritance lost warning fields")

local merged = newContraption("merged")
local target = newContraption("target")
assertEvent("normal-merge", function()
	return hookHandlers["cfw.contraption.merged"].ACE_InvalidateMergedContraptions(merged, target)
end, { merged, target }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-merged", {
	recalculations = 1,
})
assert(merged.ACERemoving and not ACE.PointContraptions[merged], "merged contraption remained active")

local removedCon = newContraption("removed")
assertEvent("contraption-removed", function()
	return hookHandlers["cfw.contraption.removed"].ACE_ContraptionRemoving(removedCon)
end, { removedCon }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "contraption-removed", {
	recalculations = 0,
})
assert(removedCon.ACERemoving and not ACE.PointContraptions[removedCon], "removed contraption remained active")

-- Family mass recovery hooks must stay side-effect-only and never create point events.
local familyEnt = newEntity(nil, "prop_physics", { mass = 25 })
familyEnt._mass = 25
local family = { ents = { [familyEnt] = true } }
assertNoEvent("family-created-mass", function()
	return hookHandlers["cfw.family.created"].ACE_InitFamilyMass(family)
end)
assert(family.totalMass == 25, "family creation did not recover mass")
family.totalMass = nil
family.ents = {}
assertNoEvent("family-added-mass", function()
	return hookHandlers["cfw.family.added"].ACE_RecoverFamilyMassOnAdd(family, familyEnt)
end)
assert(family.totalMass == 25, "family add did not recover mass (got " .. tostring(family.totalMass) .. ")")
family.totalMass = nil
family.ents = {}
assertNoEvent("family-subbed-mass", function()
	return hookHandlers["cfw.family.subbed"].ACE_RecoverFamilyMassOnRemove(family, familyEnt)
end)
assert(family.totalMass == 25, "family removal did not recover mass")

-- Armor/clipping/mass sources all use armor-only categories.
local massEntity = newEntity(conB, "prop_physics", { mass = 10 })
local phys = setmetatable({ entity = massEntity, mass = 10 }, { __index = physMeta })
assertEvent("mass-change", function()
	return phys:SetMass(20)
end, { conB }, { Armor = true, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "mass-changed")
assertEvent("clipping-change", function()
	return hookHandlers.ProperClippingPhysicsClipped.ACE_ProperClippingArmorChanged(massEntity)
end, { conB }, { Armor = true, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "armor-clipped")
assertEvent("clipping-reset", function()
	return hookHandlers.ProperClippingPhysicsReset.ACE_ProperClippingArmorReset(massEntity)
end, { conB }, { Armor = true, Ammo = false, Firepower = false, ReadyRack = false, Warning = true }, "armor-clipped")

-- Completed freeze/unfreeze and vehicle-entry transitions are idempotent.
local freezeEntity = newEntity(conC, "prop_physics")
assertEvent("freeze", function()
	return hookHandlers.PlayerFrozeObject.ACE_PointsFreezeInvalidation(nil, freezeEntity)
end, { conC }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "freeze")
assertNoEvent("duplicate-freeze", function()
	return hookHandlers.PlayerFrozeObject.ACE_PointsFreezeInvalidation(nil, freezeEntity)
end)
assertEvent("unfreeze", function()
	return hookHandlers.PlayerUnfrozeObject.ACE_PointsUnfreezeInvalidation(nil, freezeEntity)
end, { conC }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "unfreeze")
assertNoEvent("duplicate-unfreeze", function()
	return hookHandlers.PlayerUnfrozeObject.ACE_PointsUnfreezeInvalidation(nil, freezeEntity)
end)

-- A pasted prop may be frozen before ACE registers the freeze. Its first
-- completed unfreeze must still invalidate, and later callbacks remain deduped.
local pastedFrozenEntity = newEntity(conC, "prop_physics")
assertEvent("pasted-frozen-unfreeze", function()
	return hookHandlers.PlayerUnfrozeObject.ACE_PointsUnfreezeInvalidation(nil, pastedFrozenEntity)
end, { conC }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "unfreeze")
assertNoEvent("duplicate-pasted-frozen-unfreeze", function()
	return hookHandlers.PlayerUnfrozeObject.ACE_PointsUnfreezeInvalidation(nil, pastedFrozenEntity)
end)

-- Version-2 contraptions predate generation fields and the active registry.
local legacy = {
	ents = {},
	totalMass = 0,
	ACEInitDone = true,
	ACEPointsStateVersion = 2,
	ACEPointsGeneration = 12,
}
assert(ACE.EnsurePointsState(legacy), "version-2 contraption did not migrate")
assert(legacy.ACEPointsStateVersion == ACE.PointsStateVersion,
	"version-2 contraption did not receive the current state version")
assert(legacy.ACEPointsGeneration == 0 and ACE.PointContraptions[legacy],
	"version-2 contraption did not initialize generation state and registry")

local vehicle = newEntity(conC, "prop_vehicle_prisoner_pod", {
	_ACEPointsFrozen = true,
	CFW_GetContraption = function() return conC end,
})
assertEvent("vehicle-entry-unfreeze", function()
	return hookHandlers.PlayerEnteredVehicle.ACE_PointsVehicleUnfreezeInvalidation(nil, vehicle)
end, { conC }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "unfreeze-on-entry")
assertNoEvent("duplicate-vehicle-entry-unfreeze", function()
	return hookHandlers.PlayerEnteredVehicle.ACE_PointsVehicleUnfreezeInvalidation(nil, vehicle)
end)

local pastedFrozenVehicle = newEntity(conC, "prop_vehicle_prisoner_pod", {
	CFW_GetContraption = function() return conC end,
})
assertEvent("pasted-frozen-vehicle-entry-unfreeze", function()
	return hookHandlers.PlayerEnteredVehicle.ACE_PointsVehicleUnfreezeInvalidation(nil, pastedFrozenVehicle)
end, { conC }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "unfreeze-on-entry")
assertNoEvent("duplicate-pasted-frozen-vehicle-entry-unfreeze", function()
	return hookHandlers.PlayerEnteredVehicle.ACE_PointsVehicleUnfreezeInvalidation(nil, pastedFrozenVehicle)
end)

-- Cache-version transitions and the global command cover every active category.
local stale = newContraption("stale")
stale.ACECacheVersion = ACE.CacheVersion - 1
assertEvent("cache-version-change", function()
	return ACE.EnsureCacheVersion(stale)
end, { stale }, { Armor = true, Ammo = true, Firepower = true, ReadyRack = true, Warning = true }, "cache-version-changed")

local resetA = newContraption("reset-a")
local resetB = newContraption("reset-b")
clearLogs()
local cacheVersion = ACE.CacheVersion
concommands.ace_cache_clear_all()
assert(ACE.CacheVersion == cacheVersion + 1, "global cache reset did not advance its version")
assert(#batches == 1, "global cache reset did not batch active contraptions")
assert(batches[1].Reason == "cache-reset", "global cache reset reason was lost")
assert(indexOf(batches[1].AffectedContraptions, resetA), "global cache reset missed reset-a")
assert(indexOf(batches[1].AffectedContraptions, resetB), "global cache reset missed reset-b")
assert(not indexOf(batches[1].AffectedContraptions, merged), "global cache reset included merged contraption")

-- Re-entrant reads must not recursively rebuild or emit another event.
local reentrant = newContraption("reentrant")
local reentrantRebuilds = 0
hook.Add("ACE_OnContraptionsPointsInvalidated", "matrix-reentrant", function()
	if reentrantRebuilds == 0 then
		reentrantRebuilds = reentrantRebuilds + 1
		ACE.EnsureContraptionPoints(reentrant, nil, false)
	end
end)
clearLogs()
local reentrantEvent = ACE.NotifyPointsInvalidated(reentrant, "reentrant", {
	Ammo = true, Firepower = true, ReadyRack = true, Warning = true,
})
assert(reentrantEvent and reentrantRebuilds == 1, "re-entrant invalidation hook did not run once")
assert(#batches == 1 and #recalculated == 1,
	"re-entrant read duplicated event or rebuild (batches=" .. #batches .. ", recalculated=" .. #recalculated .. ")")

print("ACE points invalidation matrix LuaJIT self-test: PASS")
