
ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")

local IsEnt = ACE_IsEnt

local pointCfg = ACE.PointCostConfig or {}
local MIN_DETAIL_PTS = tonumber(pointCfg.MinDetailPoints) or 300

-- Build a readable label for detail entries.
local function ACE_GetEntityLabel(ent)
	local label = ent:GetNWString("WireName")
	if label and label ~= "" then return label end
	if ent.Name and ent.Name ~= "" then return ent.Name end
	return ent:GetClass()
end

-- Add a high-cost item to the detail list.
local function ACE_AddDetailItem(detailItems, category, label, pts, ent, minDetailPts)
	if not pts or pts < (minDetailPts or 0) then return end
	detailItems[#detailItems + 1] = {
		category = category,
		label = label,
		pts = pts,
		idx = IsEnt(ent) and ent:EntIndex() or 0
	}
end

-- Sort and trim detail entries for the readout.
local function ACE_TrimDetailItems(detailItems, minDetailPts)
	table.sort(detailItems, function(a, b)
		if a.pts == b.pts then return a.idx < b.idx end
		return a.pts > b.pts
	end)

	local trimmed = {}
	for _, entry in ipairs(detailItems) do
		if entry.pts >= minDetailPts then
			trimmed[#trimmed + 1] = {
				Category = entry.category,
				Label = entry.label,
				Points = math.Round(entry.pts, 1)
			}
		end
	end

	return trimmed
end

-- Aggregate ammo counts for the readout.
local function ACE_AddAmmoLine(ammoLines, state, caliber, ammoType, count, points)
	if not count or count <= 0 then return end
	local calKey = caliber and math.floor(caliber + 0.5) or 0
	if calKey <= 0 then return end

	local typeKey = (ammoType ~= "" and ammoType) or "Ammo"
	local key = string.format("%s|%d|%s", state, calKey, typeKey)

	ammoLines[key] = ammoLines[key] or {
		State = state,
		Caliber = calKey,
		Type = typeKey,
		Count = 0,
		Points = 0
	}
	ammoLines[key].Count = ammoLines[key].Count + count
	ammoLines[key].Points = ammoLines[key].Points + (points or 0)
end

-- Convert ammo line buckets into a sorted list.
local function ACE_BuildAmmoLineList(ammoLines)
	local ammoList = {}
	for _, entry in pairs(ammoLines) do
		if entry.Count and entry.Count > 0 then
			ammoList[#ammoList + 1] = {
				State = entry.State,
				Caliber = entry.Caliber,
				Type = entry.Type,
				Count = math.floor(entry.Count + 0.5),
				Points = math.Round(entry.Points or 0, 1)
			}
		end
	end

	table.sort(ammoList, function(a, b)
		if a.State ~= b.State then return a.State < b.State end
		if a.Caliber ~= b.Caliber then return a.Caliber < b.Caliber end
		return a.Type < b.Type
	end)

	return ammoList
end


-- Build per-contraption ammo cache inputs. Order matters: the ready-rack alloc
-- weights each crate by its effective rounds, and "effective rounds" includes
-- the rack pre-load reserve -- so build the reserve first, then feed it in.
local function ACE_BuildAmmoCache(ents)
	local gunRpsById, racks = ACE_BuildGunRpsAndRacks(ents)
	local rackReserve = ACE_BuildRackReserveAlloc(ents, racks)
	local readyAlloc  = ACE_BuildAmmoReadyAlloc(ents, rackReserve)

	return {
		GunRpsById  = gunRpsById,
		Racks       = racks,
		ReadyAlloc  = readyAlloc,
		RackReserve = rackReserve
	}
end

-- Calculate ammo totals and readout data for a contraption.
local function ACE_CalcAmmoSubsystem(ents, minDetailPts)
	local totals = {
		Ammo = 0,
		Firepower = 0,
		AmmoReady = 0,
		AmmoReadyRounds = 0
	}

	local detailItems = {}
	local ammoLines = {}

	local ammoCache = ACE_BuildAmmoCache(ents)
	local gunRpsById = ammoCache.GunRpsById
	local racks = ammoCache.Racks
	local readyAlloc = ammoCache.ReadyAlloc
	local rackReserve = ammoCache.RackReserve

	for _, ent in ipairs(ents) do
		if IsEnt(ent) and ent:GetClass() == "acf_ammo" then
			local _, detail = ACE_CalcAmmoCratePoints(ent, gunRpsById, racks, readyAlloc, rackReserve)
			if detail then
				local rawCost = detail.RawAmmoCost or 0
				local dpsCost = detail.DPSCost or 0
				if rawCost <= 0 and dpsCost <= 0 then continue end

				totals.Ammo = totals.Ammo + rawCost
				totals.Firepower = totals.Firepower + dpsCost

				totals.AmmoReady = totals.AmmoReady + rawCost
				totals.AmmoReadyRounds = totals.AmmoReadyRounds + (detail.ReadyCount or 0)

				local ammoType = detail.Type ~= "" and detail.Type or "Ammo"
				local readyCount = math.floor((detail.ReadyCount or 0) + 0.5)

				if readyCount > 0 and rawCost > 0 then
					ACE_AddDetailItem(
						detailItems,
						"Ammo",
						string.format("%s x%d", ammoType, readyCount),
						rawCost,
						ent,
						minDetailPts
					)
				end

				ACE_AddAmmoLine(ammoLines, "READY", detail.Caliber, ammoType, readyCount, rawCost)
			end
		end
	end

	return totals, detailItems, ammoLines, ammoCache
end

-- Calculate non-ammo points for a single subsystem.
local function ACE_CalcNonAmmoSubsystem(ents, subsystem, minDetailPts)
	local total = 0
	local detailItems = {}

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local cls = ent:GetClass()
			local eclass = ACE_GetPtsType(cls)
			if eclass == subsystem then
				local pts
				if subsystem == "Crew" then
					pts = ACE_GetCrewSeatPointCost(ent)
				elseif subsystem == "Firepower" and (cls == "acf_gun" or cls == "acf_rack") then
					pts = ACE_GetGunFirepowerPoints(ent)
				else
					pts = ACE_GetEntPoints(ent)
				end
				if pts ~= 0 then
					total = total + pts
					ACE_AddDetailItem(
						detailItems,
						subsystem,
						ACE_GetEntityLabel(ent),
						pts,
						ent,
						minDetailPts
					)
				end
			end
		end
	end

	return total, detailItems
end

-- ============================================================
-- Point and armor calculation logic for contraption scans
-- ============================================================

-- Calculate the points value for an ammo crate.
function ACE_CalcAmmoCratePoints(crate, gunRpsById, racks, readyAlloc, rackReserve)
	if not IsEnt(crate) then return 0 end
	local bdata = crate.BulletData
	if not bdata then return 0 end

	-- Effective rounds = loose rounds in this crate + missiles pre-loaded into
	-- linked rack tubes that this crate could feed. The reserve portion comes
	-- from ACE_BuildRackReserveAlloc, which distributes each rack's MaxMissile
	-- across its compatible crates using the same rule that credits rack RPS
	-- to a crate below. Without the reserve, an 8-tube rack primed from a
	-- 2-round crate would price as if only those 2 loose rounds existed.
	local crateCapacity = crate.Capacity or 0
	local reserveRounds = (rackReserve and rackReserve[crate]) or 0
	local rounds = crateCapacity + reserveRounds
	if rounds <= 0 then return 0 end

	local maxPen = ACE_GetAmmoMaxPen(bdata)
	local blastMass = ACE_GetAmmoBlastMass(bdata)
	if maxPen <= 0 and blastMass <= 0 then return 0 end

	local calMm = ACE_GetAmmoCaliberMm(bdata)
	if calMm <= 0 then return 0 end

	local ammoId = bdata.Id
	if not ammoId then return 0 end

	local rpsTotal = gunRpsById[ammoId] or 0
	if racks and ACF_CanLinkRack then
		for _, rack in ipairs(racks) do
			if IsEnt(rack) and rack.Id and ACF_CanLinkRack(rack.Id, ammoId, bdata, rack) then
				rpsTotal = rpsTotal + ACE_GetEntRps(rack)
			end
		end
	end
	if rpsTotal <= 0 then return 0 end

	local cfg = ACE.AmmoCostConfig or {}
	local rpsFactor = ACE_GetRofThreatFactor(rpsTotal, cfg)
	if rpsFactor <= 0 then return 0 end
	local roundPts = ACE_GetAmmoRoundPoints(bdata)
	if roundPts <= 0 then return 0 end

	local readyCap = ACE_GetReadyRackCap(calMm)
	local readyCount = rounds

	if readyCap > 0 then
		readyCount = math.min(readyCap, rounds)
	end

	if readyAlloc and readyAlloc[crate] then
		readyCount = math.min(readyAlloc[crate], rounds)
	end

	local rawAmmoCost = roundPts * readyCount * rpsFactor

	local name = ACF_GetGunValue(ammoId, "name") or tostring(ammoId)
	local detail = {
		Name = name,
		Type = bdata.Type or "",
		Caliber = calMm,
		Capacity = rounds,
		MaxPen = maxPen,
		Rps = rpsTotal,
		Rpm = rpsTotal * 60,
		RofFactor = rpsFactor,
		ReadyCount = readyCount,
		RawAmmoCost = rawAmmoCost,
		DPSCost = 0,
		FirepowerCost = rawAmmoCost
	}

	return rawAmmoCost, detail
end


-- Calculate non-armor points and readout details.
function ACE_CalcNonArmorPoints(con, baseEnt)
	if not con then
		return 0, { Engines = 0, Firepower = 0, Ammo = 0, Crew = 0, Electronics = 0 }, { Items = {} }
	end

	local totals = {
		Engines = 0,
		Firepower = 0,
		Ammo = 0,
		AmmoReady = 0,
		AmmoReadyRounds = 0,
		Crew = 0,
		Electronics = 0
	}

	local detailItems = {}
	local ammoLines = {}
	local ammoCache

	local ents = ACE_GetContraptionEntities(con, baseEnt)
	local subsystems = ACE.PointSubsystems or {
		"Engines",
		"Firepower",
		"Ammo",
		"Crew",
		"Electronics"
	}

	for _, subsystem in ipairs(subsystems) do
		if subsystem == "Ammo" then
			local ammoTotals, ammoDetails, ammoLineMap, builtAmmoCache = ACE_CalcAmmoSubsystem(ents, MIN_DETAIL_PTS)

			totals.Ammo = ammoTotals.Ammo or 0
			totals.Firepower = (totals.Firepower or 0) + (ammoTotals.Firepower or 0)
			totals.AmmoReady = ammoTotals.AmmoReady or 0
			totals.AmmoReadyRounds = ammoTotals.AmmoReadyRounds or 0

			ammoLines = ammoLineMap or {}
			ammoCache = builtAmmoCache

			for _, item in ipairs(ammoDetails) do
				detailItems[#detailItems + 1] = item
			end
		else
			local pts, items = ACE_CalcNonAmmoSubsystem(ents, subsystem, MIN_DETAIL_PTS)
			totals[subsystem] = pts or 0

			for _, item in ipairs(items) do
				detailItems[#detailItems + 1] = item
			end
		end
	end

	totals.RawFirepower = totals.Firepower or 0
	totals.Firepower = math.max((totals.RawFirepower or 0) - (totals.Ammo or 0), 0)

	local nonArmor = (totals.Engines or 0)
		+ (totals.Firepower or 0)
		+ (totals.Ammo or 0)
		+ (totals.Crew or 0)
		+ (totals.Electronics or 0)

	local trimmed = ACE_TrimDetailItems(detailItems, MIN_DETAIL_PTS)
	local ammoList = ACE_BuildAmmoLineList(ammoLines)

	return nonArmor, totals, { Items = trimmed, AmmoLines = ammoList }, ammoCache
end

-- Calculate armor points and per-entity readout lines.
function ACE_CalcContraptionArmorPoints(con, baseEnt)
	local total = 0
	local details = {}
	local ents = ACE_GetContraptionEntities(con, baseEnt)

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local pts = ACE_GetArmorPoints(ent)
			if pts > 0 then
				total = total + pts
				details[#details + 1] = {
					Label = ACE_FormatDetailLabel(ent),
					Points = ACE_SafeRound1(pts),
					EntIndex = ent:EntIndex()
				}
			end
		end
	end

	table.sort(details, function(a, b)
		if a.Points == b.Points then
			if a.EntIndex == b.EntIndex then return tostring(a.Label) < tostring(b.Label) end
			return a.EntIndex < b.EntIndex
		end
		return a.Points > b.Points
	end)

	return total, details
end

-- Rebuild requested point totals for a contraption from entity state.
function ACE_RebuildContraptionPoints(con, baseEnt, rebuildArmor, rebuildNonArmor)
	if not con then return end

	local base = baseEnt
	if (not IsEnt(base)) and con.GetACEBaseplate then base = con:GetACEBaseplate() end

	local totals = con.ACEPointsPerType or {}

	if rebuildNonArmor then
		local nonArmor, nonArmorTotals, details, ammoCache = ACE_CalcNonArmorPoints(con, base)
		totals = nonArmorTotals or {}

		con.ACEPointsNonArmor = nonArmor or 0
		con.ACEPointsDetails = details or { Items = {}, AmmoLines = {} }
		con.ACEAmmoCache = ammoCache
		con.ACENonArmorDirty = false
	end

	if rebuildArmor then
		local armorPts, armorDetails = ACE_CalcContraptionArmorPoints(con, base)

		con.ACEArmorPoints = armorPts
		con.ACEArmorFront = 0
		con.ACEArmorSide = 0
		con.ACEArmorDetails = armorDetails or {}
		con.ACEArmorDirty = false
		con.ACEArmorCalculated = true
		con.ACEArmorLastCalc = CurTime()
	end

	local armorPts = con.ACEArmorPoints or totals.Armor or 0
	totals.Armor = armorPts
	con.ACEPointsPerType = totals
	con.ACEPoints = (con.ACEPointsNonArmor or 0) + armorPts
	con.ACEPointsDirty = con.ACEArmorDirty or con.ACENonArmorDirty or false

	if not con.ACEPointsDirty then
		con.OTWarnings = con.OTWarnings or {}
		con.OTWarnings.WarnedModified = false
	end
end

-- Ensure point data is initialized and current.
function ACE_EnsureContraptionPoints(con, baseEnt, force)
	if not con then return end

	local cacheStale = ACE_EnsureCacheVersion and ACE_EnsureCacheVersion(con) or false
	local needsInit = not con.ACEArmorCalculated or (con.ACEArmorLastCalc or 0) <= 0
	if not force and not needsInit and not con.ACEPointsDirty and not con.ACEArmorDirty
		and not con.ACENonArmorDirty and not cacheStale then
		return
	end

	local rebuildArmor = force or needsInit or con.ACEArmorDirty or cacheStale
	local rebuildNonArmor = force or con.ACENonArmorDirty or cacheStale or not con.ACEPointsPerType

	ACE_RebuildContraptionPoints(con, baseEnt, rebuildArmor, rebuildNonArmor)
end

_G.ACE_EnsureContraptionPoints = ACE_EnsureContraptionPoints

