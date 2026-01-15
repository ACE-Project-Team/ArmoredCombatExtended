ACE = ACE or {}

local ArmorClasses = {
	prop_physics = true,
	primitive_shape = true,
	primitive_airfoil = true,
	primitive_rail_slider = true,
	primitive_slider = true,
	primitive_ladder = true
}

local FirepowerEnts = {
	["acf_rack"]                  = true,
	["acf_gun"]                   = true
}
local CrewEnts = {
	["ace_crewseat_gunner"]                  = true,
	["ace_crewseat_loader"]                  = true,
	["ace_crewseat_driver"]                  = true
}
local ElectronicEnts = {
	["ace_rwr_dir"]                  = true,
	["ace_rwr_sphere"]               = true,
	["acf_missileradar"]             = true,
	["acf_opticalcomputer"]          = true,
	["ace_ecm"]                      = true,
	["ace_trackingradar"]            = true,
	["ace_searchradar"]              = true,
	["ace_irst"]                     = true,
	["ace_sonar"]                    = true,
	["ace_crewseat_driver"]          = true
}

local function ACE_GetPtsType(ClassName)
	if ArmorClasses[ClassName] then
		return "Armor"
	end
	if ClassName == "acf_engine" then
		return "Engines"
	end
	if ClassName == "acf_fueltank" then
		return "Ignore"
	end
	if FirepowerEnts[ClassName] then
		return "Firepower"
	end
	if ClassName == "acf_ammo" then
		return "Ammo"
	end
	if CrewEnts[ClassName] then
		return "Crew"
	end
	if ElectronicEnts[ClassName] then
		return "Electronics"
	end

	return "Armor"
end

-- Ammo scoring model.
-- Per-round cost scales with max penetration, caliber, and ammo type factor.
-- Total crate cost multiplies per-round cost by capacity and summed compatible ROF.
local AmmoTypeFactors = {
	AP = 0.5,
	APHE = 0.6,
	APDS = 0.9,
	APFSDS = 1.2,
	HVAP = 0.7,
	HEAT = 0.75,
	HEATFS = 0.9,
	THEAT = 0.95,
	THEATFS = 1.0,
	HESH = 0.4,
	HE = 0.5,
	HEFS = 0.6,
	HP = 0.1,
	CAP = 0.6,
	CHEAT = 0.8,
	CHE = 0.25,
	CHF = 0,
	SM = 0,
	FLR = 0,
	FL = 0.3,
	GLATGM = 0.75,
	["GLATGM-HE"] = 0.25,
	Refill = 0
}

-- Normalization constants for the ammo formula; tune these to rebalance without
-- rewriting the math.
local AmmoCostConfig = {
	BaseRoundPts = 80, -- Base points per round before scaling.
	RefPen = 600, -- Reference penetration (mm) for pen scaling.
	RefCaliber = 120, -- Reference caliber (mm) for caliber scaling.
	PenExp = 1.6, -- Penetration curve exponent.
	RefBlastMass = 6, -- Reference HE filler mass (kg) for blast scaling.
	BlastExp = 1.1, -- Blast curve exponent.
	BlastWeight = 0.25, -- Blend weight for blast vs penetration threat.
	RpsRef = 1 / 7, -- Reference rounds per second for ROF scaling.
	RpsExp = 0.5, -- ROF curve exponent.
	ReadyRackBase = 2400, -- Ready rack baseline: base / caliber(mm).
	ReadyRackMin = 10, -- Minimum ready rounds per gun group.
	ReadyRackMax = 200, -- Maximum ready rounds per gun group.
	ReadyRackPivot = 60, -- Caliber (mm) where low-caliber boost stops.
	ReadyRackLowBoost = 0.5, -- Boost factor applied below pivot (0.5 = +50%).
	StowFactor = 0.35, -- Cost multiplier for stowed rounds.
	TailFactor = 0, -- Extra discount per round beyond tail start (0 disables).
	TailStartMultiplier = 2 -- Tail start = readyCap * multiplier.
}

ACE.AmmoTypeFactors = AmmoTypeFactors
ACE.AmmoCostConfig = AmmoCostConfig

ACE.DupeArmorCache = ACE.DupeArmorCache or {}
ACE.DupeArmorCacheVersion = ACE.DupeArmorCacheVersion or 1
ACE.DupeArmorCacheLastClear = ACE.DupeArmorCacheLastClear or CurTime()

local DupeArmorCacheTtl = CreateConVar(
	"ace_dupe_armor_cache_ttl",
	"1800",
	FCVAR_ARCHIVE,
	"Seconds between clearing the dupe armor cache (0 to disable)."
)

timer.Create("ACE_DupeArmorCacheGC", 60, 0, function()
	local ttl = DupeArmorCacheTtl:GetFloat()
	if ttl <= 0 then return end

	local now = CurTime()
	local last = ACE.DupeArmorCacheLastClear or now
	if now - last < ttl then return end

	ACE.DupeArmorCache = {}
	ACE.DupeArmorCacheLastClear = now
end)

concommand.Add("ace_dupe_armor_cache_clear", function()
	ACE.DupeArmorCache = {}
	ACE.DupeArmorCacheLastClear = CurTime()
end)

local function ACE_GetAmmoTypeFactor(ammoType)
	return AmmoTypeFactors[ammoType] or 1
end

local function ACE_GetReadyRackCap(calMm, totalRounds)
	local readyBase = AmmoCostConfig.ReadyRackBase or 0
	local readyMax = AmmoCostConfig.ReadyRackMax or 0
	if readyBase <= 0 or readyMax <= 0 then return 0 end

	local readyMin = AmmoCostConfig.ReadyRackMin or 0
	local pivot = AmmoCostConfig.ReadyRackPivot or 0
	local lowBoost = AmmoCostConfig.ReadyRackLowBoost or 0

	local baseCap = readyBase / math.max(calMm, 1)
	if pivot > 0 and lowBoost > 0 and calMm < pivot then
		local ratio = (pivot - calMm) / pivot
		baseCap = baseCap * (1 + lowBoost * ratio)
	end

	local cap = math.Clamp(baseCap, readyMin, readyMax)
	if totalRounds and totalRounds > 0 then
		cap = math.min(cap, totalRounds)
	end

	return math.floor(cap + 0.5)
end

local function ACE_GetAmmoMaxPen(bulletData)
	if not bulletData then return 0 end

	local maxPen = tonumber(bulletData.MaxPen) or 0
	if bulletData.MaxPen2 then
		maxPen = math.max(maxPen, tonumber(bulletData.MaxPen2) or 0)
	end

	if maxPen > 0 then
		return maxPen
	end

	local function getBlastPen(data)
		local filler = data.BoomFillerMass or data.FillerMass or 0
		local hePower = ACF and ACF.HEPower or 0
		local blastDiv = ACF and ACF.HEBlastPenetration or 0
		if filler <= 0 or hePower <= 0 or blastDiv <= 0 then return 0 end
		return (filler * hePower) / blastDiv
	end

	local roundType = bulletData.Type
	local round = roundType and ACF.RoundTypes and ACF.RoundTypes[roundType]
	if round and round.getDisplayData then
		local ok, display = pcall(round.getDisplayData, bulletData)
		if ok and istable(display) then
			maxPen = math.max(maxPen, display.MaxPen or 0, display.MaxPen2 or 0)
		end
	end

	if maxPen <= 0 then
		maxPen = getBlastPen(bulletData)
	end

	return maxPen
end

local function ACE_GetAmmoCaliberMm(bulletData)
	if not bulletData then return 0 end

	local cal = bulletData.Caliber or 0
	local slug = bulletData.SlugCaliber or 0
	local slug2 = bulletData.SlugCaliber2 or 0
	local jet = bulletData.JetCaliber or 0
	local best = math.max(cal, slug, slug2, jet)

	if best <= 0 and bulletData.Id then
		best = ACF_GetGunValue(bulletData.Id, "caliber") or 0
	end

	return best * 10
end

local function ACE_GetAmmoBlastMass(bulletData)
	if not bulletData then return 0 end

	local mass = tonumber(bulletData.BoomFillerMass) or 0
	if mass <= 0 then
		mass = tonumber(bulletData.FillerMass) or 0
	end

	return mass
end

local function ACE_GetGunRps(ent)
	local reload = ent.ReloadTime
	if reload and reload > 0 then return 1 / reload end

	local rof = ent.RateOfFire
	if rof and rof > 0 then return rof / 60 end

	return 0
end

local function ACE_GetRackRps(ent)
	local reload = ent.ReloadTime
	if reload and reload > 0 then return 1 / reload end

	return 0
end

local function ACE_CalcAmmoCratePoints(crate, gunRpsById, racks, readyAlloc)
	if not IsValid(crate) then return 0 end

	local bdata = crate.BulletData
	if not bdata then return 0 end

	local rounds = crate.Capacity or 0
	if rounds <= 0 then return 0 end

	local maxPen = ACE_GetAmmoMaxPen(bdata)
	local blastMass = ACE_GetAmmoBlastMass(bdata)
	if maxPen <= 0 and blastMass <= 0 then return 0 end

	local calMm = ACE_GetAmmoCaliberMm(bdata)
	if calMm <= 0 then return 0 end

	local typeFactor = ACE_GetAmmoTypeFactor(bdata.Type)
	if typeFactor <= 0 then return 0 end

	local ammoId = bdata.Id
	if not ammoId then return 0 end

	local rpsTotal = gunRpsById[ammoId] or 0
	if racks and ACF_CanLinkRack then
		for _, rack in ipairs(racks) do
			if IsValid(rack) and rack.Id then
				local ok = ACF_CanLinkRack(rack.Id, ammoId, bdata, rack)
				if ok then
					rpsTotal = rpsTotal + ACE_GetRackRps(rack)
				end
			end
		end
	end

	if rpsTotal <= 0 then return 0 end

	local penFactor = (maxPen / AmmoCostConfig.RefPen) ^ AmmoCostConfig.PenExp
	local blastFactor = 0
	local blastRef = AmmoCostConfig.RefBlastMass
	if blastMass > 0 and blastRef and blastRef > 0 then
		blastFactor = (blastMass / blastRef) ^ AmmoCostConfig.BlastExp
	end
	local threatFactor = penFactor + blastFactor * AmmoCostConfig.BlastWeight
	if threatFactor <= 0 then return 0 end
	local calFactor = calMm / AmmoCostConfig.RefCaliber
	local rpsFactor = (rpsTotal / AmmoCostConfig.RpsRef) ^ AmmoCostConfig.RpsExp
	local roundPts = AmmoCostConfig.BaseRoundPts * threatFactor * calFactor * typeFactor
	local stowFactor = AmmoCostConfig.StowFactor or 1
	local tailFactor = AmmoCostConfig.TailFactor or 0
	local tailStartMul = AmmoCostConfig.TailStartMultiplier or 0
	local effectiveRounds = rounds
	local readyCap = ACE_GetReadyRackCap(calMm, rounds)
	local readyCount = rounds
	local stowCount = 0

	if readyCap > 0 then
		readyCount = readyCap
		stowCount = math.max(rounds - readyCount, 0)
		effectiveRounds = readyCount + stowCount * stowFactor
		if tailFactor > 0 and tailStartMul > 0 then
			local tailStart = readyCap * tailStartMul
			local tail = math.max(rounds - tailStart, 0)
			if tail > 0 then
				effectiveRounds = effectiveRounds - tail * tailFactor
			end
		end
		if effectiveRounds < 0 then
			effectiveRounds = 0
		end
	end

	local name = ACF_GetGunValue(ammoId, "name") or tostring(ammoId)
	if readyAlloc and readyAlloc[crate] then
		readyCount = math.min(readyAlloc[crate], rounds)
		stowCount = math.max(rounds - readyCount, 0)
	end
	local readyCost = roundPts * readyCount * rpsFactor
	local stowCost = roundPts * stowCount * stowFactor * rpsFactor
	local detail = {
		Name = name,
		Type = bdata.Type or "",
		Caliber = calMm,
		Capacity = rounds,
		MaxPen = maxPen,
		Rps = rpsTotal,
		ReadyCount = readyCount,
		StowCount = stowCount,
		ReadyCost = readyCost,
		StowCost = stowCost
	}

	return readyCost + stowCost, detail
end

-- Rate-limit legal checks per entity to prevent spam and allow future policy hooks.
function ACE_DoContraptionLegalCheck(CheckEnt)

	CheckEnt.CanLegalCheck = CheckEnt.CanLegalCheck or false
	if not CheckEnt.CanLegalCheck then return end

	CheckEnt.CanLegalCheck = false
	-- Re-enable checks after a short cooldown.
	timer.Simple(3, function() if IsValid(CheckEnt) then CheckEnt.CanLegalCheck = true end end)

	local Contraption = CheckEnt:GetContraption() or {}
	if table.IsEmpty(Contraption) then return end

	ACE_CheckLegalCont(Contraption)

end

do
	local function ACE_GetDupeSignature(dupe, created)
		if not dupe then return nil end
		local function formatArmorKey(material, ductility, armour, maxArmour, mass)
			return string.format(
				"mat=%s|duct=%.3f|arm=%.2f|max=%.2f|mass=%.2f",
				tostring(material or ""),
				tonumber(ductility) or 0,
				tonumber(armour) or 0,
				tonumber(maxArmour) or 0,
				tonumber(mass) or 0
			)
		end

		local entData = dupe.Entities
			or dupe.Ents
			or dupe.EntityList
			or (dupe.Dupe and dupe.Dupe.Entities)

		if istable(entData) then
			local parts = {}
			for _, data in pairs(entData) do
				if istable(data) then
					local class = data.Class or data.class or "unknown"
					local model = data.Model or data.model or ""
					local mods = data.EntityMods or data.entitymods
					local acfSettings = mods and mods.acfsettings
					local massMod = mods and mods.mass
					local acf = data.ACF or data.acf
					local material = (acfSettings and (acfSettings.Material or acfSettings.material))
						or (acf and (acf.Material or acf.material))
					local ductility = (acfSettings and (acfSettings.Ductility or acfSettings.ductility))
						or (acf and (acf.Ductility or acf.ductility))
					local armour = acf and (acf.Armour or acf.Armor)
					local maxArmour = acf and (acf.MaxArmour or acf.MaxArmor)
					local mass = massMod and (massMod.Mass or massMod.mass)
					local armorKey = formatArmorKey(material, ductility, armour, maxArmour, mass)
					parts[#parts + 1] = class .. "|" .. model .. "|" .. armorKey
				end
			end
			table.sort(parts)
			if #parts > 0 and util and util.SHA256 then
				return tostring(ACE.DupeArmorCacheVersion) .. ":ents:" .. util.SHA256(table.concat(parts, ";"))
			end
		end

		if istable(created) and util and util.SHA256 then
			local parts = {}
			for _, ent in pairs(created) do
				if not IsValid(ent) then continue end
				local class = ent:GetClass() or "unknown"
				local model = ent:GetModel() or ""
				local size = ent:OBBMaxs() - ent:OBBMins()
				local sizeKey = string.format("%.1f,%.1f,%.1f", size.x, size.y, size.z)
				local extra = ""
				local acf = ent.ACF
				local material = acf and acf.Material
				local ductility = acf and acf.Ductility
				local armour = acf and (acf.Armour or acf.Armor)
				local maxArmour = acf and (acf.MaxArmour or acf.MaxArmor)
				local mass = 0
				local phys = ent:GetPhysicsObject()
				if IsValid(phys) then
					mass = phys:GetMass()
				end
				local armorKey = formatArmorKey(material, ductility, armour, maxArmour, mass)
				if class == "acf_gun" then
					extra = tostring(ent.Id or "")
				elseif class == "acf_ammo" then
					extra = tostring(ent.BulletData and ent.BulletData.Id or "")
				elseif class == "acf_engine" then
					extra = tostring(ent.Id or "")
				end
				parts[#parts + 1] = class .. "|" .. model .. "|" .. sizeKey .. "|" .. extra .. "|" .. armorKey
			end
			table.sort(parts)
			if #parts > 0 then
				return tostring(ACE.DupeArmorCacheVersion) .. ":spawn:" .. util.SHA256(table.concat(parts, ";"))
			end
		end

		return nil
	end

	local function ACE_GetContraptionFromEntity(ent)
		if not IsValid(ent) then return end
		if not ent.GetContraption then return end

		local con = ent:GetContraption()
		if not con or not con.ents or table.IsEmpty(con.ents) then return end

		return con
	end

	local function ACE_IsContraptionFrozen(con)
		if not con or not con.GetACEBaseplate then return false end

		local base = con:GetACEBaseplate()
		if not IsValid(base) then return false end

		local phys = base:GetPhysicsObject()
		if not IsValid(phys) then return false end

		return not phys:IsMotionEnabled()
	end

	local function ACE_GetArmorTimerId(con)
		if con.ACEArmorTimerId then return con.ACEArmorTimerId end
		local index = ACE_GetContraptionIndex and ACE_GetContraptionIndex(con) or tostring(con)
		con.ACEArmorTimerId = "ACE_ArmorInit_" .. index

		return con.ACEArmorTimerId
	end

	local function ACE_ScheduleInitArmor(con, delay, force, cacheKey)
		if not con then return end

		if not force and con.ACEArmorCalculated and not con.ACEArmorDirty then return end
		if cacheKey and not con.ACEArmorCacheKey then
			con.ACEArmorCacheKey = cacheKey
		end

		local requestedDelay = delay or 0.1
		local queuedDelay = con.ACEArmorQueuedDelay or 0
		local nextDelay = math.max(requestedDelay, queuedDelay)

		con.ACEArmorQueuedDelay = nextDelay
		con.ACEArmorQueuedForce = con.ACEArmorQueuedForce or force

		timer.Create(ACE_GetArmorTimerId(con), nextDelay, 1, function()
			if not con then return end
			local useForce = con.ACEArmorQueuedForce
			con.ACEArmorQueuedForce = nil
			con.ACEArmorQueuedDelay = nil

			if not con.GetACEBaseplate then return end
			if not useForce and con.ACEArmorCalculated and not con.ACEArmorDirty then return end

			local base = con:GetACEBaseplate()
			if IsValid(base) then
				ACE_EnsureArmor(con, base, useForce)
				con.ACEArmorLastCalc = CurTime()
			end
		end)
	end

	local function ACE_ScheduleInitArmorFromEntities(entities, delay, force, skipFrozen, cacheKey, cachedData)
		if not istable(entities) then return end
		local scheduled = {}

		for _, ent in pairs(entities) do
			if not IsValid(ent) then continue end
			local con = ACE_GetContraptionFromEntity(ent)
			if not con or scheduled[con] then continue end
			if skipFrozen and ACE_IsContraptionFrozen(con) then continue end
			scheduled[con] = true
			if cacheKey and not con.ACEArmorCacheKey then
				con.ACEArmorCacheKey = cacheKey
			end
			if cachedData then
				con.ACEArmorCachedData = cachedData
			end
			ACE_ScheduleInitArmor(con, delay, force, cacheKey)
		end
	end

	hook.Add("PlayerUnfrozeObject", "ACE_ArmorInitOnUnfreeze", function(_, ent)
		local con = ACE_GetContraptionFromEntity(ent)
		if not con then return end
		ACE_ScheduleInitArmor(con, 0.1, false)
	end)

	hook.Add("PlayerEnteredVehicle", "ACE_ArmorInitOnEntry", function(_, veh)
		local con = ACE_GetContraptionFromEntity(veh)
		if not con then return end
		ACE_ScheduleInitArmor(con, 0.1, false)
	end)

	hook.Add("AdvDupe_FinishPasting", "ACE_ArmorInitOnDupePaste", function(dupeInfo)
		local dupe = istable(dupeInfo) and dupeInfo[1]
		local created = dupe and dupe.CreatedEntities
		if not created then return end
		local cacheKey = ACE_GetDupeSignature(dupe, created)
		local cached = cacheKey and ACE.DupeArmorCache and ACE.DupeArmorCache[cacheKey] or nil
		local flagName = "_ACEAdvDupeArmorInit"
		local first
		for _, ent in pairs(created) do
			if IsValid(ent) then
				first = ent
				break
			end
		end
		if not first or first[flagName] then return end
		for _, ent in pairs(created) do
			if IsValid(ent) then
				ent[flagName] = true
			end
		end

		timer.Simple(0, function()
			ACE_ScheduleInitArmorFromEntities(created, 0.05, false, true, cacheKey, cached)
		end)

		timer.Simple(0.5, function()
			ACE_ScheduleInitArmorFromEntities(created, 0.1, false, true, cacheKey, cached)
			timer.Simple(0.8, function()
				ACE_ScheduleInitArmorFromEntities(created, 0.1, false, true, cacheKey, cached)
			end)
		end)
	end)
end

function ACE_CheckLegalCont(Contraption)

	-- Track one-time warning flags per contraption to avoid repeated spam.
	Contraption.OTWarnings = Contraption.OTWarnings or {}
	local HasWarned = false

	HasWarned = Contraption.OTWarnings.WarnedOverPoints or false
	if Contraption.ACEPoints > ACF.PointsLimit and not HasWarned then
		local Ply = Contraption:GetACEBaseplate():CPPIGetOwner()
		local AboveAmt = Contraption.ACEPoints - ACF.PointsLimit
		local msg = "[ACE] " .. Ply:Nick() .. " has a vehicle [" .. math.ceil(AboveAmt) .. "pts] over the limit costing [" .. math.ceil(Contraption.ACEPoints) .. "pts / " .. math.ceil(ACF.PointsLimit) .. "pts]"

		chatMessageGlobal( msg, Color( 255, 234, 0))

		Contraption.OTWarnings.WarnedOverPoints = true
	end

	if Contraption.totalMass > ACF.MaxWeight and not HasWarned then
		local Ply = Contraption:GetACEBaseplate():CPPIGetOwner()
		local AboveAmt = Contraption.totalMass - ACF.MaxWeight

		local msg = "[ACE] " .. Ply:Nick() .. " has a vehicle [" .. math.ceil(AboveAmt) .. "kg] over the limit, weighing [" .. math.ceil(Contraption.totalMass) .. "kg / " .. math.ceil(ACF.MaxWeight) .. "kg]"
		chatMessageGlobal( msg, Color( 255, 234, 0))

		Contraption.OTWarnings.WarnedOverWeight = true
	end

end

local armorDebugCvar = CreateConVar("ace_armor_debugvis", "0", FCVAR_ARCHIVE, "Draw debug overlays for armor scan results.")

-- Estimate contraption frontal/side armor using line-of-sight traces.
-- Samples multiple points on critical components and weights by projected area
-- to stabilize results across irregular geometry.
local function ACE_CalcContraptionArmor(ent)
	if not IsValid(ent) then return 0, 0 end

	local contraption = ent.GetContraption and ent:GetContraption() or nil
	local contraptionId = contraption and ACE_GetContraptionIndex and ACE_GetContraptionIndex(contraption) or (ent.ACF and ent.ACF.ContraptionId)
	local contraptionEnts = {}

	-- Prefer the framework contraption list when available for a complete entity set.
	if contraption and contraption.ents then
		for candidate in pairs(contraption.ents) do
			if IsValid(candidate) then
				contraptionEnts[#contraptionEnts + 1] = candidate
			end
		end
	elseif contraptionId then
		-- Fallback to cached entities that match the stored contraption id.
		for _, candidate in ipairs(ACE.contraptionEnts or {}) do
			if not IsValid(candidate) then continue end
			local candACF = candidate.ACF
			if not candACF or candACF.ContraptionId ~= contraptionId then continue end
			contraptionEnts[#contraptionEnts + 1] = candidate
		end
	end

	-- As a last resort, scan only the base entity.
	if #contraptionEnts == 0 then
		contraptionEnts[1] = ent
	end
	if #contraptionEnts > 1 then
		table.sort(contraptionEnts, function(a, b)
			return a:EntIndex() < b:EntIndex()
		end)
	end

	-- Use the largest-caliber gun to infer vehicle facing when available.
	local mainGun
	for _, candidate in ipairs(contraptionEnts) do
		if IsValid(candidate)
			and candidate:GetClass() == "acf_gun"
			and candidate:GetModel() ~= "models/launcher/20mmsl.mdl"
			and candidate:GetModel() ~= "models/launcher/40mmsl.mdl"
			and candidate:GetModel() ~= "models/launcher/40mmgl.mdl"
			and (not mainGun
				or (candidate.Caliber or 0) > (mainGun.Caliber or 0)
				or ((candidate.Caliber or 0) == (mainGun.Caliber or 0) and candidate:EntIndex() < mainGun:EntIndex())) then
			mainGun = candidate
		end
	end

	-- Establish scan directions (front/side) using gun forward, gravity up, and wheel axes.
	local function normalizeOrNil(vec)
		if not vec then return nil end
		local len = vec:Length()
		if len <= 1e-6 then return nil end
		return vec / len
	end

	local function flattenToPlane(vec, up)
		if not vec or not up then return nil end
		local flat = vec - up * vec:Dot(up)
		return normalizeOrNil(flat)
	end

	local function getWorldUp()
		local gravity = physenv and physenv.GetGravity and physenv.GetGravity() or Vector(0, 0, -1)
		if gravity:LengthSqr() <= 1e-6 then return Vector(0, 0, 1) end
		return (-gravity):GetNormalized()
	end

	local function isMakeSpherical(ent)
		local override = ent and ent.RenderOverride
		return override and tostring(override):find("MakeSpherical") ~= nil
	end

	local function getWheelAxisSide(base, up)
		if not IsValid(base) or not constraint or not constraint.FindConstraints then return nil end
		local cons = constraint.FindConstraints(base, "Axis")
		if not istable(cons) or #cons == 0 then return nil end

		local axisSum = Vector(0, 0, 0)
		local count = 0

		for _, con in ipairs(cons) do
			if not con or (con.Ent1 ~= base and con.Ent2 ~= base) then continue end
			local other = con.Ent1 == base and con.Ent2 or con.Ent1
			if not IsValid(other) or not isMakeSpherical(other) then continue end

			local localAxis = con.Ent1 == base and con.LNorm1 or con.LNorm2
			if not localAxis then continue end

			local axisWorld = base:LocalToWorld(localAxis) - base:GetPos()
			axisWorld = axisWorld - up * axisWorld:Dot(up)
			axisWorld = normalizeOrNil(axisWorld)
			if axisWorld then
				if count > 0 and axisWorld:Dot(axisSum) < 0 then
					axisWorld = -axisWorld
				end
				axisSum = axisSum + axisWorld
				count = count + 1
			end
		end

		return count > 0 and normalizeOrNil(axisSum) or nil
	end

	local upDir = getWorldUp()
	local rawFront = IsValid(mainGun) and -mainGun:GetForward() or nil
	if not rawFront then
		rawFront = ent:GetForward() * -1
	end

	local frontDir = flattenToPlane(rawFront, upDir) or normalizeOrNil(rawFront) or Vector(1, 0, 0)
	local sideDir = getWheelAxisSide(ent, upDir)

	if not sideDir then
		sideDir = normalizeOrNil(upDir:Cross(frontDir))
	end

	if not sideDir then
		sideDir = normalizeOrNil(ent:GetRight()) or Vector(0, 1, 0)
	end

	sideDir = normalizeOrNil(sideDir - frontDir * sideDir:Dot(frontDir)) or sideDir

	local adjustedFront = normalizeOrNil(sideDir:Cross(upDir))
	if adjustedFront then
		if adjustedFront:Dot(frontDir) < 0 then
			adjustedFront = -adjustedFront
		end
		frontDir = adjustedFront
	end

	local debugDraw = armorDebugCvar:GetBool()
	local debugEntries = debugDraw and {} or nil
	local debugMaxVal = 0

	local function getBoundsWorld(prop)
		local mins, maxs = prop:OBBMins(), prop:OBBMaxs()
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
			corners[i] = prop:LocalToWorld(v * 0.75)
		end

		return corners
	end

	-- Critical components used as sampling anchors for armor estimation.
	local criticals = {}
	for _, cent in ipairs(contraptionEnts) do
		if not IsValid(cent) then continue end
		local cls = cent:GetClass()
		if cls == "acf_ammo" or cls == "acf_fueltank" or cls == "acf_engine" or cls == "ace_crewseat_gunner" or cls == "ace_crewseat_loader" or cls == "ace_crewseat_driver" then
			criticals[#criticals + 1] = cent
		end
	end

	local ignoredArmor = {
		acf_gun = true,
		acf_rack = true,
		ace_crewseat_gunner = true,
		ace_crewseat_loader = true,
		ace_crewseat_driver = true
	}

	local function basisFromDir(dir)
		dir = dir:GetNormalized()
		local upHint = math.abs(dir.z) < 0.99 and Vector(0, 0, 1) or Vector(1, 0, 0)
		local u = dir:Cross(upHint):GetNormalized()
		local v = dir:Cross(u):GetNormalized()
		return u, v
	end

	local function projectedData(comp, dir)
		local u, v = basisFromDir(dir)

		local corners = getBoundsWorld(comp)
		local minU, maxU = math.huge, -math.huge
		local minV, maxV = math.huge, -math.huge

		for _, wpos in ipairs(corners) do
			local pu = wpos:Dot(u)
			local pv = wpos:Dot(v)
			if pu < minU then minU = pu end
			if pu > maxU then maxU = pu end
			if pv < minV then minV = pv end
			if pv > maxV then maxV = pv end
		end

		local halfU = (maxU - minU) * 0.5
		local halfV = (maxV - minV) * 0.5
		local area = (maxU - minU) * (maxV - minV)

		return area, halfU, halfV
	end

	local frontU, frontV = basisFromDir(frontDir)
	local sideU, sideV = basisFromDir(sideDir)
	local regionSnap = 2
	local origin = ent:WorldSpaceCenter()

	local function regionKey(pos, u, v)
		if not pos then return nil end
		local rel = pos - origin
		local ku = math.floor(rel:Dot(u) / regionSnap + 0.5)
		local kv = math.floor(rel:Dot(v) / regionSnap + 0.5)
		return ku .. ":" .. kv
	end

	local function updateRegion(regions, key, val, weight)
		if not key or val <= 0 then return end
		local entry = regions[key]
		if not entry or val > entry.val then
			regions[key] = {
				val = val,
				weight = weight
			}
		end
	end

	local function losFiltered(startPos, endPos, targetComp)
		local filter = {}
		local total = 0
		local dir = (endPos - startPos):GetNormalized()
		local dbg = armorDebugCvar:GetBool()
		local hitTarget = false
		local hitPos
		local hitNormal
		local hullMins = Vector(-3, -3, -3)
		local hullMaxs = Vector(3, 3, 3)

		for _ = 1, 128 do
			local tr = util.TraceHull({
				start = startPos,
				endpos = endPos,
				mins = hullMins,
				maxs = hullMaxs,
				filter = filter,
				mask = MASK_SOLID
			})

			if not tr.Hit then break end

			local hitEnt = tr.Entity
			if not IsValid(hitEnt) then break end

			local skip = false

			-- Ignore MakeSpherical props that skew LOS thickness without directional armor.
			if hitEnt.RenderOverride and tostring(hitEnt.RenderOverride):find("MakeSpherical") then
				skip = true
			end

			if not skip and hitEnt == targetComp then
				hitTarget = true
				if not hitPos then
					hitPos = tr.HitPos
					hitNormal = tr.HitNormal
				end
				break
			end

			if not skip then
				local cls = hitEnt:GetClass()
				local skipArmor = ignoredArmor[cls] or not ACF_Check(hitEnt)

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
				local Mat = hitEnt.ACF.Material or "RHA"
				local MatData = ACE_GetMaterialData(Mat)
				local armor = hitEnt.ACF.Armour or 0
				local armorData = hitEnt.acfPropArmorData and hitEnt:acfPropArmorData()
				local effKE = (armorData and armorData.Effectiveness) or (MatData and MatData.effectiveness) or 1
				local effCHEM = (armorData and (armorData.HEATeffectiveness or armorData.HEATEffectiveness))
					or (MatData and (MatData.HEATeffectiveness or MatData.effectiveness))
					or effKE
				local eff = effKE * 0.8 + effCHEM * 0.2
				local curve = (armorData and armorData.Curve) or 1
				local ang = ACF_GetHitAngle(tr.HitNormal, dir)
				local los

				if ang >= 89 then
					los = (armor ^ curve) * eff
				else
					local cosAng = math.max(math.cos(math.rad(ang)), 0.01)
					los = (armor / (cosAng ^ ACF.SlopeEffectFactor)) ^ curve
					los = los * eff
				end

				total = total + los
				if not hitPos then
					hitPos = tr.HitPos
					hitNormal = tr.HitNormal
				end

				if dbg and los > 100 then
					debugoverlay.Text(tr.HitPos, string.format("LOS %.1f", los), 30, true)
				end

				filter[#filter + 1] = hitEnt
				startPos = tr.HitPos + dir * 0.1
			end
		end

		if not hitTarget then
			return 0
		end

		return total, hitPos, hitNormal
	end

	local frontRegions = {}
	local sideRegions = {}

	for _, comp in ipairs(criticals) do
		local center = comp:WorldSpaceCenter()
		local size = comp:OBBMaxs() - comp:OBBMins()
		local up = comp:GetUp()
		local right = comp:GetRight()

		local frontArea, frontHalfU, frontHalfV = projectedData(comp, frontDir)
		local sideArea, sideHalfU, sideHalfV = projectedData(comp, sideDir)

		local halfUp = up * (size.z * 0.5 * 0.95)
		local halfRight = right * (size.y * 0.5 * 0.95)

		local samples = {
			center + halfUp + halfRight,
			center + halfUp - halfRight,
			center - halfUp + halfRight,
			center - halfUp - halfRight,
			center -- Center sample improves coverage.
		}
		local sampleCount = #samples
		local weightF = sampleCount > 0 and (frontArea / sampleCount) or 0
		local weightS = sampleCount > 0 and (sideArea / sampleCount) or 0
		local sampleScale = sampleCount > 0 and (1 / math.sqrt(sampleCount)) or 0
		local frontHalfUSample = (frontHalfU or 0) * sampleScale
		local frontHalfVSample = (frontHalfV or 0) * sampleScale
		local sideHalfUSample = (sideHalfU or 0) * sampleScale
		local sideHalfVSample = (sideHalfV or 0) * sampleScale
		local markerSize = debugDraw and math.max(2, math.min(size.x, size.y, size.z) * 0.05) or 0

		for _, pt in ipairs(samples) do
			local frontStart = pt - frontDir * 200
			local frontEnd   = pt
			local sideStart  = pt - sideDir * 100
			local sideEnd    = pt

			-- Frontal thickness uses the forward trace from the sample point.
			local frontVal, frontHitPos, frontHitNormal = losFiltered(frontStart, frontEnd, comp)

			-- Side thickness samples both lateral directions and uses the smaller valid LOS.
			local sideValA, sideHitPosA, sideHitNormalA  = losFiltered(sideStart, sideEnd, comp)
			local sideValB, sideHitPosB, sideHitNormalB  = losFiltered(pt + sideDir * 500, pt - sideDir * 50, comp)
			local sideVal = 0
			local sideDirUsed = sideDir
			local sideHitPos
			local sideHitNormal
			if sideValA > 0 and (sideValB <= 0 or sideValA <= sideValB) then
				sideVal = sideValA
				sideDirUsed = sideDir
				sideHitPos = sideHitPosA
				sideHitNormal = sideHitNormalA
			elseif sideValB > 0 then
				sideVal = sideValB
				sideDirUsed = -sideDir
				sideHitPos = sideHitPosB
				sideHitNormal = sideHitNormalB
			end

			-- Accumulate area-weighted averages only when a valid hit is found.
			if frontVal > 0 then
				local key = regionKey(frontHitPos, frontU, frontV)
				updateRegion(frontRegions, key, frontVal, weightF)
			end

			if sideVal > 0 then
				local key = regionKey(sideHitPos, sideU, sideV)
				updateRegion(sideRegions, key, sideVal, weightS)
			end

			if debugDraw then
				if frontArea > 0 and frontVal > 0 then
					debugEntries[#debugEntries + 1] = {
						pos = frontHitPos,
						normal = frontHitNormal,
						fallbackNormal = -frontDir,
						val = frontVal,
						halfU = frontHalfUSample,
						halfV = frontHalfVSample,
						markerSize = markerSize
					}
					if frontVal > debugMaxVal then debugMaxVal = frontVal end
				end

				if sideArea > 0 and sideVal > 0 then
					debugEntries[#debugEntries + 1] = {
						pos = sideHitPos,
						normal = sideHitNormal,
						fallbackNormal = -sideDirUsed,
						val = sideVal,
						halfU = sideHalfUSample,
						halfV = sideHalfVSample,
						markerSize = markerSize
					}
					if sideVal > debugMaxVal then debugMaxVal = sideVal end
				end
			end
		end
	end

	if debugDraw and debugEntries and debugMaxVal > 0 then
		local function colorFromVal(v)
			local ratio = math.min(math.max((v or 0) / debugMaxVal, 0), 1)
			return 255 * ratio, 255 * (1 - ratio)
		end

		local thickness = 0.1
		for _, entry in ipairs(debugEntries) do
			if not entry.pos then continue end
			local normal = entry.normal or entry.fallbackNormal
			if not normal then continue end
			local r, g = colorFromVal(entry.val)
			local ang = normal:Angle()
			local pos = entry.pos + normal * 0.1
			local u = entry.halfU or entry.markerSize
			local v = entry.halfV or entry.markerSize
			debugoverlay.BoxAngles(pos, Vector(-thickness, -u, -v), Vector(thickness, u, v), ang, 30, Color(r, g, 0, 0.1))
		end
	end

	local countFront, countSide = 0, 0
	local accumFront, accumSide = 0, 0

	for _, entry in pairs(frontRegions) do
		accumFront = accumFront + entry.val * entry.weight
		countFront = countFront + entry.weight
	end

	for _, entry in pairs(sideRegions) do
		accumSide = accumSide + entry.val * entry.weight
		countSide = countSide + entry.weight
	end

	local avgFront = countFront > 0 and (accumFront / countFront) or 0
	local avgSide = countSide > 0 and (accumSide / countSide) or 0

	-- Return raw averages; side weighting is applied when converting to points.
	return avgFront, avgSide
	end

function ACE_GetArmorScan(ent)
	return ACE_CalcContraptionArmor(ent)
end

local function ACE_GetContraptionEntities(Contraption, fallbackEnt)
	local ents = {}

	if Contraption and Contraption.ents then
		for ent in pairs(Contraption.ents) do
			if IsValid(ent) then
				ents[#ents + 1] = ent
			end
		end
	end

	if #ents == 0 and IsValid(fallbackEnt) then
		ents[1] = fallbackEnt
	end

	return ents
end

local function ACE_BuildAmmoReadyAlloc(ents)
	local readyBase = AmmoCostConfig.ReadyRackBase or 0
	local readyMax = AmmoCostConfig.ReadyRackMax or 0
	if readyBase <= 0 or readyMax <= 0 then return nil end

	local groups = {}

	for _, ent in ipairs(ents) do
		if not IsValid(ent) then continue end
		if ent:GetClass() ~= "acf_ammo" then continue end

		local bdata = ent.BulletData
		if not bdata then continue end

		local rounds = ent.Capacity or 0
		if rounds <= 0 then continue end

		local ammoId = bdata.Id
		if not ammoId then continue end

		local calMm = ACE_GetAmmoCaliberMm(bdata)
		if calMm <= 0 then continue end

		local group = groups[ammoId]
		if not group then
			group = {
				calMm = calMm,
				total = 0,
				entries = {}
			}
			groups[ammoId] = group
		end

		group.total = group.total + rounds
		group.entries[#group.entries + 1] = {
			ent = ent,
			rounds = rounds
		}
	end

	local alloc = {}

	for _, group in pairs(groups) do
		local total = group.total or 0
		if total <= 0 then continue end

		local readyCap = ACE_GetReadyRackCap(group.calMm, total)
		if readyCap <= 0 then continue end

		local entries = {}
		local remaining = readyCap
		for _, entry in ipairs(group.entries) do
			local raw = readyCap * entry.rounds / total
			local base = math.floor(raw)
			remaining = remaining - base
			entries[#entries + 1] = {
				ent = entry.ent,
				rounds = entry.rounds,
				ready = base,
				frac = raw - base
			}
		end

		table.sort(entries, function(a, b)
			if a.frac == b.frac then
				if a.rounds == b.rounds then
					return tostring(a.ent) < tostring(b.ent)
				end
				return a.rounds < b.rounds
			end
			return a.frac > b.frac
		end)

		for _, entry in ipairs(entries) do
			if remaining <= 0 then break end
			if entry.ready < entry.rounds then
				entry.ready = entry.ready + 1
				remaining = remaining - 1
			end
		end

		for _, entry in ipairs(entries) do
			alloc[entry.ent] = entry.ready
		end
	end

	if next(alloc) == nil then return nil end
	return alloc
end

function ACE_GetAmmoCratePointsForContraption(crate, Contraption, fallbackEnt)
	if not IsValid(crate) then return 0 end

	local ents = ACE_GetContraptionEntities(Contraption, fallbackEnt or crate)
	local gunRpsById = {}
	local racks = {}
	local readyAlloc = ACE_BuildAmmoReadyAlloc(ents)

	for _, ent in ipairs(ents) do
		if not IsValid(ent) then continue end
		local cls = ent:GetClass()
		if cls == "acf_gun" then
			local id = ent.Id
			local rps = ACE_GetGunRps(ent)
			if id and rps > 0 then
				gunRpsById[id] = (gunRpsById[id] or 0) + rps
			end
		elseif cls == "acf_rack" then
			racks[#racks + 1] = ent
		end
	end

	return ACE_CalcAmmoCratePoints(crate, gunRpsById, racks, readyAlloc)
end

function ACE_CalcNonArmorPoints(Contraption, baseEnt)
	if not Contraption then
		return 0, {
			Engines = 0,
			Firepower = 0,
			Ammo = 0,
			Crew = 0,
			Electronics = 0
		}, { Items = {} }
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
	local nonArmor = 0
	local ents = ACE_GetContraptionEntities(Contraption, baseEnt)
	local gunRpsById = {}
	local racks = {}
	local detailItems = {}
	local ammoLines = {}
	local function addAmmoLine(state, caliber, ammoType, count)
		if not count or count <= 0 then return end
		local calKey = caliber and math.floor(caliber + 0.5) or 0
		if calKey <= 0 then return end
		local typeKey = ammoType ~= "" and ammoType or "Ammo"
		local key = string.format("%s|%d|%s", state, calKey, typeKey)
		if not ammoLines[key] then
			ammoLines[key] = {
				State = state,
				Caliber = calKey,
				Type = typeKey,
				Count = 0
			}
		end
		ammoLines[key].Count = ammoLines[key].Count + count
	end
	local minDetailPts = 300

	local function getEntityLabel(ent)
		local label = ent:GetNWString("WireName")
		if label and label ~= "" then return label end
		if ent.Name and ent.Name ~= "" then return ent.Name end
		return ent:GetClass()
	end

	local function addDetail(category, label, pts, ent)
		detailItems[#detailItems + 1] = {
			category = category,
			label = label,
			pts = pts,
			idx = IsValid(ent) and ent:EntIndex() or 0
		}
	end

	for _, ent in ipairs(ents) do
		if not IsValid(ent) then continue end
		local cls = ent:GetClass()
		if cls == "acf_gun" then
			local id = ent.Id
			local rps = ACE_GetGunRps(ent)
			if id and rps > 0 then
				gunRpsById[id] = (gunRpsById[id] or 0) + rps
			end
		elseif cls == "acf_rack" then
			racks[#racks + 1] = ent
		end
	end
	local readyAlloc = ACE_BuildAmmoReadyAlloc(ents)

	for _, ent in ipairs(ents) do
		if not IsValid(ent) then continue end

		local cls = ent:GetClass()
		if cls == "acf_ammo" then
			local pts, detail = ACE_CalcAmmoCratePoints(ent, gunRpsById, racks, readyAlloc)
			if pts > 0 then
				nonArmor = nonArmor + pts
				totals.Ammo = (totals.Ammo or 0) + pts
				if detail then
					totals.AmmoReady = (totals.AmmoReady or 0) + (detail.ReadyCost or 0)
					totals.AmmoBackup = (totals.AmmoBackup or 0) + (detail.StowCost or 0)
					totals.AmmoReadyRounds = (totals.AmmoReadyRounds or 0) + (detail.ReadyCount or 0)
					totals.AmmoBackupRounds = (totals.AmmoBackupRounds or 0) + (detail.StowCount or 0)

					local ammoType = detail.Type ~= "" and detail.Type or "Ammo"
					local readyCount = math.floor((detail.ReadyCount or 0) + 0.5)
					local stowCount = math.floor((detail.StowCount or 0) + 0.5)
					local readyCost = detail.ReadyCost or 0
					local stowCost = detail.StowCost or 0

					if readyCount > 0 then
						local label = string.format("Ready rack %s x%d", ammoType, readyCount)
						addDetail("Ammo", label, readyCost, ent)
					end
					if stowCount > 0 then
						local label = string.format("Backup ammo %s x%d", ammoType, stowCount)
						addDetail("Ammo", label, stowCost, ent)
					end

					addAmmoLine("READY", detail.Caliber, ammoType, readyCount)
					addAmmoLine("BACKUP", detail.Caliber, ammoType, stowCount)
				end
			end
			continue
		end

		local eclass = ACE_GetPtsType(cls)
		if eclass == "Ignore" then continue end
		if eclass == "Armor" then continue end

		local pts = ACE_GetEntPoints(ent)
		if pts ~= 0 then
			nonArmor = nonArmor + pts
			totals[eclass] = (totals[eclass] or 0) + pts
			addDetail(eclass, getEntityLabel(ent), pts, ent)
		end
	end

	table.sort(detailItems, function(a, b)
		if a.pts == b.pts then
			return a.idx < b.idx
		end
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

	local ammoList = {}
	for _, entry in pairs(ammoLines) do
		if entry.Count and entry.Count > 0 then
			ammoList[#ammoList + 1] = {
				State = entry.State,
				Caliber = entry.Caliber,
				Type = entry.Type,
				Count = math.floor(entry.Count + 0.5)
			}
		end
	end

	return nonArmor, totals, { Items = trimmed, AmmoLines = ammoList }
end

local function ACE_RebuildNonArmorPoints(Contraption, baseEnt)
	if not Contraption then return end

	local nonArmor, totals, details = ACE_CalcNonArmorPoints(Contraption, baseEnt)

	Contraption.ACEPointsNonArmor = nonArmor
	Contraption.ACEPointsPerType = Contraption.ACEPointsPerType or {}
	for key, value in pairs(totals) do
		Contraption.ACEPointsPerType[key] = value
	end
	Contraption.ACEPointsDetails = details
end

-- Rebuild armor points when dirty and synchronize totals for the breakdown.
function ACE_EnsureArmor(Contraption, baseEnt, force)
	if not Contraption then return end
	if not force then
		if not Contraption.ACEArmorDirty then return end
		if Contraption.ACEArmorCalculated and Contraption.ACEArmorDirty then return end
	end

	local base = baseEnt
	if (not IsValid(base)) and Contraption.GetACEBaseplate then
		base = Contraption:GetACEBaseplate()
	end

	local front = 0
	local side = 0
	local usedCache = false
	local cached = Contraption.ACEArmorCachedData
	if cached then
		front = cached.Front or cached.front or 0
		side = cached.Side or cached.side or 0
		Contraption.ACEArmorFront = front
		Contraption.ACEArmorSide = side
		usedCache = true
	else
		if IsValid(base) then
			local f, s = ACE_CalcContraptionArmor(base)
			front = f
			side = s
			Contraption.ACEArmorFront = f
			Contraption.ACEArmorSide = s
		end
	end

	ACE_RebuildNonArmorPoints(Contraption, base)

	-- Convert armor averages to points; side armor counts double to reflect exposure.
	local newArmorPts = (front + side * 2) * 4
	Contraption.ACEPointsPerType = Contraption.ACEPointsPerType or {}
	Contraption.ACEPointsPerType.Armor = newArmorPts

	Contraption.ACEArmorPoints = newArmorPts
	Contraption.ACEArmorDirty = false
	Contraption.ACEArmorCalculated = true

	local nonArmor = Contraption.ACEPointsNonArmor or 0
	Contraption.ACEPoints = nonArmor + newArmorPts

	local cacheKey = Contraption.ACEArmorCacheKey
	if cacheKey and not usedCache then
		ACE.DupeArmorCache = ACE.DupeArmorCache or {}
		ACE.DupeArmorCache[cacheKey] = {
			Front = front,
			Side = side
		}
	end
	Contraption.ACEArmorCacheKey = nil
	Contraption.ACEArmorCachedData = nil

	if armorDebugCvar:GetBool() then
		print(string.format("[ACE ArmorDbg] Front=%.2f Side=%.2f Pts(x4)=%.2f", front or 0, side or 0, newArmorPts))
		if IsValid(base) then
			debugoverlay.Text(base:WorldSpaceCenter(), string.format("F %.2f | S %.2f | Pts(x4) %.2f", front or 0, side or 0, newArmorPts), 30, true)
		end
	end
end

function ACE_GetEntPoints(Ent)
	local Points = 0 -- Base for per-entity point adjustments.
	--[[ Legacy mass/material-based point calculation (deprecated).
	     Kept for reference if the scoring model is revisited in the future.
	if IsValid(Ent) then
		-- legacy mass/material calculation would go here
	end
	]]

	if not IsValid(Ent) then return 0 end

	local class = Ent:GetClass()
	if ArmorClasses[class] then
		-- Armor is scored at the contraption level; individual props contribute zero here.
		return 0
	end
	if class == "acf_fueltank" then
		return 0
	end
	if class == "acf_ammo" or class == "acf_gun" or class == "acf_rack" then
		return 0
	end

	Points = Points + (Ent.ACEPoints or 0)

	return Points
end

do
	-- Hook PhysObj:SetMass so point totals update when props are modified.
	local PHYS    = FindMetaTable("PhysObj")
	local ACE_Override_SetMass = ACE_Override_SetMass or PHYS.SetMass

	function PHYS:SetMass(mass)

		local ent     = self:GetEntity()
		local oldPointValue = ent._AcePts or 0 -- Default to zero if no cached points exist yet.

	ent._AcePts = ACE_GetEntPoints(ent)

		ACE_Override_SetMass(self,mass)

		local con = ent:GetContraption()
		if not con then return end

		local delta = ent._AcePts - oldPointValue
		local eclass = ACE_GetPtsType(ent:GetClass())

		if eclass == "Ignore" then return end
		if eclass == "Armor" then
			con.ACEArmorDirty = true
			return
		end

		con.ACEPoints = (con.ACEPoints or 0) + delta
		con.ACEPointsNonArmor = (con.ACEPointsNonArmor or 0) + delta
		con.ACEPointsPerType = con.ACEPointsPerType or {}
		con.ACEPointsPerType[eclass] = (con.ACEPointsPerType[eclass] or 0) + delta
	end

	local function ACE_InitPts(Class)
		Class.ACEPoints = 0
		Class.ACEPointsNonArmor = 0
		Class.ACEArmorPoints = 0
		Class.ACEArmorDirty = true
		Class.ACEArmorCalculated = false

		Class.ACEPointsPerType = {}
		Class.ACEPointsPerType.Armor = 0
		Class.ACEPointsPerType.Engines = 0
		Class.ACEPointsPerType.Firepower = 0
		Class.ACEPointsPerType.Ammo = 0
		Class.ACEPointsPerType.AmmoReady = 0
		Class.ACEPointsPerType.AmmoBackup = 0
		Class.ACEPointsPerType.AmmoReadyRounds = 0
		Class.ACEPointsPerType.AmmoBackupRounds = 0
		Class.ACEPointsPerType.Crew = 0
		Class.ACEPointsPerType.Electronics = 0
	end

	hook.Add("cfw.contraption.created", "ACE_InitPoints", ACE_InitPts)
	hook.Add("cfw.family.created", "ACE_InitPoints", ACE_InitPts)


	function ACE_AddPts(Class, Ent)
		if not IsValid(Ent) then return end

		local conRef = Class
		local EClass = ACE_GetPtsType(Ent:GetClass())
		local newPts = ACE_GetEntPoints(Ent)
		local oldPts = Ent._AcePts or 0

		if EClass == "Ignore" then
			if Ent._ACEPointsConRef and Ent._ACEPointsConRef ~= conRef then
				ACE_RemPts(Ent._ACEPointsConRef, Ent)
			end

			Ent._ACEPointsConRef = conRef
			Ent._ACEPointsConKey = ACE_GetContraptionIndex and ACE_GetContraptionIndex(conRef) or nil
			Ent._AcePts = 0
			return
		end

		if Ent._ACEPointsConRef == conRef then
			if EClass == "Armor" then
				Class.ACEArmorDirty = true
			else
				local delta = newPts - oldPts
				if delta ~= 0 then
					Class.ACEPoints = (Class.ACEPoints or 0) + delta
					Class.ACEPointsNonArmor = (Class.ACEPointsNonArmor or 0) + delta
					Class.ACEPointsPerType = Class.ACEPointsPerType or {}
					Class.ACEPointsPerType[EClass] = (Class.ACEPointsPerType[EClass] or 0) + delta
				end
			end

			Ent._AcePts = newPts
			return
		end

		if Ent._ACEPointsConRef and Ent._ACEPointsConRef ~= conRef then
			ACE_RemPts(Ent._ACEPointsConRef, Ent)
		end

		Ent._ACEPointsConRef = conRef
		Ent._ACEPointsConKey = ACE_GetContraptionIndex and ACE_GetContraptionIndex(conRef) or nil
		Ent._AcePts = newPts

		if EClass == "Armor" then
			Class.ACEArmorDirty = true
		else
			Class.ACEPoints = (Class.ACEPoints or 0) + newPts
			Class.ACEPointsNonArmor = (Class.ACEPointsNonArmor or 0) + newPts
			Class.ACEPointsPerType = Class.ACEPointsPerType or {}
			Class.ACEPointsPerType[EClass] = (Class.ACEPointsPerType[EClass] or 0) + newPts
		end
	end
	hook.Add("cfw.contraption.entityAdded", "ACE_AddPoints", ACE_AddPts)
	hook.Add("cfw.family.added", "ACE_AddPoints", ACE_AddPts)

	function ACE_RemPts(Class, Ent)
		if not IsValid(Ent) then return end

		if Ent._ACEPointsConRef and Ent._ACEPointsConRef ~= Class then return end
		Ent._ACEPointsConKey = nil
		Ent._ACEPointsConRef = nil

		local EClass = ACE_GetPtsType(Ent:GetClass())

		if EClass == "Ignore" then return end
		if EClass == "Armor" then
			Class.ACEArmorDirty = true
			return
		end

		local AcePts = Ent._AcePts or 0 -- Use cached points to avoid heavy recalculation on removal.

		Class.ACEPoints = Class.ACEPoints - AcePts
		Class.ACEPointsNonArmor = (Class.ACEPointsNonArmor or 0) - AcePts

		Class.ACEPointsPerType[EClass] = Class.ACEPointsPerType[EClass] - AcePts
	end

	hook.Add("cfw.contraption.entityRemoved", "ACE_RemPoints", ACE_RemPts)
	hook.Add("cfw.family.subbed", "ACE_RemPoints", ACE_RemPts)


end
