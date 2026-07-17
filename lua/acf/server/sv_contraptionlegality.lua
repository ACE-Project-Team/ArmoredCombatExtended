ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")
include("acf/server/sv_pointshandling.lua")


local IsEnt = ACE.IsEnt
ACE.CacheVersion = ACE.CacheVersion or 1
local POINTS_STATE_VERSION = 2
ACE.PointsStateVersion = POINTS_STATE_VERSION

-- CFW's mass extension assumes its aggregate was initialized before a physics rebuild or
-- membership transition reaches SetMass/entityAdded/entityRemoved. Reconstruct a missing
-- aggregate from CFW's own per-entity mass ledger at the ACE lifecycle boundary.
local function ACE_GetCFWEntityMass(ent, initializeLedger)
	local mass = ent._mass
	if mass == nil and ent.GetPhysicsObject then
		local phys = ent:GetPhysicsObject()
		mass = IsValid(phys) and phys:GetMass() or 0
		if initializeLedger then ent._mass = mass end
	end

	return mass or 0
end

local function ACE_EnsureCFWMassTotal(class, members, include, exclude, excludeMass)
	if not class or class.totalMass ~= nil then return end

	local total = 0
	for key, value in pairs(members or {}) do
		local member = value == true and key or value
		if IsValid(member) and member ~= exclude then
			total = total + ACE_GetCFWEntityMass(member, true)
		end
	end

	-- SetMass can be nested inside CFW's wrapper after CFW has already written the new
	-- entity ledger value. Reinsert the pre-change physical mass so CFW's delta applies once.
	if IsValid(exclude) and members and members[exclude] and isnumber(excludeMass) then
		total = total + excludeMass
	end

	-- entityAdded fires after the entity is inserted; entityRemoved fires after it
	-- is removed. Include/exclude the transition entity so a late aggregate
	-- recovery does not double-count either hook's pending mass update.
	if IsValid(include) and (not members or not members[include]) then
		total = total + ACE_GetCFWEntityMass(include, true)
	end

	class.totalMass = total
end

local function ACE_EnsureCFWMassState(ent, currentMass)
	local con = ent.CFW_GetContraption and ent:CFW_GetContraption()
	ACE_EnsureCFWMassTotal(con, con and con.ents, nil, ent, currentMass)

	local family = ent.GetFamily and ent:GetFamily()
	ACE_EnsureCFWMassTotal(family, family and family.ents, nil, ent, currentMass)
end

-- ------------------------------------------------------------
-- Legal check throttle (prevents chat spam)
-- ------------------------------------------------------------

-- Run a legality scan for a contraption.
function ACE.DoContraptionLegalCheck(checkEnt)
	checkEnt.CanLegalCheck = checkEnt.CanLegalCheck or false
	if not checkEnt.CanLegalCheck then return end

	checkEnt.CanLegalCheck = false
	timer.Simple(3, function()
		if IsEnt(checkEnt) then checkEnt.CanLegalCheck = true end
	end)

	local con = checkEnt:CFW_GetContraption() or {}
	if table.IsEmpty(con) then return end

	ACE.CheckLegalCont(con)
end

-- ------------------------------------------------------------
-- Player warnings (over points, overweight, and dirty armor)
-- ------------------------------------------------------------

-- Evaluate legality for a contraption.
function ACE.CheckLegalCont(con)
	con.OTWarnings = con.OTWarnings or {}

	if ACE.EnsureContraptionPoints then
		ACE.EnsureContraptionPoints(con, nil, false)
	end

	local points = con.ACEPoints or 0
	if points > ACF.PointsLimit and not con.OTWarnings.WarnedOverPoints then
		local name  = ACE.GetOwnerName(ACE.GetContraptionOwner(con))
		local above = points - ACF.PointsLimit
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "pts] over the limit costing [" ..
				math.ceil(points) .. "pts / " .. math.ceil(ACF.PointsLimit) .. "pts]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverPoints = true
	end

	if con.totalMass > ACF.MaxWeight and not con.OTWarnings.WarnedOverWeight then
		local name  = ACE.GetOwnerName(ACE.GetContraptionOwner(con))
		local above = con.totalMass - ACF.MaxWeight
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "kg] over the limit, weighing [" ..
				math.ceil(con.totalMass) .. "kg / " .. math.ceil(ACF.MaxWeight) .. "kg]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverWeight = true
	end
end

-- ------------------------------------------------------------
-- Contraption init and point bookkeeping hooks
-- ------------------------------------------------------------

do
	-- Sync per-contraption cache version and invalidate stale local caches.
	function ACE.EnsureCacheVersion(con)
		if not con then return false end

		if con.ACECacheVersion == ACE.CacheVersion then return false end

		con.ACECacheVersion = ACE.CacheVersion
		ACE.MarkContraptionPointsDirty(con, nil, true, true, "cache-version-changed")

		return true
	end

	-- Initialize per-contraption points state.
	function ACE.EnsurePointsState(con)
		if not con then return false end
		if con.ACEInitDone and con.ACEPointsStateVersion == POINTS_STATE_VERSION then return false end

		con.ACEInitDone = true
		con.ACEPointsStateVersion = POINTS_STATE_VERSION
		ACE_EnsureCFWMassTotal(con, con.ents)

		con.ACECacheVersion = ACE.CacheVersion
		con.ACEPoints = 0
		con.ACEPointsNonArmor = 0

		con.ACEArmorPoints = 0
		con.ACEPointsDirty = true
		con.ACEArmorDirty = false
		con.ACEArmorCalculated = false

		con.ACENonArmorDirty = true

		con.ACEPointsPerType = {}
		for _, k in ipairs({
			"Armor",
			"Engines",
			"Firepower",
			"Crew",
			"Electronics"
		}) do
			con.ACEPointsPerType[k] = 0
		end

		con.ACEPointsRevision = 0
		ACE.MarkContraptionPointsDirty(con, nil, true, true, "contraption-created")

		return true
	end

	local ACE_InitPts = ACE.EnsurePointsState

	-- Mark a contraption's derived point totals dirty.
	function ACE.MarkContraptionPointsDirty(con, ent, armorDirty, nonArmorDirty, reason)
		if not con then return end

		if armorDirty == nil then armorDirty = true end
		if nonArmorDirty == nil then nonArmorDirty = true end

		if armorDirty and ACE.ClearArmorPointCache and IsEnt(ent) then
			ACE.ClearArmorPointCache(ent)
		end

		con.ACEPointsDirty = true
		con.ACEArmorDirty = con.ACEArmorDirty or armorDirty
		con.ACENonArmorDirty = con.ACENonArmorDirty or nonArmorDirty

		if armorDirty then
			con.ACEArmorCalculated = false
		end

		ACE.NotifyContraptionPointsInvalidated(con, ent, reason, armorDirty, nonArmorDirty)
	end

	-- Orphan weapons invalidate the link-anchor contraption that owns their cost.
	function ACE.PointsInputChanged(ent, reason)
		if not IsEnt(ent) then return end

		local previous = ent._ACEPointsOwnerConRef
		local con = ACE.GetContraptionFromEntity and ACE.GetContraptionFromEntity(ent)
		if not con and ACE.GetWeaponAnchorContraption then con = ACE.GetWeaponAnchorContraption(ent) end

		ent._ACEPointsOwnerConRef = con

		if previous and previous ~= con then
			ACE.MarkContraptionPointsDirty(previous, ent, false, true, "weapon-owner-changed")
		end
		if con then ACE.MarkContraptionPointsDirty(con, ent, false, true, reason or "entity-updated") end
	end

	-- Initialize point tracking when a contraption is created.
	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)
	hook.Add("cfw.family.created", "ACE_InitFamilyMass", function(family)
		ACE_EnsureCFWMassTotal(family, family.ents)
	end)
	hook.Add("cfw.family.added", "ACE_RecoverFamilyMassOnAdd", function(family, ent)
		ACE_EnsureCFWMassTotal(family, family.ents, nil, ent)
	end)
	hook.Add("cfw.family.subbed", "ACE_RecoverFamilyMassOnRemove", function(family, ent)
		ACE_EnsureCFWMassTotal(family, family.ents, ent)
	end)

	-- Damage can split a warned vehicle into a fresh CFW contraption. Preserve the one-time
	-- point warning across that split so debris and detached sections cannot repeat it.
	local function ACE_InheritPointWarning(parent, child)
		if not parent or not child then return end
		if not parent.OTWarnings or not parent.OTWarnings.WarnedOverPoints then return end

		child.OTWarnings = child.OTWarnings or {}
		child.OTWarnings.WarnedOverPoints = true
	end

	hook.Add("cfw.contraption.split", "ACE_InheritPointWarning", ACE_InheritPointWarning)

	-- Damage can split a warned vehicle into a fresh CFW contraption. Preserve the one-time
	-- point warning across that split so debris and detached sections cannot repeat it.
	local function ACE_InheritPointWarning(parent, child)
		if not parent or not child then return end
		if not parent.OTWarnings or not parent.OTWarnings.WarnedOverPoints then return end

		child.OTWarnings = child.OTWarnings or {}
		child.OTWarnings.WarnedOverPoints = true
	end

	hook.Add("cfw.contraption.split", "ACE_InheritPointWarning", ACE_InheritPointWarning)

	-- Flag contraptions that are being removed to suppress dirty warnings.
	hook.Add("cfw.contraption.removed", "ACE_ContraptionRemoving", function(con)
		if not con then return end
		con.ACERemoving = true
		if con.OTWarnings then con.OTWarnings.WarnedModified = true end
	end)

	-- Refresh orphan-weapon ownership after a linked crate changes contraptions.
	function ACE.NotifyCrateWeapons(ent, reason)
		if not ent or not ent.GetClass or ent:GetClass() ~= "acf_ammo" then return end
		if type(ent.Master) ~= "table" then return end

		for _, weapon in pairs(ent.Master or {}) do
			if IsEnt(weapon) then ACE.PointsInputChanged(weapon, reason or "linked-crate-moved") end
		end
	end

	-- Handle entity addition and update point totals.
	function ACE.AddPts(con, ent)
		if not IsEnt(ent) then return end
		ACE_EnsureCFWMassTotal(con, con.ents, nil, ent)

		local previous = ent._ACEPointsConRef
		local previousOwner = ent._ACEPointsOwnerConRef

		if previous and previous ~= con then
			ACE.MarkContraptionPointsDirty(previous, ent, true, true, "entity-moved")
		end
		if previousOwner and previousOwner ~= con and previousOwner ~= previous then
			ACE.MarkContraptionPointsDirty(previousOwner, ent, false, true, "weapon-owner-changed")
		end

		ent._ACEPointsConRef = con
		ent._ACEPointsOwnerConRef = con
		ACE.MarkContraptionPointsDirty(con, ent, true, true, "entity-added")
		ACE.NotifyCrateWeapons(ent)
	end

	-- Handle entity removal and update point totals.
	function ACE.RemPts(con, ent)
		if not con then return end
		ACE_EnsureCFWMassTotal(con, con.ents, ent)

		local valid = IsEnt(ent)
		local removing = valid and ent.IsBeingRemoved and ent:IsBeingRemoved()
		local previous = valid and ent._ACEPointsOwnerConRef

		if valid and ent._ACEPointsConRef == con then ent._ACEPointsConRef = nil end
		if valid and previous == con then ent._ACEPointsOwnerConRef = nil end

		ACE.MarkContraptionPointsDirty(con, ent, true, true, "entity-removed")

		if previous and previous ~= con then
			ACE.MarkContraptionPointsDirty(previous, ent, false, true, "weapon-owner-changed")
		end

		ACE.NotifyCrateWeapons(ent)
		if valid and not removing then ACE.PointsInputChanged(ent, "entity-detached") end
	end

	-- Track point totals when entities are added.
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE.AddPts)

	-- Track point totals when entities are removed.
	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE.RemPts)
end

-- ------------------------------------------------------------
-- Hook PhysObj:SetMass so mass edits rebuild points on demand.
-- ------------------------------------------------------------

do
	local PHYS = FindMetaTable("PhysObj")

	ACE._OldPhysSetMass = ACE._OldPhysSetMass or PHYS.SetMass
	local OldSetMass = ACE._OldPhysSetMass

	-- Override PhysObj:SetMass to mark armor dirty when needed.
	function PHYS:SetMass(mass)
		local ent = self:GetEntity()
		local currentMass = self:GetMass()
		if IsEnt(ent) then
			-- Initialize the ledger before an inner CFW wrapper calculates its delta. An outer
			-- CFW wrapper has already captured its old ledger value and will overwrite this
			-- field again after the nested call.
			if ent._mass == nil then ent._mass = currentMass end
			ACE_EnsureCFWMassState(ent, currentMass)
		end

		local result = OldSetMass(self, mass)

		if not IsEnt(ent) then
			return result
		end

		if ent.IsPrimitive and ACE.PrimitivePropertiesApplied then
			ACE.PrimitivePropertiesApplied(ent)
		end

		if math.abs(mass - currentMass) < 0.01 then
			return result
		end

		if ent:GetClass() ~= "prop_physics" and not ent.IsPrimitive then return result end

		local con = ACE.GetContraptionFromEntity and ACE.GetContraptionFromEntity(ent)
		ACE.MarkArmorDirty(con, ent, "mass-changed")

		return result
	end
end

-- ------------------------------------------------------------
-- Cache reset and armor dirty handling
-- ------------------------------------------------------------

-- Clear derived point caches globally; contraptions rebuild on demand.
local function ACE_ClearAllCaches()
	ACE.ArmorPointCache = {}
	ACE.CacheVersion = (ACE.CacheVersion or 1) + 1
end

concommand.Add("ace_cache_clear_all", function()
	ACE_ClearAllCaches()
end)

-- Mark armor points dirty for callers that know only armor changed.
function ACE.MarkArmorDirty(con, ent, reason)
	if not con then
		if ACE.ClearArmorPointCache and IsEnt(ent) then ACE.ClearArmorPointCache(ent) end
		return
	end

	ACE.MarkContraptionPointsDirty(con, ent, true, false, reason or "armor-updated")
end

-- Reprice clipped armor after Proper Clipping replaces its physics object.
local function ACE_ProperClippingPhysicsChanged(ent)
	if not IsEnt(ent) then return end

	local con = ACE.GetContraptionFromEntity and ACE.GetContraptionFromEntity(ent)
	ACE.MarkArmorDirty(con, ent, "armor-clipped")
end

hook.Add("ProperClippingPhysicsClipped", "ACE_ProperClippingArmorChanged", ACE_ProperClippingPhysicsChanged)
hook.Add("ProperClippingPhysicsReset", "ACE_ProperClippingArmorReset", ACE_ProperClippingPhysicsChanged)

