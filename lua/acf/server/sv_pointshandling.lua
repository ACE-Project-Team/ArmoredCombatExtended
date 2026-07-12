
ACE = ACE or {}

include("acf/shared/sh_ace_functions.lua")

local IsEnt = ACE_IsEnt

local pointCfg = ACE.PointCostConfig or {}
local MIN_DETAIL_PTS = tonumber(pointCfg.MinDetailPoints) or 150

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

-- Firepower detail label: "<name>: <rate>/s x <gate> x <roundCost>" so a player sees WHY a
-- weapon costs what it does -- sustained cadence x the share of the meta its pen defeats x the
-- raw per-round lethality. Racks use the tube-capped reload rate. Falls back to the bare name
-- (or name + rate) when the weapon has no priceable candidate round (e.g. a utility launcher).
local function ACE_FirepowerLabel(ent, conEnts)
	local name = ACE_GetEntityLabel(ent)
	local rate, gate, roundCost = ACE_GetGunFirepowerDetail(ent, conEnts)
	if not rate then return name end
	if not gate or not roundCost then
		return string.format("%s: %.2f/s", name, rate)
	end
	return string.format("%s: %.2f/s x %.2f x %.0f", name, rate, gate, roundCost)
end

-- Calculate one point subsystem (Engines / Firepower / Crew / Electronics) for a contraption.
-- Firepower prices guns and racks through the points model, using the precomputed contraption
-- entity list (candidate crates) so guns aren't re-resolved one at a time.
local function ACE_CalcSubsystem(ents, subsystem, minDetailPts)
	local total = 0
	local detailItems = {}

	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			local cls = ent:GetClass()
			if ACE_GetPtsType(cls) == subsystem then
				local pts, label
				if subsystem == "Crew" then
					pts = ACE_GetCrewSeatPointCost(ent)
					label = ACE_GetEntityLabel(ent)
				elseif subsystem == "Firepower" and (cls == "acf_gun" or cls == "acf_rack") then
					pts = ACE_GetGunFirepowerPointsFor(ent, ents)
					-- Only the honest decomposition is worth computing when the entry will show.
					if pts and pts >= minDetailPts then
						label = ACE_FirepowerLabel(ent, ents)
					else
						label = ACE_GetEntityLabel(ent)
					end
				else
					pts = ACE_GetEntPoints(ent)
					label = ACE_GetEntityLabel(ent)
				end

				if pts ~= 0 then
					total = total + pts
					ACE_AddDetailItem(detailItems, subsystem, label, pts, ent, minDetailPts)
				end
			end
		end
	end

	return total, detailItems
end

-- ============================================================
-- Point and armor calculation logic for contraption scans
-- ============================================================

-- Calculate non-armor points and readout details. Ammo is free (crates contribute nothing),
-- so the categories are Engines, Firepower (guns AND racks), Crew and Electronics. The
-- contraption entity list is resolved ONCE and shared across guns.
function ACE_CalcNonArmorPoints(con, baseEnt)
	if not con then
		return 0, { Engines = 0, Firepower = 0, Crew = 0, Electronics = 0 }, { Items = {} }
	end

	local totals = { Engines = 0, Firepower = 0, Crew = 0, Electronics = 0 }
	local detailItems = {}

	local ents = ACE_GetContraptionEntities(con, baseEnt)

	local subsystems = ACE.PointSubsystems or {
		"Engines",
		"Firepower",
		"Crew",
		"Electronics"
	}

	for _, subsystem in ipairs(subsystems) do
		local pts, items = ACE_CalcSubsystem(ents, subsystem, MIN_DETAIL_PTS)
		totals[subsystem] = pts or 0

		for _, item in ipairs(items) do
			detailItems[#detailItems + 1] = item
		end
	end

	local nonArmor = (totals.Engines or 0)
		+ (totals.Firepower or 0)
		+ (totals.Crew or 0)
		+ (totals.Electronics or 0)

	local trimmed = ACE_TrimDetailItems(detailItems, MIN_DETAIL_PTS)

	return nonArmor, totals, { Items = trimmed }
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
		local nonArmor, nonArmorTotals, details = ACE_CalcNonArmorPoints(con, base)
		totals = nonArmorTotals or {}

		con.ACEPointsNonArmor = nonArmor or 0
		con.ACEPointsDetails = details or { Items = {} }
		con.ACEAmmoCache = nil
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
