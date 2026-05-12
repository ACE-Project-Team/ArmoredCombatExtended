
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


-- Build per-contraption ammo cache inputs.
local function ACE_BuildAmmoCache(ents)
	local gunRpsById, racks = ACE_BuildGunRpsAndRacks(ents)
	local readyAlloc = ACE_BuildAmmoReadyAlloc(ents)

	return {
		GunRpsById = gunRpsById,
		Racks = racks,
		ReadyAlloc = readyAlloc
	}
end

-- Calculate ammo totals and readout data for a contraption.
local function ACE_CalcAmmoSubsystem(ents, minDetailPts)
	local totals = {
		Ammo = 0,
		AmmoReady = 0,
		AmmoBackup = 0,
		AmmoReadyRounds = 0,
		AmmoBackupRounds = 0
	}

	local detailItems = {}
	local ammoLines = {}

	local ammoCache = ACE_BuildAmmoCache(ents)
	local gunRpsById = ammoCache.GunRpsById
	local racks = ammoCache.Racks
	local readyAlloc = ammoCache.ReadyAlloc

	for _, ent in ipairs(ents) do
		if IsEnt(ent) and ent:GetClass() == "acf_ammo" then
			local pts, detail = ACE_CalcAmmoCratePoints(ent, gunRpsById, racks, readyAlloc)
			if pts > 0 then
				totals.Ammo = totals.Ammo + pts

				if detail then
					totals.AmmoReady = totals.AmmoReady + (detail.ReadyCost or 0)
					totals.AmmoBackup = totals.AmmoBackup + (detail.StowCost or 0)
					totals.AmmoReadyRounds = totals.AmmoReadyRounds + (detail.ReadyCount or 0)
					totals.AmmoBackupRounds = totals.AmmoBackupRounds + (detail.StowCount or 0)

					local ammoType = detail.Type ~= "" and detail.Type or "Ammo"
					local readyCount = math.floor((detail.ReadyCount or 0) + 0.5)
					local stowCount = math.floor((detail.StowCount or 0) + 0.5)
					local readyCost = detail.ReadyCost or 0
					local stowCost = detail.StowCost or 0

					if readyCount > 0 and readyCost > 0 then
						ACE_AddDetailItem(
							detailItems,
							"Ammo",
							string.format("Ready rack %s x%d", ammoType, readyCount),
							readyCost,
							ent,
							minDetailPts
						)
					end
					if stowCount > 0 and stowCost > 0 then
						ACE_AddDetailItem(
							detailItems,
							"Ammo",
							string.format("Backup ammo %s x%d", ammoType, stowCount),
							stowCost,
							ent,
							minDetailPts
						)
					end

					ACE_AddAmmoLine(ammoLines, "READY", detail.Caliber, ammoType, readyCount, readyCost)
					if stowCost > 0 then
						ACE_AddAmmoLine(ammoLines, "BACKUP", detail.Caliber, ammoType, stowCount, stowCost)
					end
				end
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
					pts = tonumber(ACE.CrewSeatPointCost)
						or tonumber((ACE.PointCostConfig or {}).CrewSeatFlat)
						or 250
				elseif subsystem == "Firepower" and cls == "acf_gun" then
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
function ACE_CalcAmmoCratePoints(crate, gunRpsById, racks, readyAlloc)
	if not IsEnt(crate) then return 0 end
	local bdata = crate.BulletData
	if not bdata then return 0 end

	local rounds = crate.Capacity or 0
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

	local stowFactor = cfg.StowFactor or 1
	local tailFactor = cfg.TailFactor or 0
	local tailStartMul = cfg.TailStartMultiplier or 0

	local readyCap = ACE_GetReadyRackCap(calMm)
	local readyCount = rounds
	local stowCount = 0

	if readyCap > 0 then
		readyCount = math.min(readyCap, rounds)
		stowCount = math.max(rounds - readyCount, 0)
	end

	if readyAlloc and readyAlloc[crate] then
		readyCount = math.min(readyAlloc[crate], rounds)
		stowCount = math.max(rounds - readyCount, 0)
	end

	local readyCost = roundPts * readyCount * rpsFactor
	local stowCost = roundPts * stowCount * stowFactor * rpsFactor

	if readyCap > 0 and tailFactor > 0 and tailStartMul > 0 then
		local tailStart = readyCap * tailStartMul
		local tail = math.max(rounds - tailStart, 0)
		if tail > 0 then
			stowCost = stowCost - (roundPts * tail * tailFactor * rpsFactor)
			if stowCost < 0 then stowCost = 0 end
		end
	end

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
		StowCount = stowCount,
		ReadyCost = readyCost,
		StowCost = stowCost
	}

	return readyCost + stowCost, detail
end


-- Sum legacy manufacturing cost for a contraption.
function ACE_CalcContraptionLegacyCost(con, baseEnt)
	local total = 0
	local ents = ACE_GetContraptionEntities(con, baseEnt)
	for _, ent in ipairs(ents) do
		if IsEnt(ent) then
			total = total + ACE_GetEntLegacyCost(ent)
		end
	end
	return total
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
		AmmoBackup = 0,
		AmmoReadyRounds = 0,
		AmmoBackupRounds = 0,
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
			totals.AmmoReady = ammoTotals.AmmoReady or 0
			totals.AmmoBackup = ammoTotals.AmmoBackup or 0
			totals.AmmoReadyRounds = ammoTotals.AmmoReadyRounds or 0
			totals.AmmoBackupRounds = ammoTotals.AmmoBackupRounds or 0

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

	local nonArmor = (totals.Engines or 0)
		+ (totals.Firepower or 0)
		+ (totals.Ammo or 0)
		+ (totals.Crew or 0)
		+ (totals.Electronics or 0)

	local trimmed = ACE_TrimDetailItems(detailItems, MIN_DETAIL_PTS)
	local ammoList = ACE_BuildAmmoLineList(ammoLines)

	return nonArmor, totals, { Items = trimmed, AmmoLines = ammoList }, ammoCache
end

-- Recompute cached non-armor totals for a contraption.
function ACE_RebuildNonArmorPoints(con, baseEnt)
	if not con then return end

	local ents = ACE_GetContraptionEntities(con, baseEnt)
	local subsystems = ACE.PointSubsystems or {
		"Engines",
		"Firepower",
		"Ammo",
		"Crew",
		"Electronics"
	}

	con.ACESubsystemCache = con.ACESubsystemCache or {}
	con.ACESubsystemDirty = con.ACESubsystemDirty or {}
	ACE.DupeSubsystemCache = ACE.DupeSubsystemCache or {}

	local dupeKeys = con.ACEDupeSubsystemKeys
	if not istable(dupeKeys) then
		dupeKeys = {}
	end

	-- Resolve a cache key for the subsystem and update stored keys.
	local function getSubsystemKey(subsystem)
		local key = dupeKeys[subsystem]
		if key then return key end

		key = ACE_GetSubsystemSignatureFromEnts(subsystem, ents)
		if key then
			dupeKeys[subsystem] = key
		end
		return key
	end

	-- Load or compute cached data for a subsystem.
	local function cacheSubsystem(subsystem)
		local cached = con.ACESubsystemCache[subsystem]
		if cached and not con.ACESubsystemDirty[subsystem] then
			return cached
		end

		local key = getSubsystemKey(subsystem)
		if key then
			local shared = ACE.DupeSubsystemCache[key]
			if shared then
				if subsystem == "Ammo" then
					local ammoCache = ACE_BuildAmmoCache(ents)
					local data = {
						Totals = shared.Totals or {},
						Details = shared.Details or {},
						AmmoLines = shared.AmmoLines or {},
						AmmoCache = ammoCache
					}
					con.ACESubsystemCache[subsystem] = data
					con.ACESubsystemDirty[subsystem] = false
					return data
				end

				con.ACESubsystemCache[subsystem] = shared
				con.ACESubsystemDirty[subsystem] = false
				return shared
			end
		end

		local data
		if subsystem == "Ammo" then
			local ammoTotals, ammoDetails, ammoLines, ammoCache = ACE_CalcAmmoSubsystem(ents, MIN_DETAIL_PTS)
			data = {
				Totals = ammoTotals,
				Details = ammoDetails,
				AmmoLines = ammoLines,
				AmmoCache = ammoCache
			}
		else
			local pts, items = ACE_CalcNonAmmoSubsystem(ents, subsystem, MIN_DETAIL_PTS)
			data = {
				Totals = { [subsystem] = pts or 0 },
				Details = items
			}
		end

		con.ACESubsystemCache[subsystem] = data
		con.ACESubsystemDirty[subsystem] = false

		if key then
			if subsystem == "Ammo" then
				ACE.DupeSubsystemCache[key] = {
					Totals = data.Totals,
					Details = data.Details,
					AmmoLines = data.AmmoLines
				}
			else
				ACE.DupeSubsystemCache[key] = data
			end
		end

		return data
	end

	local totals = {
		Engines = 0,
		Firepower = 0,
		Ammo = 0,
		AmmoReady = 0,
		AmmoBackup = 0,
		AmmoReadyRounds = 0,
		AmmoBackupRounds = 0,
		Crew = 0,
		Electronics = 0
	}

	local detailItems = {}
	local ammoLines = {}

	for _, subsystem in ipairs(subsystems) do
		local data = cacheSubsystem(subsystem)
		if data and data.Totals then
			for k, v in pairs(data.Totals) do
				totals[k] = (totals[k] or 0) + (v or 0)
			end
		end

		if data and data.Details then
			for _, item in ipairs(data.Details) do
				detailItems[#detailItems + 1] = item
			end
		end

		if subsystem == "Ammo" and data then
			ammoLines = data.AmmoLines or {}
			con.ACEAmmoCache = data.AmmoCache
		end
	end

	local nonArmor = (totals.Engines or 0)
		+ (totals.Firepower or 0)
		+ (totals.Ammo or 0)
		+ (totals.Crew or 0)
		+ (totals.Electronics or 0)

	con.ACEPointsNonArmor = nonArmor
	con.ACEPointsPerType = con.ACEPointsPerType or {}

	for k, v in pairs(totals) do
		con.ACEPointsPerType[k] = v
	end

	con.ACEPointsDetails = {
		Items = ACE_TrimDetailItems(detailItems, MIN_DETAIL_PTS),
		AmmoLines = ACE_BuildAmmoLineList(ammoLines)
	}

	con.ACEDupeSubsystemKeys = next(dupeKeys) and dupeKeys or nil
	con.ACENonArmorDirty = false
end


-- ============================================================
-- Armor scan logic
-- ============================================================

ACE_CalcContraptionArmor = function(ent)
	if not IsEnt(ent) then return 0, 0 end

	-- Resolve direction vectors and scan LOS armor samples.

	local contraption = ent.GetContraption and ent:CFW_GetContraption() or nil
	local contraptionId = contraption and ACE_GetContraptionIndex and ACE_GetContraptionIndex(contraption)
		or (ent.ACF and ent.ACF.ContraptionId)

	local contraptionEnts = {}

	if contraption and contraption.ents then
		for candidate in pairs(contraption.ents) do
			if IsEnt(candidate) then contraptionEnts[#contraptionEnts + 1] = candidate end
		end
	elseif contraptionId then
		for _, candidate in ipairs(ACE.contraptionEnts or {}) do
			if IsEnt(candidate) then
				local acf = candidate.ACF
				if acf and acf.ContraptionId == contraptionId then
					contraptionEnts[#contraptionEnts + 1] = candidate
				end
			end
		end
	end

	if #contraptionEnts == 0 then contraptionEnts[1] = ent end
	if #contraptionEnts > 1 then
		table.sort(contraptionEnts, function(a, b) return a:EntIndex() < b:EntIndex() end)
	end

	local contraptionSet = {}
	for _, comp in ipairs(contraptionEnts) do
		contraptionSet[comp] = true
	end

	-- Normalize a vector or return nil.
	local function normalizeOrNil(vec)
		if not vec then return nil end
		local len = vec:Length()
		if len <= 1e-6 then return nil end
		return vec / len
	end

	-- Project a vector onto a plane.
	local function flattenToPlane(vec, up)
		if not vec or not up then return nil end
		return normalizeOrNil(vec - up * vec:Dot(up))
	end

	-- Resolve a world-up vector from gravity.
	local function getWorldUp()
		local gravity = physenv and physenv.GetGravity and physenv.GetGravity() or Vector(0, 0, -1)
		if gravity:LengthSqr() <= 1e-6 then return Vector(0, 0, 1) end
		return (-gravity):GetNormalized()
	end

	local function getWorldPlaneBasis(up)
		local seedFront = flattenToPlane(Vector(1, 0, 0), up)
			or flattenToPlane(Vector(0, 1, 0), up)
			or Vector(1, 0, 0)
		local seedSide = normalizeOrNil(up:Cross(seedFront)) or Vector(0, 1, 0)

		return seedFront, seedSide
	end

	local origin = Vector(0, 0, 0)
	local originCount = 0
	for _, comp in ipairs(contraptionEnts) do
		if not IsEnt(comp) then continue end
		origin = origin + comp:WorldSpaceCenter()
		originCount = originCount + 1
	end
	origin = originCount > 0 and (origin / originCount) or ent:WorldSpaceCenter()

	-- Detect sphered wheel props.
	local function isMakeSpherical(e)
		local override = e and e.RenderOverride
		return override and tostring(override):find("MakeSpherical") ~= nil
	end

	-- Compute world-space bounds for a prop.
	local function getBoundsWorld(prop, scale)
		local mins, maxs = prop:OBBMins(), prop:OBBMaxs()
		scale = scale or 0.75
		local corners = {
			Vector(mins.x, mins.y, mins.z),
			Vector(mins.x, mins.y, maxs.z),
			Vector(mins.x, maxs.y, mins.z),
			Vector(mins.x, maxs.y, maxs.z),
			Vector(maxs.x, mins.y, mins.z),
			Vector(maxs.x, mins.y, maxs.z),
			Vector(maxs.x, maxs.y, mins.z),
			Vector(maxs.x, maxs.y, maxs.z)
		}
		for i, v in ipairs(corners) do
			corners[i] = prop:LocalToWorld(v * scale)
		end
		return corners
	end

	local function getShapeSampleWeight(comp)
		local size = comp:OBBMaxs() - comp:OBBMins()
		local volume = math.abs(size.x * size.y * size.z)

		return math.max(volume ^ (1 / 3), 1)
	end

	local function addAligned(sum, vec, weight)
		vec = normalizeOrNil(vec)
		if not vec then return sum end

		if sum:LengthSqr() > 1e-6 and vec:Dot(sum) < 0 then vec = -vec end

		return sum + vec * (weight or 1)
	end

	-- Estimate left/right from wheel positions relative to their constrained bases.
	local function getWheelBaseSide(ents, up)
		if not constraint or not constraint.FindConstraints then return nil, 0 end

		local sideSum = Vector(0, 0, 0)
		local seenPairs = {}
		local pairCount = 0

		for _, base in ipairs(ents) do
			if not IsEnt(base) then continue end
			if isMakeSpherical(base) then continue end

			local cons = constraint.FindConstraints(base, "Axis")
			if not istable(cons) then continue end

			for _, con in ipairs(cons) do
				if not con or (con.Ent1 ~= base and con.Ent2 ~= base) then continue end

				local other = (con.Ent1 == base) and con.Ent2 or con.Ent1
				if not IsEnt(other) or not isMakeSpherical(other) then continue end

				local pairKey = math.min(base:EntIndex(), other:EntIndex()) .. ":" .. math.max(base:EntIndex(), other:EntIndex())
				if seenPairs[pairKey] then continue end
				seenPairs[pairKey] = true

				local rel = flattenToPlane(other:WorldSpaceCenter() - base:WorldSpaceCenter(), up)
				if not rel then continue end
				local relLen = rel:Length()
				if relLen <= 1e-6 then continue end

				sideSum = addAligned(sideSum, rel, relLen)
				pairCount = pairCount + 1
			end
		end

		return normalizeOrNil(sideSum), pairCount
	end

	-- Build a horizontal basis from the contraption footprint.
	local function getShapeBasis(ents, up)
		local seedFront, seedSide = getWorldPlaneBasis(up)
		local points = {}
		local totalWeight = 0
		local sumX = 0
		local sumY = 0

		for _, comp in ipairs(ents) do
			if not IsEnt(comp) or isMakeSpherical(comp) then continue end

			local rel = comp:WorldSpaceCenter() - origin
			local px = rel:Dot(seedFront)
			local py = rel:Dot(seedSide)
			local weight = getShapeSampleWeight(comp)

			points[#points + 1] = { x = px, y = py, w = weight }
			totalWeight = totalWeight + weight
			sumX = sumX + px * weight
			sumY = sumY + py * weight
		end

		if totalWeight <= 1e-6 then return nil, nil end

		local meanX = sumX / totalWeight
		local meanY = sumY / totalWeight
		local covXX = 0
		local covXY = 0
		local covYY = 0

		for _, point in ipairs(points) do
			local dx = point.x - meanX
			local dy = point.y - meanY
			local weight = point.w or 1
			covXX = covXX + dx * dx * weight
			covXY = covXY + dx * dy * weight
			covYY = covYY + dy * dy * weight
		end

		if covXX <= 1e-6 and covYY <= 1e-6 then return nil, nil end

		local majorX, majorY
		if math.abs(covXY) <= 1e-6 then
			if covXX >= covYY then
				majorX, majorY = 1, 0
			else
				majorX, majorY = 0, 1
			end
		else
			local trace = covXX + covYY
			local disc = math.sqrt(math.max((covXX - covYY) ^ 2 + 4 * covXY * covXY, 0))
			local lambda = 0.5 * (trace + disc)
			majorX = covXY
			majorY = lambda - covXX
		end

		local majorAxis = normalizeOrNil(seedFront * majorX + seedSide * majorY)
		local minorAxis = majorAxis and normalizeOrNil(up:Cross(majorAxis)) or nil
		if not majorAxis or not minorAxis then return nil, nil end

		return majorAxis, minorAxis
	end

	local function getEntOrientationWeight(comp)
		local size = comp:OBBMaxs() - comp:OBBMins()
		return math.max(size:Length(), 1)
	end

	local function getAxisSpan(ents, axis)
		local minDot = math.huge
		local maxDot = -math.huge

		for _, comp in ipairs(ents) do
			if not IsEnt(comp) then continue end

			for _, corner in ipairs(getBoundsWorld(comp, 1)) do
				local dot = corner:Dot(axis)
				if dot < minDot then minDot = dot end
				if dot > maxDot then maxDot = dot end
			end
		end

		if minDot == math.huge or maxDot == -math.huge then return 0 end

		return maxDot - minDot
	end

	-- Resolve which principal axis is forward/side using contraption-wide orientation agreement.
	local function resolveBasisFromVotes(ents, up, axisA, axisB, wheelSide, wheelPairs)
		if not axisA or not axisB then return nil, nil end

		local spanA = getAxisSpan(ents, axisA)
		local spanB = getAxisSpan(ents, axisB)
		local abScore = spanA
		local baScore = spanB
		local abFrontSign = 0
		local abSideSign = 0
		local baFrontSign = 0
		local baSideSign = 0

		for _, comp in ipairs(ents) do
			if not IsEnt(comp) or isMakeSpherical(comp) then continue end

			local class = comp:GetClass()
			local forward = flattenToPlane(comp:GetForward(), up)
			local right = flattenToPlane(comp:GetRight(), up)
			if not forward and not right then continue end

			local weight = getEntOrientationWeight(comp)
			local weaponWeight = (class == "acf_gun" or class == "acf_rack") and 1.5 or 1
			local scoreAB = ((forward and math.abs(forward:Dot(axisA))) or 0) + ((right and math.abs(right:Dot(axisB))) or 0)
			local scoreBA = ((forward and math.abs(forward:Dot(axisB))) or 0) + ((right and math.abs(right:Dot(axisA))) or 0)

			abScore = abScore + scoreAB * weight
			baScore = baScore + scoreBA * weight

			if forward then
				abFrontSign = abFrontSign + forward:Dot(axisA) * weight * weaponWeight
				baFrontSign = baFrontSign + forward:Dot(axisB) * weight * weaponWeight
			end
			if right then
				abSideSign = abSideSign + right:Dot(axisB) * weight
				baSideSign = baSideSign + right:Dot(axisA) * weight
			end
		end

		if wheelSide then
			local wheelWeight = math.max(wheelPairs or 0, 1) * 2
			abScore = abScore + math.abs(wheelSide:Dot(axisB)) * wheelWeight
			baScore = baScore + math.abs(wheelSide:Dot(axisA)) * wheelWeight
			abSideSign = abSideSign + wheelSide:Dot(axisB) * wheelWeight
			baSideSign = baSideSign + wheelSide:Dot(axisA) * wheelWeight
		end

		local frontAxis, sideAxis, frontSign, sideSign
		if abScore >= baScore then
			frontAxis, sideAxis = axisA, axisB
			frontSign, sideSign = abFrontSign, abSideSign
		else
			frontAxis, sideAxis = axisB, axisA
			frontSign, sideSign = baFrontSign, baSideSign
		end

		if frontSign < 0 then
			frontAxis = -frontAxis
		end

		local rightHandedSide = normalizeOrNil(up:Cross(frontAxis))
		if sideSign < 0 or (math.abs(sideSign) <= 1e-6 and rightHandedSide and sideAxis:Dot(rightHandedSide) < 0) then
			sideAxis = -sideAxis
		end

		return frontAxis, sideAxis
	end

	-- Build a stable basis: shape first, then wheel evidence, then simple entity-axis fallback.
	local upDir = getWorldUp()
	local wheelSide, wheelPairs = getWheelBaseSide(contraptionEnts, upDir)
	local shapeMajor, shapeMinor = getShapeBasis(contraptionEnts, upDir)
	local frontDir, sideDir = resolveBasisFromVotes(contraptionEnts, upDir, shapeMajor, shapeMinor, wheelSide, wheelPairs)
	local worldFront = getWorldPlaneBasis(upDir)

	frontDir = frontDir
		or shapeMajor
		or worldFront
		or Vector(1, 0, 0)
	sideDir = sideDir
		or wheelSide
		or normalizeOrNil(upDir:Cross(frontDir))
		or Vector(0, 1, 0)

	sideDir = normalizeOrNil(sideDir - frontDir * sideDir:Dot(frontDir)) or sideDir

	local adjustedFront = normalizeOrNil(sideDir:Cross(upDir))
	if adjustedFront and adjustedFront:Dot(frontDir) < 0 then adjustedFront = -adjustedFront end
	frontDir = adjustedFront or frontDir

	local debugDraw = ACE.ArmorDebugCvar and ACE.ArmorDebugCvar:GetBool() or false

	-- Critical components are sampled for forward armor bias.
	local function isEmptyAmmoCrate(ent)
		if not IsEnt(ent) or ent:GetClass() ~= "acf_ammo" then return false end
		return (tonumber(ent.Ammo) or 0) <= 0
	end

	local criticals = {}
	local fallbackCriticals = {}
	for _, cent in ipairs(contraptionEnts) do
		if IsEnt(cent) then
			local cls = cent:GetClass()
			if cls == "acf_ammo" and isEmptyAmmoCrate(cent) then
				continue
			end

			if cls == "acf_ammo" or cls == "acf_fueltank" or cls == "acf_engine"
				or cls == "ace_crewseat_gunner" or cls == "ace_crewseat_loader" or cls == "ace_crewseat_driver" then
				criticals[#criticals + 1] = cent
			elseif cls == "acf_gun" or cls == "acf_rack" then
				fallbackCriticals[#fallbackCriticals + 1] = cent
			end
		end
	end

	if #criticals == 0 and #fallbackCriticals > 0 then
		criticals = fallbackCriticals
	end

	local ignoredArmor = table.Copy(ACF.TraceFilter or {})
	table.Merge(ignoredArmor, {
		acf_gun = false,
		acf_rack = false,
		ace_crewseat_gunner = true,
		ace_crewseat_loader = true,
		ace_crewseat_driver = true
	})

	-- Build an orthonormal basis from a direction.
	local function basisFromDir(dir)
		dir = dir:GetNormalized()
		local upHint = (math.abs(dir.z) < 0.99) and Vector(0, 0, 1) or Vector(1, 0, 0)
		local u = dir:Cross(upHint):GetNormalized()
		local v = dir:Cross(u):GetNormalized()
		return u, v
	end

	-- Calculate projected area and centroid.
	local function projectedData(comp, dir)
		local u, v = basisFromDir(dir)
		local corners = getBoundsWorld(comp)

		local minU, maxU = math.huge, -math.huge
		local minV, maxV = math.huge, -math.huge

		for _, wpos in ipairs(corners) do
			local pu, pv = wpos:Dot(u), wpos:Dot(v)
			if pu < minU then minU = pu end
			if pu > maxU then maxU = pu end
			if pv < minV then minV = pv end
			if pv > maxV then maxV = pv end
		end

		local area = (maxU - minU) * (maxV - minV)
		return area, (maxU - minU) * 0.5, (maxV - minV) * 0.5
	end

	-- Sample the actual world-space extent instead of component-local right/up axes.
	local function getSamplePoints(comp)
		local samples = getBoundsWorld(comp, 0.95)
		samples[#samples + 1] = comp:WorldSpaceCenter()

		return samples
	end

	local frontU, frontV = basisFromDir(frontDir)
	local sideU, sideV = basisFromDir(sideDir)

	local scanCfg = ACE.ArmorScanConfig or {}
	local regionSnap = scanCfg.RegionSnap or 2
	local tracePadding = scanCfg.TracePadding or 64

	local function getProjectionRange(dir)
		local minDot = math.huge
		local maxDot = -math.huge

		for _, comp in ipairs(contraptionEnts) do
			if not IsEnt(comp) then continue end

			for _, corner in ipairs(getBoundsWorld(comp, 1)) do
				local dot = corner:Dot(dir)
				if dot < minDot then minDot = dot end
				if dot > maxDot then maxDot = dot end
			end
		end

		if minDot == math.huge or maxDot == -math.huge then
			local centerDot = origin:Dot(dir)
			return centerDot, centerDot
		end

		return minDot, maxDot
	end

	local frontMin = getProjectionRange(frontDir)
	local sideMin, sideMax = getProjectionRange(sideDir)

	-- Build a region bucket key.
	local function regionKey(pos, u, v)
		if not pos then return nil end
		local rel = pos - origin
		local ku = math.floor(rel:Dot(u) / regionSnap + 0.5)
		local kv = math.floor(rel:Dot(v) / regionSnap + 0.5)
		return ku .. ":" .. kv
	end

	-- Accumulate armor region statistics.
	local function updateRegion(regions, key, val, weight)
		if not key or val <= 0 then return end
		local cur = regions[key]
		if not cur or val > cur.val then
			regions[key] = { val = val, weight = weight }
		end
	end

	local hullSize = scanCfg.TraceHullSize or 3
	local TRACE_HULL_MINS = Vector(-hullSize, -hullSize, -hullSize)
	local TRACE_HULL_MAXS = Vector(hullSize, hullSize, hullSize)
	local TRACE_MAX_STEPS = scanCfg.TraceMaxSteps or 128

	-- Calculate effective LOS armor at a trace impact point.
	local function calcLosArmor(hitEnt, hitNormal, shotDir)
		local acf = hitEnt.ACF
		if not istable(acf) then return 0 end

		local mat = acf.Material or "RHA"
		local matData = ACE_GetMaterialData(mat)
		local armor = acf.Armour or 0
		if armor <= 0 then return 0 end

		local armorData = hitEnt.acfPropArmorData and hitEnt:acfPropArmorData()
		local effKE = (armorData and armorData.Effectiveness) or (matData and matData.effectiveness) or 1
		local effCHEM = (armorData and (armorData.HEATeffectiveness or armorData.HEATEffectiveness))
			or (matData and (matData.HEATeffectiveness or matData.effectiveness))
			or effKE

		local eff = effKE * 0.8 + effCHEM * 0.2
		local curve = (armorData and armorData.Curve) or 1
		local ang = ACF_GetHitAngle(hitNormal, shotDir)

		if ang >= 89 then
			return (armor ^ curve) * eff
		end

		local cosAng = math.max(math.cos(math.rad(ang)), 0.01)
		local los = (armor / (cosAng ^ ACF.SlopeEffectFactor)) ^ curve
		return los * eff
	end

	-- Line-of-sight test with filter rules.
	local function losFiltered(startPos, endPos, targetComp)
		local filter = {}
		local total = 0
		local dir = (endPos - startPos):GetNormalized()
		local hitTarget = false

		for _ = 1, TRACE_MAX_STEPS do
			-- Small hull keeps thin props from slipping through the trace.
			local tr = util.TraceHull({
				start = startPos,
				endpos = endPos,
				mins = TRACE_HULL_MINS,
				maxs = TRACE_HULL_MAXS,
				filter = filter,
				mask = MASK_SOLID
			})

			if not tr.Hit then break end
			local hitEnt = tr.Entity
			if not IsEnt(hitEnt) then break end

			if not contraptionSet[hitEnt] then
				filter[#filter + 1] = hitEnt
				startPos = tr.HitPos + dir * 0.1
			else
				local skip = false

				if hitEnt.RenderOverride and tostring(hitEnt.RenderOverride):find("MakeSpherical") then
					skip = true
				end

				if not skip and hitEnt == targetComp then
					hitTarget = true
					break
				end

				if not skip then
					local cls = hitEnt:GetClass()
					local skipArmor = ignoredArmor[cls] or not ACF_Check(hitEnt)
					if not skipArmor and cls == "acf_ammo" and isEmptyAmmoCrate(hitEnt) then
						skipArmor = true
					end
					if skipArmor then
						skip = true
					elseif ACF_CheckClips(hitEnt, tr.HitPos) then
						skip = true
					end
				end

				if skip then
					filter[#filter + 1] = hitEnt
					startPos = tr.HitPos + dir * 0.1
				else
					total = total + calcLosArmor(hitEnt, tr.HitNormal, dir)
					filter[#filter + 1] = hitEnt
					startPos = tr.HitPos + dir * 0.1
				end
			end
		end

		if not hitTarget then return 0 end
		return total
	end

	-- Map a ratio to a debug color.
	local function ACE_DebugColorRatio(r)
		r = math.Clamp(r or 0, 0, 1)

		-- red -> yellow -> green
		local rr = math.floor(255 * (1 - r))
		local gg = math.floor(255 * r)
		local bb = 0

		-- keep it readable when low
		if r < 0.5 then
			gg = math.floor(255 * (r * 2))
			rr = 255
		else
			rr = math.floor(255 * (1 - (r - 0.5) * 2))
			gg = 255
		end

		return Color(rr, gg, bb, 255)
	end

	local debugSamples = debugDraw and {} or nil
	local debugMaxLOS = 0

	local frontRegions, sideRegions = {}, {}
	local compContrib = {}

	for _, comp in ipairs(criticals) do
		local frontArea = projectedData(comp, frontDir)
		local sideArea = projectedData(comp, sideDir)
		local compFrontMin = math.huge
		local compSideMin = math.huge
		local compSideMax = -math.huge

		for _, corner in ipairs(getBoundsWorld(comp, 1)) do
			local frontDot = corner:Dot(frontDir)
			local sideDot = corner:Dot(sideDir)
			if frontDot < compFrontMin then compFrontMin = frontDot end
			if sideDot < compSideMin then compSideMin = sideDot end
			if sideDot > compSideMax then compSideMax = sideDot end
		end

		local samples = getSamplePoints(comp)

		local sampleCount = #samples
		local weightF = (sampleCount > 0) and (frontArea / sampleCount) or 0
		local weightS = (sampleCount > 0) and (sideArea / sampleCount) or 0
		local compFrontWeight = 0
		local compSideWeight = 0

		for _, pt in ipairs(samples) do
			local pointFrontDot = pt:Dot(frontDir)
			local pointSideDot = pt:Dot(sideDir)
			local frontDist = math.max(pointFrontDot - frontMin, pointFrontDot - compFrontMin, 0) + tracePadding
			local sideNegDist = math.max(pointSideDot - sideMin, pointSideDot - compSideMin, 0) + tracePadding
			local sidePosDist = math.max(sideMax - pointSideDot, compSideMax - pointSideDot, 0) + tracePadding

			local frontVal = losFiltered(pt - frontDir * frontDist, pt, comp)
			local sideValA = losFiltered(pt - sideDir * sideNegDist, pt, comp)
			local sideValB = losFiltered(pt + sideDir * sidePosDist, pt, comp)

			local sideVal = 0
			if sideValA > 0 and (sideValB <= 0 or sideValA <= sideValB) then
				sideVal = sideValA
			elseif sideValB > 0 then
				sideVal = sideValB
			end

			if debugSamples then
				local best = math.max(frontVal or 0, sideVal or 0)
				if best > debugMaxLOS then debugMaxLOS = best end
				debugSamples[#debugSamples + 1] = {
					pos = pt,
					front = frontVal or 0,
					side = sideVal or 0
				}
			end

			if frontVal > 0 then
				updateRegion(frontRegions, regionKey(pt, frontU, frontV), frontVal, weightF)
				compFrontWeight = compFrontWeight + frontVal * weightF
			end
			if sideVal > 0 then
				updateRegion(sideRegions, regionKey(pt, sideU, sideV), sideVal, weightS)
				compSideWeight = compSideWeight + sideVal * weightS
			end
		end

		local compWeight = compFrontWeight + compSideWeight * 2
		if compWeight > 0 then
			compContrib[#compContrib + 1] = {
				Ent = comp,
				Weight = compWeight
			}
		end
	end

	if debugSamples and debugMaxLOS > 0 then
		for _, s in ipairs(debugSamples) do
			local best = math.max(s.front or 0, s.side or 0)
			local ratio = best / debugMaxLOS
			local col = ACE_DebugColorRatio(ratio)

			-- small square at each sample point
			debugoverlay.Box(s.pos, Vector(-1, -1, -1), Vector(1, 1, 1), 30, col)

			-- optional: label the best value
			-- debugoverlay.Text(s.pos + Vector(0, 0, 2), string.format("%.0f", best), 30, true)
		end
	end

	local accumFront, countFront = 0, 0
	for _, e in pairs(frontRegions) do
		accumFront = accumFront + e.val * e.weight
		countFront = countFront + e.weight
	end

	local accumSide, countSide = 0, 0
	for _, e in pairs(sideRegions) do
		accumSide = accumSide + e.val * e.weight
		countSide = countSide + e.weight
	end

	local frontAvg = countFront > 0 and (accumFront / countFront) or 0
	local sideAvg = countSide > 0 and (accumSide / countSide) or 0

	local quantStep = scanCfg.ResultQuantizeMm or 0
	if quantStep > 0 then
		frontAvg = math.Round(frontAvg / quantStep) * quantStep
		sideAvg = math.Round(sideAvg / quantStep) * quantStep
	end

	local totalArmorPts = ACE_CalcArmorPoints(frontAvg, sideAvg)

	-- Build per-entity armor detail weights.
	-- Prefer trace-derived armor entities if available; otherwise fallback to armor prop projected area weighting.
	local detailWeights = {}
	local detailWeightTotal = 0
	for _, row in ipairs(compContrib) do
		local comp = row.Ent
		if IsEnt(comp) then
			local cls = comp:GetClass()
			if ACE.ArmorClasses and ACE.ArmorClasses[cls] then
				local w = tonumber(row.Weight) or 0
				if w > 0 then
					detailWeights[#detailWeights + 1] = { Ent = comp, Weight = w }
					detailWeightTotal = detailWeightTotal + w
				end
			end
		end
	end

	if detailWeightTotal <= 0 then
		for _, ent in ipairs(contraptionEnts) do
			if IsEnt(ent) then
				local cls = ent:GetClass()
				if ACE.ArmorClasses and ACE.ArmorClasses[cls] then
					local w = projectedData(ent, frontDir) + projectedData(ent, sideDir) * 2
					if w > 0 then
						detailWeights[#detailWeights + 1] = { Ent = ent, Weight = w }
						detailWeightTotal = detailWeightTotal + w
					end
				end
			end
		end
	end

	local armorDetails = {}
	if totalArmorPts > 0 and detailWeightTotal > 0 then
		for _, row in ipairs(detailWeights) do
			local comp = row.Ent
			if IsEnt(comp) then
				local pts = totalArmorPts * (row.Weight / detailWeightTotal)
				local label = ACE_FormatDetailLabel(comp)
				armorDetails[#armorDetails + 1] = {
					Label = label,
					RawPoints = pts,
					Points = ACE_SafeRound1(pts),
					EntIndex = comp:EntIndex()
				}
			end
		end
	end

	table.sort(armorDetails, function(a, b)
		if a.Points == b.Points then
			if a.EntIndex == b.EntIndex then return tostring(a.Label) < tostring(b.Label) end
			return a.EntIndex < b.EntIndex
		end
		return a.Points > b.Points
	end)

	-- Keep detail sum aligned with displayed armor total after rounding.
	if #armorDetails > 0 then
		local detailTotal = 0
		for _, entry in ipairs(armorDetails) do
			detailTotal = detailTotal + (entry.Points or 0)
		end

		local correction = ACE_SafeRound1(totalArmorPts - detailTotal)
		if correction ~= 0 then
			armorDetails[1].Points = ACE_SafeNonNegative((armorDetails[1].Points or 0) + correction)
		end

		for _, entry in ipairs(armorDetails) do
			entry.RawPoints = nil
		end
	end

	return frontAvg, sideAvg, armorDetails
end


-- Ensure armor data is initialized and cached.
function ACE_EnsureArmor(con, baseEnt, force)
	if not con then return end

	local cacheStale = ACE_EnsureCacheVersion and ACE_EnsureCacheVersion(con) or false
	local needsInit = not con.ACEArmorCalculated or (con.ACEArmorLastCalc or 0) <= 0
	if not force and not needsInit and not con.ACEArmorDirty and not cacheStale then return end

	local base = baseEnt
	if (not IsEnt(base)) and con.GetACEBaseplate then base = con:GetACEBaseplate() end

	local front, side = 0, 0
	local armorDetails = con.ACEArmorDetails or {}
	local usedCache = false

	local cacheKey = con.ACEArmorCacheKey
	local cached = con.ACEArmorCachedData
	if ACE_DebugCache then
		local info = string.format("key=%s cached=%s", tostring(cacheKey or "nil"), tostring(cached ~= nil))
		ACE_DebugCache(con, "ensure-cache", base, info, "EnsureArmor")
	end
	if cached then
		front = cached.Front or cached.front or 0
		side = cached.Side or cached.side or 0
		local cachedDetails = cached.Details or cached.details
		local cacheVersion = cached.Version or cached.version or 1
		local expectedVersion = ACE.ArmorCacheVersion or 1

		if cacheVersion == expectedVersion and ACE_IsValidArmorResult(front, side) and ACE_IsValidArmorDetails(cachedDetails) then
			con.ACEArmorFront = front
			con.ACEArmorSide = side
			armorDetails = cachedDetails or armorDetails
			usedCache = true
		else
			front, side = 0, 0
			usedCache = false
		end
	end

	if not usedCache and IsEnt(base) then
		front, side, armorDetails = ACE_CalcContraptionArmor(base)
		con.ACEArmorFront = front
		con.ACEArmorSide = side
	end

	if con.ACENonArmorDirty or not con.ACEPointsPerType then
		ACE_RebuildNonArmorPoints(con, base)
	end

	local newArmorPts = ACE_CalcArmorPoints(front, side)

	con.ACEPointsPerType = con.ACEPointsPerType or {}
	con.ACEPointsPerType.Armor = newArmorPts

	con.ACEArmorPoints = newArmorPts
	con.ACEArmorDetails = armorDetails or {}
	con.ACEArmorDirty = false
	con.ACEArmorCalculated = true
	con.ACEArmorLastCalc = CurTime()

	con.OTWarnings = con.OTWarnings or {}
	con.OTWarnings.WarnedModified = false

	local nonArmor = con.ACEPointsNonArmor or 0
	con.ACEPoints = nonArmor + newArmorPts

	local cacheKey = con.ACEArmorCacheKey
	if cacheKey and not usedCache and ACE_IsValidArmorResult(front, side) then
		ACE.DupeArmorCache = ACE.DupeArmorCache or {}
		ACE.DupeArmorCache[cacheKey] = {
			Version = ACE.ArmorCacheVersion or 1,
			Front = front,
			Side = side,
			Details = armorDetails
		}
		if ACE_DebugCache then
			local info = string.format("write key=%s", tostring(cacheKey))
			ACE_DebugCache(con, "cache-write", base, info, "EnsureArmor")
		end
	elseif ACE_DebugCache then
		local info = string.format("skip key=%s used=%s valid=%s", tostring(cacheKey), tostring(usedCache), tostring(ACE_IsValidArmorResult(front, side)))
		ACE_DebugCache(con, "cache-skip", base, info, "EnsureArmor")
	end

	con.ACEArmorCacheKey = nil
	con.ACEArmorCachedData = nil

	if ACE_DebugDirty then
		ACE_DebugDirty(con, "armor-scan-complete", base,
			string.format("front=%.2f side=%.2f cache=%s", front or 0, side or 0, tostring(usedCache)),
			"EnsureArmor"
		)
	end
end

_G.ACE_EnsureArmor = ACE_EnsureArmor

