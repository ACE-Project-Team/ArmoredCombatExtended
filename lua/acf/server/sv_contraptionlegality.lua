ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")
include("acf/server/sv_pointshandling.lua")


local IsEnt = ACE_IsEnt
ACE.CacheVersion = ACE.CacheVersion or 1

-- ------------------------------------------------------------
-- Legal check throttle (prevents chat spam)
-- ------------------------------------------------------------

-- Run a legality scan for a contraption.
function ACE_DoContraptionLegalCheck(checkEnt)
	checkEnt.CanLegalCheck = checkEnt.CanLegalCheck or false
	if not checkEnt.CanLegalCheck then return end

	checkEnt.CanLegalCheck = false
	timer.Simple(3, function()
		if IsEnt(checkEnt) then checkEnt.CanLegalCheck = true end
	end)

	local con = checkEnt:CFW_GetContraption() or {}
	if table.IsEmpty(con) then return end

	ACE_CheckLegalCont(con)
end

-- ------------------------------------------------------------
-- Player warnings (over points, overweight, and dirty armor)
-- ------------------------------------------------------------

-- Evaluate legality for a contraption.
function ACE_CheckLegalCont(con)
	con.OTWarnings = con.OTWarnings or {}

	if ACE_EnsureContraptionPoints then
		ACE_EnsureContraptionPoints(con, nil, false)
	end

	local points = con.ACEPoints or 0
	if points > ACF.PointsLimit and not con.OTWarnings.WarnedOverPoints then
		local name  = ACE_GetOwnerName(ACE_GetContraptionOwner(con))
		local above = points - ACF.PointsLimit
		chatMessageGlobal(
			"[ACE] " .. name .. " has a vehicle [" .. math.ceil(above) .. "pts] over the limit costing [" ..
				math.ceil(points) .. "pts / " .. math.ceil(ACF.PointsLimit) .. "pts]",
			Color(255, 234, 0)
		)
		con.OTWarnings.WarnedOverPoints = true
	end

	if con.totalMass > ACF.MaxWeight and not con.OTWarnings.WarnedOverWeight then
		local name  = ACE_GetOwnerName(ACE_GetContraptionOwner(con))
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
	function ACE_EnsureCacheVersion(con)
		if not con then return false end

		if con.ACECacheVersion == ACE.CacheVersion then return false end

		con.ACECacheVersion = ACE.CacheVersion

		con.ACEArmorCalculated = false

		con.ACEPointsDirty = true
		con.ACEArmorDirty = true
		con.ACENonArmorDirty = true

		return true
	end

	-- Initialize per-contraption points state.
	local function ACE_InitPts(con)
		if con.ACEInitDone then return end
		con.ACEInitDone = true

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
	end

	-- Mark a contraption's derived point totals dirty.
	function ACE_MarkContraptionPointsDirty(con, ent, armorDirty, nonArmorDirty)
		if not con then return end

		if armorDirty == nil then armorDirty = true end
		if nonArmorDirty == nil then nonArmorDirty = true end

		if armorDirty and ACE_ClearArmorPointCache and IsEnt(ent) then
			ACE_ClearArmorPointCache(ent)
		end

		con.ACEPointsDirty = true
		con.ACEArmorDirty = con.ACEArmorDirty or armorDirty
		con.ACENonArmorDirty = con.ACENonArmorDirty or nonArmorDirty

		if armorDirty then
			con.ACEArmorCalculated = false
		end
	end

	-- Orphan weapons invalidate the link-anchor contraption that owns their cost.
	function ACE_PointsInputChanged(ent)
		if not IsEnt(ent) then return end

		local previous = ent._ACEPointsOwnerConRef
		local con = ACE_GetContraptionFromEntity and ACE_GetContraptionFromEntity(ent)
		if not con and ACE_GetWeaponAnchorContraption then con = ACE_GetWeaponAnchorContraption(ent) end

		ent._ACEPointsOwnerConRef = con

		if previous and previous ~= con then
			ACE_MarkContraptionPointsDirty(previous, ent, false, true)
		end
		if con then ACE_MarkContraptionPointsDirty(con, ent, false, true) end
	end

	-- Initialize point tracking when a contraption is created.
	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)

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
	local function ACE_NotifyCrateWeapons(ent)
		if not IsEnt(ent) or ent:GetClass() ~= "acf_ammo" then return end

		for _, weapon in pairs(ent.Master or {}) do
			if IsEnt(weapon) then ACE_PointsInputChanged(weapon) end
		end
	end

	-- Handle entity addition and update point totals.
	function ACE_AddPts(con, ent)
		if not IsEnt(ent) then return end

		local previous = ent._ACEPointsConRef
		local previousOwner = ent._ACEPointsOwnerConRef

		if previous and previous ~= con then
			ACE_MarkContraptionPointsDirty(previous, ent, true, true)
		end
		if previousOwner and previousOwner ~= con and previousOwner ~= previous then
			ACE_MarkContraptionPointsDirty(previousOwner, ent, false, true)
		end

		ent._ACEPointsConRef = con
		ent._ACEPointsOwnerConRef = con
		ACE_MarkContraptionPointsDirty(con, ent, true, true)
		ACE_NotifyCrateWeapons(ent)
	end

	-- Handle entity removal and update point totals.
	function ACE_RemPts(con, ent)
		if not con then return end

		local valid = IsEnt(ent)
		local removing = valid and ent.IsBeingRemoved and ent:IsBeingRemoved()
		local previous = valid and ent._ACEPointsOwnerConRef

		if valid and ent._ACEPointsConRef == con then ent._ACEPointsConRef = nil end
		if valid and previous == con then ent._ACEPointsOwnerConRef = nil end

		ACE_MarkContraptionPointsDirty(con, ent, true, true)

		if previous and previous ~= con then
			ACE_MarkContraptionPointsDirty(previous, ent, false, true)
		end

		ACE_NotifyCrateWeapons(ent)
		if valid and not removing then ACE_PointsInputChanged(ent) end
	end

	-- Track point totals when entities are added.
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE_AddPts)

	-- Track point totals when entities are removed.
	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE_RemPts)
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
		local result = OldSetMass(self, mass)

		if not IsEnt(ent) then
			return result
		end

		if math.abs(mass - currentMass) < 0.01 then
			return result
		end

		if ent:GetClass() ~= "prop_physics" and not ent.IsPrimitive then return result end

		local con = ACE_GetContraptionFromEntity and ACE_GetContraptionFromEntity(ent)
		ACE_MarkArmorDirty(con, ent)

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
function ACE_MarkArmorDirty(con, ent)
	if ACE_ClearArmorPointCache and IsEnt(ent) then ACE_ClearArmorPointCache(ent) end
	if not con then return end
	ACE_MarkContraptionPointsDirty(con, nil, true, false)
end

-- Reprice clipped armor after Proper Clipping replaces its physics object.
local function ACE_ProperClippingPhysicsChanged(ent)
	if not IsEnt(ent) then return end

	local con = ACE_GetContraptionFromEntity and ACE_GetContraptionFromEntity(ent)
	ACE_MarkArmorDirty(con, ent)
end

hook.Add("ProperClippingPhysicsClipped", "ACE_ProperClippingArmorChanged", ACE_ProperClippingPhysicsChanged)
hook.Add("ProperClippingPhysicsReset", "ACE_ProperClippingArmorReset", ACE_ProperClippingPhysicsChanged)

