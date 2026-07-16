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

		if con.ACECacheVersion == nil then
			con.ACECacheVersion = ACE.CacheVersion
			return false
		end

		if con.ACECacheVersion == ACE.CacheVersion then return false end

		con.ACECacheVersion = ACE.CacheVersion

		con.ACEArmorCalculated = false
		con.ACEArmorLastCalc = 0

		con.ACEPointsDirty = true
		con.ACENonArmorDirty = true
		con.ACEAmmoCache = nil
		con.ACEPointsDetails = nil

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
		con.ACEArmorLastCalc = 0

		con.ACENonArmorDirty = true
		con.ACEAmmoCache = nil

		con.ACEPointsPerType = {}
		for _, k in ipairs({
			"Armor",
			"Engines",
			"Firepower",
			"Ammo",
			"AmmoReady",
			"AmmoReadyRounds",
			"Crew",
			"Electronics"
		}) do
			con.ACEPointsPerType[k] = 0
		end
	end

	-- Mark a contraption's derived point totals dirty.
	function ACE_MarkContraptionPointsDirty(con, ent, armorDirty, nonArmorDirty)
		if not con then return end

		if ACE_ClearArmorPointCache and IsEnt(ent) then
			ACE_ClearArmorPointCache(ent)
		end

		if armorDirty == nil then armorDirty = true end
		if nonArmorDirty == nil then nonArmorDirty = true end

		con.ACEPointsDirty = true
		con.ACEArmorDirty = con.ACEArmorDirty or armorDirty
		con.ACENonArmorDirty = con.ACENonArmorDirty or nonArmorDirty

		if armorDirty then
			con.ACEArmorCalculated = false
			con.ACEArmorLastCalc = 0
		end

		if nonArmorDirty then
			con.ACEAmmoCache = nil
		end
	end

	-- Initialize point tracking when a contraption is created.
	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)
	-- Initialize point tracking when a family is created.
	hook.Add("cfw.family.created", "ACE_InitPoints", ACE_InitPts)

	-- Flag contraptions that are being removed to suppress dirty warnings.
	hook.Add("cfw.contraption.removed", "ACE_ContraptionRemoving", function(con)
		if not con then return end
		con.ACERemoving = true
		if con.OTWarnings then con.OTWarnings.WarnedModified = true end
	end)

	-- Handle entity addition and update point totals.
	function ACE_AddPts(con, ent)
		if not IsEnt(ent) then return end

		if ent._ACEPointsConRef and ent._ACEPointsConRef ~= con then
			ACE_RemPts(ent._ACEPointsConRef, ent)
		end

		ent._ACEPointsConRef = con
		ent._ACEPointsConKey = ACE_GetContraptionIndex and ACE_GetContraptionIndex(con) or nil

		ACE_MarkContraptionPointsDirty(con, ent, true, true)
	end

	-- Handle entity removal and update point totals.
	function ACE_RemPts(con, ent)
		if not IsEnt(ent) then return end
		if ent.IsBeingRemoved and ent:IsBeingRemoved() then return end
		if ent._ACEPointsConRef and ent._ACEPointsConRef ~= con then return end

		ent._ACEPointsConKey = nil
		ent._ACEPointsConRef = nil

		ACE_MarkContraptionPointsDirty(con, ent, true, true)
	end

	-- Track point totals when entities are added.
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE_AddPts)
	-- Track point totals when entities are added to a family.
	hook.Add("cfw.family.added", "ACE_AddPoints", ACE_AddPts)

	-- Track point totals when entities are removed.
	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE_RemPts)
	-- Track point totals when entities are removed from a family.
	hook.Add("cfw.family.subbed", "ACE_RemPoints", ACE_RemPts)
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
		if not IsEnt(ent) then
			return OldSetMass(self, mass)
		end

		local currentMass = self:GetMass()
		if math.abs(mass - currentMass) < 0.01 then
			return OldSetMass(self, mass)
		end

		OldSetMass(self, mass)

		local con = ent.GetContraption and ent:CFW_GetContraption()
		if not con then return end

		ACE_MarkContraptionPointsDirty(con, ent, true, true)
	end
end

-- ------------------------------------------------------------
-- Cache reset and armor dirty handling
-- ------------------------------------------------------------

-- Clear derived point caches globally; contraptions rebuild on demand.
local function ACE_ClearAllCaches()
	ACE.CacheVersion = (ACE.CacheVersion or 1) + 1
end

concommand.Add("ace_cache_clear_all", function()
	ACE_ClearAllCaches()
end)

-- Mark armor points dirty for callers that know only armor changed.
function ACE_MarkArmorDirty(con, ent)
	if not con then return end
	ACE_MarkContraptionPointsDirty(con, ent, true, false)
end

