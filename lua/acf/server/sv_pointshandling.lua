
ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")

local IsEnt = ACE_IsEnt

local function CopyPointTotals(totals)
	local result = {}
	for key, value in pairs(totals or {}) do result[key] = value end
	return result
end

-- Public point lifecycle hooks:
-- ACE_OnContraptionPointsInvalidated(con, change) reports every known pricing-input mutation,
-- even when the cache is already dirty or the resulting point delta is zero. change contains
-- Revision, Entity, Reason, Armor, and NonArmor. Consumers can call ACE_EnsureContraptionPoints
-- from this hook when they need the updated total immediately.
-- ACE_OnContraptionPointsRecalculated(con, change) reports Revision, OldTotal, Total, OldByType,
-- ByType, Armor, and NonArmor as detached snapshots after a rebuild.
function ACE_NotifyContraptionPointsInvalidated(con, ent, reason, armorDirty, nonArmorDirty)
	if not con then return end

	con.ACEPointsRevision = (con.ACEPointsRevision or 0) + 1

	hook.Run("ACE_OnContraptionPointsInvalidated", con, {
		Revision = con.ACEPointsRevision,
		Entity = ent,
		Reason = reason or "entity-updated",
		Armor = armorDirty and true or false,
		NonArmor = nonArmorDirty and true or false,
	})
end

local function ACE_CalcSubsystem(ents, subsystem)
	local total = 0

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local cls = ent:GetClass()
			if ACE_GetPtsType(cls) == subsystem then
				local pts
				if subsystem == "Crew" then
					pts = ACE_GetCrewSeatPointCost(ent)
				elseif subsystem == "Firepower" and (cls == "acf_gun" or cls == "acf_rack") then
					-- Never collapse by class or round ID: identical weapons bill independently.
					pts = ACE_GetGunFirepowerPointsFor(ent, ents)
				else
					pts = ACE_GetEntPoints(ent)
				end

				if pts ~= 0 then
					total = total + pts
				end
			end
		end
	end

	return total
end

-- ============================================================
-- Point and armor calculation logic for contraption scans
-- ============================================================

-- Calculate non-armor points and readout details. Ammo is free (crates contribute nothing),
-- so the categories are Engines, Firepower (guns AND racks), Crew and Electronics. The
-- contraption entity list is resolved ONCE and shared across guns.
function ACE_CalcNonArmorPoints(con, baseEnt)
	if not con then
		return 0, { Engines = 0, Firepower = 0, Crew = 0, Electronics = 0 }
	end

	local totals = { Engines = 0, Firepower = 0, Crew = 0, Electronics = 0 }

	local ents = ACE_GetContraptionEntities(con, baseEnt)

	local subsystems = ACE.PointSubsystems or {
		"Engines",
		"Firepower",
		"Crew",
		"Electronics"
	}

	for _, subsystem in ipairs(subsystems) do
		totals[subsystem] = ACE_CalcSubsystem(ents, subsystem) or 0
	end

	local nonArmor = (totals.Engines or 0)
		+ (totals.Firepower or 0)
		+ (totals.Crew or 0)
		+ (totals.Electronics or 0)

	return nonArmor, totals
end

function ACE_CalcContraptionArmorPoints(con, baseEnt)
	local total = 0
	local ents = ACE_GetContraptionEntities(con, baseEnt)

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local pts = ACE_GetArmorPoints(ent)
			if pts > 0 then
				total = total + pts
			end
		end
	end

	return total
end

-- Rebuild requested point totals for a contraption from entity state.
function ACE_RebuildContraptionPoints(con, baseEnt, rebuildArmor, rebuildNonArmor)
	if not con then return end

	local oldPoints = con.ACEPoints or 0
	local oldTotals = CopyPointTotals(con.ACEPointsPerType)
	local base = baseEnt
	if (not IsEnt(base)) and con.GetACEBaseplate then base = con:GetACEBaseplate() end

	local totals = con.ACEPointsPerType or {}

	if rebuildNonArmor then
		local nonArmor, nonArmorTotals = ACE_CalcNonArmorPoints(con, base)
		totals = nonArmorTotals or {}

		con.ACEPointsNonArmor = nonArmor or 0
		con.ACENonArmorDirty = false
	end

	if rebuildArmor then
		local armorPts = ACE_CalcContraptionArmorPoints(con, base)

		con.ACEArmorPoints = armorPts
		con.ACEArmorDirty = false
		con.ACEArmorCalculated = true
	end

	local armorPts = con.ACEArmorPoints or totals.Armor or 0
	totals.Armor = armorPts
	con.ACEPointsPerType = totals
	con.ACEPoints = (con.ACEPointsNonArmor or 0) + armorPts
	con.ACEPointsDirty = con.ACEArmorDirty or con.ACENonArmorDirty or false

	hook.Run("ACE_OnContraptionPointsRecalculated", con, {
		Revision = con.ACEPointsRevision or 0,
		OldTotal = oldPoints,
		Total = con.ACEPoints,
		OldByType = oldTotals,
		ByType = CopyPointTotals(totals),
		Armor = rebuildArmor and true or false,
		NonArmor = rebuildNonArmor and true or false,
	})
end

-- Ensure point data is initialized and current.
function ACE_EnsureContraptionPoints(con, baseEnt, force)
	if not con then return end
	if con._ACEPointsEnsuring then return end

	con._ACEPointsEnsuring = true
	if ACE_EnsurePointsState then ACE_EnsurePointsState(con) end

	local cacheStale = ACE_EnsureCacheVersion and ACE_EnsureCacheVersion(con) or false
	local needsInit = not con.ACEArmorCalculated
	if not force and not needsInit and not con.ACEPointsDirty and not con.ACEArmorDirty
		and not con.ACENonArmorDirty and not cacheStale then
		con._ACEPointsEnsuring = nil
		return
	end

	local rebuildArmor = force or needsInit or con.ACEArmorDirty or cacheStale
	local rebuildNonArmor = force or con.ACENonArmorDirty or cacheStale or not con.ACEPointsPerType

	ACE_RebuildContraptionPoints(con, baseEnt, rebuildArmor, rebuildNonArmor)
	con._ACEPointsEnsuring = nil
end

_G.ACE_EnsureContraptionPoints = ACE_EnsureContraptionPoints
