
ACE = ACE or {}

include("ace/shared/sh_ace_functions.lua")

local IsEnt = ACE.IsEnt

ACE.PointEntityLedger = ACE.PointEntityLedger or setmetatable({}, { __mode = "k" })
ACE.PendingPointEntityChanges = ACE.PendingPointEntityChanges or {}
ACE.PendingPointRebuilds = ACE.PendingPointRebuilds or setmetatable({}, { __mode = "k" })
ACE.PendingPointWarnings = ACE.PendingPointWarnings or setmetatable({}, { __mode = "k" })

local function CopyPointTotals(totals)
	local result = {}
	for key, value in pairs(totals or {}) do result[key] = value end
	return result
end

local function IsLiveContraption(con)
	return con and not con.ACERemoving and not con._removed
end

local function GetPointContribution(ent)
	if not IsEnt(ent) or not ent.GetClass then return "Ignore", 0 end

	local class = ent:GetClass()
	local category = ACE.GetPtsType(class) or "Ignore"

	if category == "Armor" then
		return category, ACE.GetArmorPoints(ent)
	end

	if category == "Crew" then
		return category, ACE.GetCrewSeatPointCost(ent)
	end

	if category == "Firepower" and (class == "acf_gun" or class == "acf_rack") then
		return category, ACE.GetGunFirepowerPointsFor(ent)
	end

	return category, ACE.GetEntPoints(ent)
end

local function ApplyPointDelta(con, category, points)
	if not con or category == "Ignore" or points == 0 then return end

	local totals = con.ACEPointsPerType or {}
	totals[category] = (totals[category] or 0) + points

	if category == "Armor" then
		con.ACEArmorPoints = (con.ACEArmorPoints or 0) + points
	else
		con.ACEPointsNonArmor = (con.ACEPointsNonArmor or 0) + points
	end

	totals.Armor = con.ACEArmorPoints or totals.Armor or 0
	con.ACEPointsPerType = totals
	con.ACEPoints = (con.ACEPointsNonArmor or 0) + (con.ACEArmorPoints or 0)
end

local function MarkQueuedContraption(con)
	if not IsLiveContraption(con) then return end

	con._ACEPointEntityChangesQueued = true
end

local function GetFlushState(states, con)
	if not IsLiveContraption(con) then return end

	local state = states[con]
	if state then return state end

	state = {
		OldPoints = con.ACEPoints or 0,
		OldTotals = CopyPointTotals(con.ACEPointsPerType),
		Armor = false,
		NonArmor = false,
	}
	states[con] = state

	return state
end

-- Queue an entity's final point owner for the next server tick. Repeated CFW callbacks
-- replace the same entry, so a split's Sub/Add pair becomes one ledger transfer.
function ACE.QueuePointEntityChange(ent, owner)
	if not ent then return end

	ACE.PendingPointEntityChanges[ent] = { Owner = owner, Remove = owner == nil }
	MarkQueuedContraption(owner)

	local old = ACE.PointEntityLedger[ent]
	if old then MarkQueuedContraption(old.Owner) end
end

-- Queue a full scan only when a caller cannot identify the changed entity.
function ACE.QueueContraptionPointRebuild(con)
	if not IsLiveContraption(con) then return end

	ACE.PendingPointRebuilds[con] = true
end

function ACE.QueueContraptionPointWarning(con)
	if IsLiveContraption(con) then ACE.PendingPointWarnings[con] = true end
end

function ACE.HasQueuedPointChanges(con)
	return con and con._ACEPointEntityChangesQueued or false
end

function ACE.ClearContraptionPointLedger(con)
	if not con then return end

	for ent, record in pairs(con.ACEPointLedger or {}) do
		if ACE.PointEntityLedger[ent] == record then ACE.PointEntityLedger[ent] = nil end
	end

	con.ACEPointLedger = {}
end

function ACE.RebuildContraptionPointLedger(con, baseEnt)
	if not con then return end

	ACE.ClearContraptionPointLedger(con)
	local ledger = con.ACEPointLedger

	for _, ent in ipairs(ACE.GetContraptionEntities(con, baseEnt)) do
		local category, points = GetPointContribution(ent)
		if category ~= "Ignore" then
			local record = { Owner = con, Category = category, Points = points }
			ledger[ent] = record
			ACE.PointEntityLedger[ent] = record
		end
	end
end

function ACE.DropContraptionPointLedger(con, preserveOutgoingTransfers)
	if not con then return end

	for ent, change in pairs(ACE.PendingPointEntityChanges) do
		local old = ACE.PointEntityLedger[ent]
		local outgoingTransfer = preserveOutgoingTransfers and old and old.Owner == con
			and change.Owner and change.Owner ~= con
		if not outgoingTransfer and ((old and old.Owner == con) or change.Owner == con) then
			ACE.PendingPointEntityChanges[ent] = nil
		end
	end

	ACE.ClearContraptionPointLedger(con)
	ACE.PendingPointRebuilds[con] = nil
	ACE.PendingPointWarnings[con] = nil
	con._ACEPointEntityChangesQueued = nil
end

local function NotifyPointFlush(con, state)
	con.ACEArmorDirty = false
	con.ACENonArmorDirty = false
	con.ACEArmorCalculated = true
	con.ACEPointsDirty = false

	if hook and hook.Run then hook.Run("ACE_OnContraptionPointsRecalculated", con, {
		Revision = con.ACEPointsRevision or 0,
		Generation = con.ACEPointsGeneration or con.ACEPointsRevision or 0,
		OldTotal = state.OldPoints,
		Total = con.ACEPoints or 0,
		OldByType = state.OldTotals,
		ByType = CopyPointTotals(con.ACEPointsPerType),
		Armor = state.Armor,
		NonArmor = state.NonArmor,
	}) end
end

-- Apply the point stack once per tick. This is deliberately separate from public
-- invalidation events: listeners still see every mutation, while scans and warnings coalesce.
function ACE.FlushQueuedPointChanges()
	local changes = ACE.PendingPointEntityChanges
	local rebuilds = ACE.PendingPointRebuilds
	local warnings = ACE.PendingPointWarnings
	ACE.PendingPointEntityChanges = {}
	ACE.PendingPointRebuilds = setmetatable({}, { __mode = "k" })
	ACE.PendingPointWarnings = setmetatable({}, { __mode = "k" })

	local states = {}
	for ent, change in pairs(changes) do
		local old = ACE.PointEntityLedger[ent]
		if old and old.Owner then old.Owner._ACEPointEntityChangesQueued = nil end
		if change.Owner then change.Owner._ACEPointEntityChangesQueued = nil end
	end
	for ent, change in pairs(changes) do
		local old = ACE.PointEntityLedger[ent]
		local oldOwner = old and old.Owner
		local newOwner = change.Remove and nil or change.Owner
		local oldState = GetFlushState(states, oldOwner)
		local newState = GetFlushState(states, newOwner)

		if old then
			if oldState then
				ApplyPointDelta(oldOwner, old.Category, -old.Points)
				oldState.Armor = oldState.Armor or old.Category == "Armor"
				oldState.NonArmor = oldState.NonArmor or old.Category ~= "Armor"
			end
			if oldOwner and oldOwner.ACEPointLedger then oldOwner.ACEPointLedger[ent] = nil end
			ACE.PointEntityLedger[ent] = nil
		end

		if newState and IsEnt(ent) then
			local category, points = GetPointContribution(ent)
			if category ~= "Ignore" then
				local record = { Owner = newOwner, Category = category, Points = points }
				newOwner.ACEPointLedger = newOwner.ACEPointLedger or {}
				newOwner.ACEPointLedger[ent] = record
				ACE.PointEntityLedger[ent] = record
				ApplyPointDelta(newOwner, category, points)
				newState.Armor = newState.Armor or category == "Armor"
				newState.NonArmor = newState.NonArmor or category ~= "Armor"
			end
		end
	end

	for con in pairs(rebuilds) do
		if IsLiveContraption(con) then
			ACE.RebuildContraptionPoints(con, nil, true, true)
			states[con] = nil
		end
	end

	for con, state in pairs(states) do
		if IsLiveContraption(con) then NotifyPointFlush(con, state) end
	end

	for con in pairs(warnings) do
		if con.ents and IsLiveContraption(con) and con.ACEWarningsDirty and not con._ACEWarningChecking then
			con._ACEWarningChecking = true
			ACE.CheckLegalCont(con)
			con._ACEWarningChecking = nil
		end
	end
end

-- Public point lifecycle hooks:
-- ACE_OnContraptionPointsInvalidated(con, change) reports every known pricing-input mutation,
-- even when the cache is already dirty or the resulting point delta is zero. change contains
-- Revision, Entity, Reason, Armor, and NonArmor. Consumers can call ACE.EnsureContraptionPoints
-- from this hook when they need the updated total immediately.
-- ACE_OnContraptionPointsRecalculated(con, change) reports Revision, OldTotal, Total, OldByType,
-- ByType, Armor, and NonArmor as detached snapshots after a rebuild.
function ACE.NotifyContraptionPointsInvalidated(con, ent, reason, armorDirty, nonArmorDirty, event)
	if not con then return end

	con.ACEPointsRevision = (con.ACEPointsRevision or 0) + 1

	if not hook or not hook.Run then return end

	hook.Run("ACE_OnContraptionPointsInvalidated", con, {
		EventId = event and event.EventId or con.ACEPointsRevision,
		Revision = con.ACEPointsRevision,
		Generation = con.ACEPointsGeneration or con.ACEPointsRevision,
		CacheGeneration = con.ACECacheGeneration or con.ACEPointsGeneration or con.ACEPointsRevision,
		Entity = ent,
		Reason = reason or "entity-updated",
		Armor = armorDirty and true or false,
		NonArmor = nonArmorDirty and true or false,
		Categories = event and event.Categories or nil,
		AffectedContraptions = event and event.AffectedContraptions or { con },
		CacheGenerations = {
			Points = con.ACEPointsGeneration or con.ACEPointsRevision,
			Armor = con.ACEArmorGeneration or 0,
			Ammo = con.ACEAmmoGeneration or 0,
			Firepower = con.ACEFirepowerGeneration or 0,
			ReadyRack = con.ACEReadyRackGeneration or 0,
			Warning = con.ACEWarningGeneration or 0,
		},
	})
end

-- Keep the historical hook-facing symbol available while consumers migrate to ACE.*.
ACE_NotifyContraptionPointsInvalidated = ACE.NotifyContraptionPointsInvalidated

local function ACE_CalcSubsystem(ents, subsystem)
	local total = 0

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local cls = ent:GetClass()
			if ACE.GetPtsType(cls) == subsystem then
				local pts
				if subsystem == "Crew" then
					pts = ACE.GetCrewSeatPointCost(ent)
				elseif subsystem == "Firepower" and (cls == "acf_gun" or cls == "acf_rack") then
					-- Never collapse by class or round ID: identical weapons bill independently.
					pts = ACE.GetGunFirepowerPointsFor(ent, ents)
				else
					pts = ACE.GetEntPoints(ent)
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
function ACE.CalcNonArmorPoints(con, baseEnt)
	if not con then
		return 0, { Engines = 0, Firepower = 0, Crew = 0, Electronics = 0 }
	end

	local totals = { Engines = 0, Firepower = 0, Crew = 0, Electronics = 0 }

	local ents = ACE.GetContraptionEntities(con, baseEnt)

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

function ACE.CalcContraptionArmorPoints(con, baseEnt)
	local total = 0
	local ents = ACE.GetContraptionEntities(con, baseEnt)

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local pts = ACE.GetArmorPoints(ent)
			if pts > 0 then
				total = total + pts
			end
		end
	end

	return total
end

-- Rebuild requested point totals for a contraption from entity state.
function ACE.RebuildContraptionPoints(con, baseEnt, rebuildArmor, rebuildNonArmor)
	if not IsLiveContraption(con) then return end

	local oldPoints = con.ACEPoints or 0
	local oldTotals = CopyPointTotals(con.ACEPointsPerType)
	local base = baseEnt
	if (not IsEnt(base)) and con.GetACEBaseplate then base = con:GetACEBaseplate() end

	local totals = con.ACEPointsPerType or {}

	if rebuildNonArmor then
		local nonArmor, nonArmorTotals = ACE.CalcNonArmorPoints(con, base)
		totals = nonArmorTotals or {}

		con.ACEPointsNonArmor = nonArmor or 0
		con.ACENonArmorDirty = false
	end

	if rebuildArmor then
		local armorPts = ACE.CalcContraptionArmorPoints(con, base)

		con.ACEArmorPoints = armorPts
		con.ACEArmorDirty = false
		con.ACEArmorCalculated = true
	end

	local armorPts = con.ACEArmorPoints or totals.Armor or 0
	totals.Armor = armorPts
	con.ACEPointsPerType = totals
	con.ACEPoints = (con.ACEPointsNonArmor or 0) + armorPts
	con.ACEPointsDirty = con.ACEArmorDirty or con.ACENonArmorDirty or false
	ACE.RebuildContraptionPointLedger(con, base)

	if hook and hook.Run then hook.Run("ACE_OnContraptionPointsRecalculated", con, {
		Revision = con.ACEPointsRevision or 0,
		Generation = con.ACEPointsGeneration or con.ACEPointsRevision or 0,
		OldTotal = oldPoints,
		Total = con.ACEPoints,
		OldByType = oldTotals,
		ByType = CopyPointTotals(totals),
		Armor = rebuildArmor and true or false,
		NonArmor = rebuildNonArmor and true or false,
	}) end
end

-- Ensure point data is initialized and current.
function ACE.EnsureContraptionPoints(con, baseEnt, force)
	if not IsLiveContraption(con) then return end
	if con._ACEPointsEnsuring then return end

	con._ACEPointsEnsuring = true
	if ACE.EnsurePointsState then ACE.EnsurePointsState(con) end
	ACE.FlushQueuedPointChanges()

	local cacheStale = ACE.EnsureCacheVersion and ACE.EnsureCacheVersion(con) or false
	local needsInit = not con.ACEArmorCalculated
	if not force and not needsInit and not con.ACEPointsDirty and not con.ACEArmorDirty
		and not con.ACENonArmorDirty and not cacheStale then
		con._ACEPointsEnsuring = nil
		return
	end

	local rebuildArmor = force or needsInit or con.ACEArmorDirty or cacheStale
	local rebuildNonArmor = force or con.ACENonArmorDirty or cacheStale or not con.ACEPointsPerType

	ACE.RebuildContraptionPoints(con, baseEnt, rebuildArmor, rebuildNonArmor)
	con._ACEPointsEnsuring = nil

	-- Invalidation marks warning state dirty, but a cache-version invalidation can
	-- arrive while this ensure is already rebuilding. Consume the warning state
	-- only after the new totals are available.
	if ACE.CheckLegalCont and con.ACEWarningsDirty and not con._ACEWarningChecking then
		con._ACEWarningChecking = true
		ACE.CheckLegalCont(con)
		con._ACEWarningChecking = nil
	end
end

_G.ACE_EnsureContraptionPoints = ACE.EnsureContraptionPoints

hook.Add("Think", "ACE_FlushQueuedPointChanges", ACE.FlushQueuedPointChanges)
