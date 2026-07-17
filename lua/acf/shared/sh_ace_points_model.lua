--[[-----------------------------------------------------------------------------
	ACE Contraption Points -- pricing model

	Ammo count is not a points input; linked round capability prices guns and racks.
	Retune the calibrated constants together against the reference corpus.
	The pure model must load under vanilla Lua 5.1; GMod calls belong in the adapters.
-------------------------------------------------------------------------------]]

ACE = ACE or {}

-- ================================================================
--  SECTION 1 -- PURE MODEL  (vanilla Lua 5.1; no GMod calls)
-- ================================================================

-- Retune these fields together and mutate them in place because Model retains this table.
ACE.PointsModel = ACE.PointsModel or {
	kGun   = 5.408,            -- firepower scale
	kArmor = 0.259845,         -- armor survivability scale
	kEng   = 1.501,            -- engine power scale
	P50    = 548.5,            -- gate half-point: pen where a round defeats half the meta
	Scale  = 0.65,             -- global display scale; sets how much of PointsLimit real fielded
	                           -- vehicles use, deliberately independent of the corpus fit below
}

local Model = ACE.PointsModel

local pi   = math.pi
local sqrt = math.sqrt
local max  = math.max
local min  = math.min

-- --- FIXED structural constants (NOT calibration knobs) ---
local FRAREA_REF = pi * 5.0 ^ 2   -- 100mm reference round cross-section (radius 5cm), cm^2
local BLAST_REF  = 6.0            -- kg filler reference
-- HE lethality pen-equivalent: 30 * filler_kg^(2/3) mm -- the splash coverage channel
-- (blast radius^2 scales with kg^(2/3)).
local HE_EQUIV   = 30.0
-- Armor actually defeated by blast: filler_kg x HEPower / HEBlastPenetration (the damage
-- code's own blast-penetration channel). Used by the gate so heavy ordnance that genuinely
-- penetrates through blast is judged by that real reach rather than only its splash equivalent.
local HE_BLAST_PEN_PER_KG = 8000.0 / 3500.0
local ROUND_COST_FLOOR = 1.0        -- every configured round has a non-zero weapon-pricing input
-- HE's splash, module damage, and soft-target utility add value beyond its direct lethality terms.
local HE_INTRINSIC_VALUE_MULT = 1.50
-- GATE is LINEAR (GATE_EXP = 1): effectiveness = pen/(pen+P50). Kept linear for legibility;
-- a saturating (Hill-style) fit prices the corpus the same, so no exponent term is needed.
local GUN_FLAT    = 20.0          -- no weapon is free (utility launchers price here)
local RACK_FLAT   = 100.0
-- 30s engagement window: a rack's sustained rate is capped at tubes/window -- it is NOT an
-- infinite-reload DPS machine. Tubes are launcher hardware (mountpoint count), not a
-- carried-round choice; keeps missiles/planes sanely priced. Also sets the gun/rack priced-rate
-- floor (1/RACK_WINDOW): no mounted delivery system prices below one round per window, closing
-- the slow-alpha and tiny-ROFLimit aliases of the same cheese.
local RACK_WINDOW = 30.0
local CREW_SEAT   = 100.0
local LOADER_SEAT = 300.0
local EXP_MM = 1.4                -- armor thickness exponent (intensive term -- untouched)
-- Armor HP exponent. LINEAR/extensive on purpose: N props of the same total HP price
-- identically to 1 prop, so splitting armor into fragments is points-neutral. A sub-linear
-- exponent would reward that split as a pricing exploit.
local EXP_HP = 1.0

-- --- type tables ---
local DAMAGE_MULT = {   -- post-pen damage multipliers (acf_globals.lua:253-261 ACF.*DamageMult)
	AP = 2.0, APHE = 1.75, APDS = 3.0, APFSDS = 3.0, HVAP = 2.0,
	HEAT = 6.0, HE = 2.0, HESH = 1.2, HP = 8.0, FL = 1.4,
}
local TYPE_MAP = {      -- round type id -> damage family
	AP = "AP", APHE = "APHE", APDS = "APDS", APFSDS = "APFSDS", HVAP = "HVAP",
	HP = "HP", CAP = "AP",
	HEAT = "HEAT", HEATFS = "HEAT", THEAT = "HEAT", THEATFS = "HEAT", CHEAT = "HEAT",
	GLATGM = "HEAT", ["GLATGM-HE"] = "HE",
	HE = "HE", HEFS = "HE", CHE = "HE",
	HESH = "HESH",
	SM = "SM", FLR = "SM", CHF = "SM", FL = "FL", Refill = "Refill",
}
-- HEAT jet family: the shaped-charge slug caliber (not the shell body) sets the area.
local HEAT_FAMILY = { HEAT = true, HEATFS = true, THEAT = true, THEATFS = true, CHEAT = true, GLATGM = true }
local UTILITY     = { SM = true, Refill = true }   -- smoke, chaff, flares, and refill carry no damage
-- Gun classes whose definitions set noloader=true, so acf_gun refuses loader links. SL is
-- included by the model so salvo launchers price like the other auto classes rather than
-- taking a crewed-loader reload buff they cannot use.
local AUTO_CLASSES = { AC = true, MG = true, RAC = true, HMG = true, GL = true, SA = true, SL = true, AL = true }
local FUEL_FACTOR  = { Petrol = 1.0, Diesel = 1.2, Multifuel = 1.2, Electric = 0.8 }
-- Guidance names omitted from this table use a 1.0 multiplier.
local GUIDANCE = {
	Dumb = 0.5, Straight_Running = 0.6, Radar = 1.4, Semiactive = 1.4,
	Infrared = 1.5, Top_Attack_IR = 1.8, GPS = 0.8, GPS_TerrainAvoidant = 0.9,
}

-- Lethality once the round is inside armor: base damage plus the hole it tears
-- (frontal area x the type's damage multiplier, normalized so a 100mm AP shell = 1.0; HEAT
-- uses its jet cross-section, not the shell body), plus the explosive payload it delivers
-- (sqrt of filler kg vs a 6kg reference). Utility (smoke/refill) rounds return 0,0,0.
function ACE_Points_PostPenParts(round)
	local t = round.Type
	if not t or t == "" then t = "AP" end
	local fam = TYPE_MAP[t] or "AP"
	if UTILITY[fam] then return 0.0, 0.0, 0.0 end

	local mult = DAMAGE_MULT[fam] or 1.0
	local slug = tonumber(round.SlugCaliber) or 0
	local area
	if HEAT_FAMILY[t] and slug ~= 0 then
		area = pi * (slug / 2) ^ 2            -- shaped-charge jet, not shell body
	else
		area = tonumber(round.FrArea) or 0.0
	end

	local blast = tonumber(round.blastMass) or 0.0
	return 1.0,
		(area * mult) / (FRAREA_REF * DAMAGE_MULT.AP),    -- FrArea normalized vs 100mm AP
		sqrt(max(blast, 0.0) / BLAST_REF)
end

-- The three parts summed: the per-round "inside-armor damage" multiplier.
function ACE_Points_PostPenMult(round)
	local base, hole, blast = ACE_Points_PostPenParts(round)
	return base + hole + blast
end

-- Penetration used for lethality: raw maxPen, but HE/HESH floor it at a blast-equivalent so
-- big fillers still register a threat even with token stated pen.
function ACE_Points_LethalityPen(round)
	local pen = tonumber(round.maxPen) or 0.0
	local fam = TYPE_MAP[round.Type or "AP"] or "AP"
	if fam == "HE" or fam == "HESH" then
		local blast = tonumber(round.blastMass) or 0.0
		pen = max(pen, HE_EQUIV * blast ^ (2.0 / 3.0))
	end
	return pen
end

-- Guidance multiplier for a round (1.0 for everything but guided missile ammo). Public so
-- displays can show the "x 1.5 guidance" factor instead of hiding it inside baseRoundCost.
function ACE_Points_GuidanceMul(round)
	local g = round.guidance
	if g and g ~= "" then
		return GUIDANCE[g] or 1.0
	end
	return 1.0
end

-- Intrinsic value beyond direct lethality terms; shared by billing and explanatory readouts.
function ACE_Points_IntrinsicValueMul(round)
	local fam = TYPE_MAP[round and round.Type or "AP"] or "AP"
	return fam == "HE" and HE_INTRINSIC_VALUE_MULT or 1.0
end

-- Intrinsic cost of one configured round. Inventory count is not billed, but every weapon
-- multiplies this value by its own delivery rate and threat factor.
function ACE_Points_BaseRoundCost(round)
	local cost = ACE_Points_LethalityPen(round) * ACE_Points_PostPenMult(round)
		* ACE_Points_GuidanceMul(round) * ACE_Points_IntrinsicValueMul(round)
	return max(cost, ROUND_COST_FLOOR)
end

-- Share of the meta this pen defeats. The curve is continuous from zero with no minimum share.
function ACE_Points_Gate(pen)
	pen = tonumber(pen) or 0
	if pen <= 0 then return 0 end
	return pen / (pen + Model.P50)
end

-- Penetration the GATE judges a round by. HE uses its blast lethality reach because splash,
-- module damage, and soft-target effects create combat value without literal armor penetration;
-- HESH retains only the damage code's literal blast-penetration channel.
function ACE_Points_GatePen(round)
	local pen = tonumber(round.maxPen) or 0.0
	local fam = TYPE_MAP[round.Type or "AP"] or "AP"
	if fam == "HE" then
		pen = max(pen, ACE_Points_LethalityPen(round))
		local blast = tonumber(round.blastMass) or 0.0
		pen = max(pen, blast * HE_BLAST_PEN_PER_KG)
	elseif fam == "HESH" then
		local blast = tonumber(round.blastMass) or 0.0
		pen = max(pen, blast * HE_BLAST_PEN_PER_KG)
	end
	return pen
end

-- Round score = threat * baseRoundCost.
function ACE_Points_RoundScore(round)
	return ACE_Points_Gate(ACE_Points_GatePen(round)) * ACE_Points_BaseRoundCost(round)
end

-- Candidate ordering is final weapon output, then per-shot score, then stable source order.
function ACE_Points_IsBetterCandidate(candidate, best)
	if not best then return true end
	if candidate.FinalScore ~= best.FinalScore then return candidate.FinalScore > best.FinalScore end
	if candidate.RoundScore ~= best.RoundScore then return candidate.RoundScore > best.RoundScore end
	return candidate.SourceIndex < best.SourceIndex
end

-- Static sustained cadence. Magazine-aware (burst then mag reload) and loader-aware for
-- non-auto classes. baseRps already folds in the gun's current wire ROFLimit (the adapter
-- below applies it via ACE_GetGunConfiguredRps before calling here), so a low limit lengthens
-- the effective cycle through this same math rather than being ignored.
function ACE_Points_SustainedRps(baseRps, magSize, magReload, gunClass, loaders)
	local base   = tonumber(baseRps) or 0
	local mag    = tonumber(magSize) or 0
	local magrel = tonumber(magReload) or 0
	loaders      = tonumber(loaders) or 0

	if mag > 1 and magrel > 0 and base > 0 then
		base = mag / (mag / base + magrel)
	end
	if not AUTO_CLASSES[gunClass or ""] then
		base = base / max(1.25 - 0.25 * loaders, 0.5)   -- crewed-loader buff (static design)
	end
	return base
end

-- Gun firepower cost (scaled). This is called once per gun entity; identical guns therefore
-- add linearly instead of sharing or deduplicating the round cost.
function ACE_Points_GunCost(sustainedRps, baseRoundCost, threat)
	local pricedRps = max(tonumber(sustainedRps) or 0, 1.0 / RACK_WINDOW)
	return max(Model.kGun
		* pricedRps
		* (tonumber(baseRoundCost) or 0)
		* (tonumber(threat) or 0), GUN_FLAT) * Model.Scale
end

function ACE_Points_RackRate(reloadTime, maxMissile)
	local rt = tonumber(reloadTime) or 0
	if rt == 0 then rt = 10.0 end
	local mm = tonumber(maxMissile) or 0
	if mm == 0 then mm = 1 end
	return min(1.0 / max(rt, 0.5), mm / RACK_WINDOW)
end

function ACE_Points_RackCostFromRate(rate, bestScore)
	local pricedRate = max(tonumber(rate) or 0, 1.0 / RACK_WINDOW)
	return max(Model.kGun * pricedRate
		* (tonumber(bestScore) or 0), RACK_FLAT) * Model.Scale
end

-- Public so readouts can tell a player when the priced-rate floor changed their bill, instead
-- of leaving the window a silently duplicated magic number.
function ACE_Points_RateFloor()
	return 1.0 / RACK_WINDOW
end

-- Tube count caps sustained rack rate over the engagement window.
function ACE_Points_RackCost(reloadTime, maxMissile, bestScore)
	return ACE_Points_RackCostFromRate(ACE_Points_RackRate(reloadTime, maxMissile), bestScore)
end

-- Mounted charges use one tube-window without the rack hardware floor. Stored ammo remains free.
function ACE_Points_ChargeCost(fillerKg)
	fillerKg = tonumber(fillerKg) or 0
	if fillerKg <= 0 then return 0 end
	local round = { Type = "HE", maxPen = 0, FrArea = 0, blastMass = fillerKg, guidance = "Dumb" }
	return Model.kGun * (1.0 / RACK_WINDOW) * ACE_Points_RoundScore(round) * Model.Scale
end

function ACE_Points_EffectiveMm(armourMm, ke, chem)
	return (tonumber(armourMm) or 0) * (0.7 * (tonumber(ke) or 1) + 0.3 * (tonumber(chem) or 1))
end

-- Per-prop armor survivability cost (scaled). mm is intensive (^1.4), HP is linear (^1.0).
function ACE_Points_ArmorProp(effMm, maxHealth)
	return Model.kArmor * 100.0
		* ((tonumber(effMm) or 0) / 50.0) ^ EXP_MM
		* ((tonumber(maxHealth) or 0) / 75.0) ^ EXP_HP
		* Model.Scale
end

-- Engine cost (scaled). hp is peak power (peakkw / 0.7457); fuel scales upkeep-ish value.
function ACE_Points_EngineCost(hp, fuelType)
	return Model.kEng * (tonumber(hp) or 0) * (FUEL_FACTOR[fuelType or "Petrol"] or 1.0) * Model.Scale
end

-- Crew seat cost (scaled). Loader seats cost more than generic seats.
function ACE_Points_CrewCost(isLoader)
	return (isLoader and LOADER_SEAT or CREW_SEAT) * Model.Scale
end

-- ================================================================
--  SECTION 2 -- ADAPTERS  (GLua; entity -> plain values -> pure funcs)
-- ================================================================

-- Guidance table keys replace spaces and dashes with underscores.
local function normalizeGuidanceName(name)
	if not isstring(name) or name == "" then return nil end
	return (name:gsub("%s+", "_"):gsub("%-", "_"))
end

-- Guidance may be a serialized string, keyed table, or ordered mode list.
local function resolveGuidanceName(guidanceValue)
	if isstring(guidanceValue) then
		local name = ACE_GetConfigurableName(guidanceValue, "")
		if name == "" then name = guidanceValue end
		return normalizeGuidanceName(name)
	elseif istable(guidanceValue) then
		local name = guidanceValue.ClassName or guidanceValue.class or guidanceValue.GuidanceName
			or guidanceValue.Guidance or guidanceValue.Type
		if name == nil then name = guidanceValue[1] end
		return normalizeGuidanceName(name)
	end
	return nil
end

-- These calibrated pricing weights intentionally differ from some live armor material values.
-- Retune them against the reference corpus; unknown materials use (1, 1).
local MATERIAL_EFF = {
	RHA   = { 1.0,    1.0 },
	CHA   = { 0.98,   0.98 },
	Cer   = { 2.05,   2.05 },
	DU    = { 3.0,    3.0 },
	Ti    = { 1.7,    1.7 },
	Alum  = { 0.8325, 0.8325 / 5.0 },
	ERA   = { 2.5,    8.0 },
	Rub   = { 0.05,   3.0 },
	Texto = { 0.5,    1.2 },
}

local function materialEff(mat)
	local eff = MATERIAL_EFF[mat or "RHA"]
	if not eff then return 1.0, 1.0 end
	return eff[1], eff[2]
end

-- Returns nil for unknown materials so display code can fall back to live material data.
function ACE_Points_MaterialEff(mat)
	local eff = MATERIAL_EFF[mat]
	if not eff then return nil end
	return eff[1], eff[2]
end

-- Build the plain pricing round from a gun/crate/rack BulletData table. nil if not a table.
function ACE_Points_RoundFromBullet(bdata)
	if not istable(bdata) then return nil end

	local round = {
		Type        = ACE_ResolveAmmoType(nil, bdata),   -- bdata branch: bdata.Type or bdata.RoundType
		maxPen      = ACE_GetAmmoMaxPen(bdata),
		FrArea      = tonumber(bdata.FrArea) or 0,
		SlugCaliber = tonumber(bdata.SlugCaliber),       -- HEAT family only; nil otherwise
		blastMass   = ACE_GetAmmoBlastMass(bdata),
	}

	-- Guidance folds the old per-missile pricing premium into baseRoundCost. Candidates:
	-- BulletData.guidance/Guidance, else Data7 (the runtime-configured guidance object the
	-- legacy pricing read). GLATGM (gun-launched grenade ammo) opts out, as it always has.
	-- Non-missiles carry none, so guidance stays nil (1.0).
	local guid = bdata.guidance or bdata.Guidance or bdata.Data7
	if guid ~= nil and not ACE_IsGLATGMAmmoType(bdata.Type) then
		round.guidance = resolveGuidanceName(guid)
	end

	return round
end

-- ROFLimit is a pricing input and its trigger path must dirty points. LoaderCount is local to
-- the gun, including loaders linked across contraption fragments.
function ACE_Points_GunSustainedRps(gun, bdata, crate)
	if not ACE_IsEnt(gun) then return 0 end
	local base = ACE_GetGunConfiguredRps(gun, tonumber(gun.ROFLimit) or 0, bdata, crate)
	return ACE_Points_SustainedRps(base, gun.MagSize, gun.MagReload, gun.Class, gun.LoaderCount)
end

-- Mounted charge (scalable explosives / bombs family) -> scaled points. Prices the charge's
-- REAL filler mass -- self.FillerMass, kg of HE, set once at spawn from the scaled charge
-- volume -- as mounted ordnance via ACE_Points_ChargeCost. 0 for a filler-less/invalid entity.
function ACE_Points_ChargeEntCost(ent)
	if not ACE_IsEnt(ent) then return 0 end
	return ACE_Points_ChargeCost(tonumber(ent.FillerMass) or 0)
end

-- Prop -> (effectiveMm, maxHealth) for the armor term, or nil to skip. Skips ACF/ACE
-- components and pods (they price in their own categories) and props with no armour or HP.
-- Uses MAX armour/health (static design). Material ke/chem via the curated MATERIAL_EFF above.
function ACE_Points_PropArmor(ent)
	if not ACE_IsEnt(ent) then return nil end

	local cls = ent:GetClass() or ""
	if cls:sub(1, 4) == "acf_" or cls:sub(1, 4) == "ace_" or cls:sub(1, 5) == "gmod_"
		or cls:find("pod", 1, true) then
		return nil
	end

	local acf = ent.ACF
	if not istable(acf) then return nil end

	local armourMm = tonumber(acf.MaxArmour) or 0
	local hp       = tonumber(acf.MaxHealth) or 0
	if armourMm <= 0 or hp <= 0 then return nil end

	local ke, chem = materialEff(acf.Material or ent.ACF_Material)
	return ACE_Points_EffectiveMm(armourMm, ke, chem), hp
end
