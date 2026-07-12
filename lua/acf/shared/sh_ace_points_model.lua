--[[-----------------------------------------------------------------------------
	ACE Contraption Points -- pricing model (redesign, 2026-07-12)

	Canonical reference: GMod-LLM-Wiki/tools/ace_points_model.py -- this file mirrors
	it function-for-function; every number here is canonical from there.

	AMMO IS FREE (user, 2026-07-12): round COUNT is a player choice, never a points
	input -- mass/MaxWeight and cook-off risk already price hauling ammo. Crates
	contribute ZERO points. Rounds still price guns/racks via the candidate-round
	adapters below: you pay for what you are BUILT to fire, not for how much you carry.

	SECTION 1 -- PURE MODEL. Plain Lua 5.1 (only math/string/table + base coercion).
	No GMod/ACE global is CALLED at load time or inside these functions; they take
	plain values/tables. This section is run offline under a vanilla Lua interpreter
	against ground-truth dumps for parity testing, so it must load and run there.

	SECTION 2 -- ADAPTERS. GLua: entity in -> plain tables/numbers out, then it calls
	the pure functions. Every GMod/ACE call lives INSIDE an adapter body (never at
	file scope), so the whole file still loads cleanly under vanilla Lua.
-------------------------------------------------------------------------------]]

ACE = ACE or {}

-- ================================================================
--  SECTION 1 -- PURE MODEL  (vanilla Lua 5.1; no GMod calls)
-- ================================================================

-- Calibrated knobs + global re-anchor -- the ONLY tunables, all in one table.
-- Tuning workflow: re-fit the free constants against the user's ranked corpus
-- (data/advdupe2/00 ACF/ACE/PointExpectedValues) with
--     python tools/ace_points_model.py <groundtruth_dir> --calibrate
-- kGun/kArmor/kEng/P50 are the free constants; Scale is a pure re-anchor that moves
-- the hyper-modern-MBT reference build (~19906.6 raw, ammo-free) to 10000 pts and is
-- applied uniformly to every category, so all calibrated rankings/ratios are preserved and
-- only the absolute numbers move (recompute it via the reference build in the .py __main__).
-- Retune fields IN PLACE so the pure upvalue below keeps pointing at the live table.
ACE.PointsModel = ACE.PointsModel or {
	kGun   = 5.408,            -- firepower scale
	kArmor = 0.3057,           -- armor survivability scale
	kEng   = 1.501,            -- engine power scale
	P50    = 548.5,            -- gate half-point: pen where a round defeats half the meta
	Scale  = 10000 / 19906.6,  -- global re-anchor: 10000 pts = hyper-modern MBT reference
}

local Model = ACE.PointsModel

local pi   = math.pi
local sqrt = math.sqrt
local max  = math.max
local min  = math.min

-- --- FIXED structural constants (NOT calibration knobs) ---
local FRAREA_REF = pi * 5.0 ^ 2   -- 100mm reference round cross-section (radius 5cm), cm^2
local BLAST_REF  = 6.0            -- kg filler reference
local HE_EQUIV   = 30.0           -- HE blast pen-equivalent: 30 * filler_kg^(2/3) mm
local GATE_FLOOR = 0.2            -- any lethal round still hurts light targets
-- GATE is LINEAR (GATE_EXP = 1): effectiveness = pen/(pen+P50). User pick 2026-07-12
-- for max legibility (a Hill-2 fit landed identically), so no exponent term is needed.
local GUN_FLAT    = 20.0          -- no weapon is free (utility launchers price here)
local RACK_FLAT   = 100.0
local RACK_WINDOW = 30.0          -- 30s engagement window: a rack's sustained rate is capped at
                                  -- tubes/window -- it is NOT an infinite-reload DPS machine.
                                  -- Tubes are launcher hardware (mountpoint count), not a
                                  -- carried-round choice; keeps missiles/planes sanely priced.
local CREW_SEAT   = 100.0
local LOADER_SEAT = 300.0
local EXP_MM = 1.4                -- armor thickness exponent (intensive term -- untouched)
local EXP_HP = 1.0                -- armor HP exponent. LINEAR/extensive on purpose: N props
                                  -- of the same total HP price identically to 1 prop, which
                                  -- kills a fragmentation exploit the inherited 0.45 exponent
                                  -- allowed (a naive 4-way split was 2.16x before, 1.00x after).

-- --- type tables (verbatim semantics from ace_points_model.py:35-59) ---
local DAMAGE_MULT = {   -- post-pen damage multipliers (acf_globals.lua:253-261 ACF.*DamageMult)
	AP = 2.0, APHE = 1.75, APDS = 3.0, APFSDS = 3.0, HVAP = 2.0,
	HEAT = 6.0, HE = 2.0, HESH = 1.2, HP = 8.0, FL = 1.4,
}
local TYPE_MAP = {      -- round type id -> damage family
	AP = "AP", APHE = "APHE", APDS = "APDS", APFSDS = "APFSDS", HVAP = "HVAP",
	HP = "HP", CAP = "AP",
	HEAT = "HEAT", HEATFS = "HEAT", THEAT = "HEAT", THEATFS = "HEAT", CHEAT = "HEAT",
	GLATGM = "HEAT", ["GLATGM-HE"] = "HE",
	HE = "HE", HEFS = "HE", CHE = "HE", CHF = "HE",
	HESH = "HESH",
	SM = "SM", FLR = "SM", FL = "SM", Refill = "Refill",
}
-- HEAT jet family: the shaped-charge slug caliber (not the shell body) sets the area.
local HEAT_FAMILY = { HEAT = true, HEATFS = true, THEAT = true, THEATFS = true, CHEAT = true, GLATGM = true }
local UTILITY     = { SM = true, Refill = true }   -- smoke/refill carry no post-pen lethality
-- loader-buff-exempt weapon classes (autoloaders/rapid guns; acf_gun/init.lua:462). SL is
-- included by the model beyond the live init.lua:462 check so salvo launchers price like the
-- other auto classes rather than taking the crewed-loader reload buff.
local AUTO_CLASSES = { AC = true, MG = true, RAC = true, HMG = true, GL = true, SA = true, SL = true }
local FUEL_FACTOR  = { Petrol = 1.0, Diesel = 1.2, Multifuel = 1.2, Electric = 0.8 }
-- guidance name -> pen multiplier. Subset of ACE.MissileGuidanceFactors (acf_globals.lua:229);
-- every entry omitted here is 1.0 there, which is this table's default, so the two agree.
local GUIDANCE = {
	Dumb = 0.5, Straight_Running = 0.6, Radar = 1.4, Semiactive = 1.4,
	Infrared = 1.5, Top_Attack_IR = 1.8, GPS = 0.8, GPS_TerrainAvoidant = 0.9,
}

-- Lethality once the round is INSIDE the armor, as its three added parts (the player story:
-- "1 base + hole size + blast"): any penetrating round hurts (1), plus the hole it tears
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
-- displays can show the "x 1.5 guidance" factor instead of hiding it inside roundCost.
function ACE_Points_GuidanceMul(round)
	local g = round.guidance
	if g and g ~= "" then
		return GUIDANCE[g] or 1.0
	end
	return 1.0
end

-- Per-round lethality: lethalityPen * postPenMult * guidance. Guidance (a GUIDANCE key) is only
-- present on missile ammo; anything else (nil / "") is 1.0, matching the Python model.
function ACE_Points_RoundCost(round)
	return ACE_Points_LethalityPen(round) * ACE_Points_PostPenMult(round)
		* ACE_Points_GuidanceMul(round)
end

-- Share of the meta this pen defeats. LINEAR gate, floored so any lethal round still counts.
function ACE_Points_Gate(pen)
	pen = tonumber(pen) or 0
	if pen <= 0 then return GATE_FLOOR end
	return max(pen / (pen + Model.P50), GATE_FLOOR)
end

-- Round score = gate * roundCost. NOTE: the gate uses the RAW maxPen (not lethalityPen),
-- exactly as ace_points_model.py price_components does.
function ACE_Points_RoundScore(round)
	return ACE_Points_Gate(round.maxPen) * ACE_Points_RoundCost(round)
end

-- Static sustained cadence. Magazine-aware (burst then mag reload) and loader-aware for
-- non-auto classes. Wire ROFLimit is deliberately ignored -- baseRps is the static calc.
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

-- Gun firepower cost (scaled). Priced at the nastiest round it is built to fire, floored so
-- no weapon is free.
function ACE_Points_GunCost(sustainedRps, bestScore)
	return max(Model.kGun * (tonumber(sustainedRps) or 0) * (tonumber(bestScore) or 0), GUN_FLAT) * Model.Scale
end

-- Rack firepower cost (scaled). rackRate is the reload rate CAPPED at the tube count over the
-- engagement window (maxMissile/RACK_WINDOW) so a rack is not priced as an infinite-reload DPS
-- machine; RACK_FLAT floors it. reloadTime defaults to 10 (nil/0), maxMissile defaults to 1.
-- bestScore is the max ACE_Points_RoundScore over the rack's candidate rounds (adapter supplies it).
function ACE_Points_RackCost(reloadTime, maxMissile, bestScore)
	local rt = tonumber(reloadTime) or 0
	if rt == 0 then rt = 10.0 end
	local mm = tonumber(maxMissile) or 0
	if mm == 0 then mm = 1 end
	local rackRate = min(1.0 / max(rt, 0.5), mm / RACK_WINDOW)
	return max(Model.kGun * rackRate * (tonumber(bestScore) or 0), RACK_FLAT) * Model.Scale
end

-- NOTE: there is deliberately NO crate cost. Ammo is free (see the header) -- crates price
-- nothing; their rounds only feed the gun/rack candidate-round scoring above.

-- Effective armor thickness: LOS armour weighted 0.7 KE / 0.3 CHEM effectiveness.
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

-- Normalize a guidance descriptor to a GUIDANCE-table key (spaces/dashes -> underscore),
-- same normalization the legacy guidance-factor resolver used before this model replaced it.
local function normalizeGuidanceName(name)
	if not isstring(name) or name == "" then return nil end
	return (name:gsub("%s+", "_"):gsub("%-", "_"))
end

-- Pull the guidance NAME out of BulletData.guidance. Missiles store a TABLE; take its name via
-- candidate keys ClassName/class/GuidanceName/Guidance/Type (the legacy resolver's order).
-- Also accept a plain string, and, defensively, a plain list of mode names
-- ({"Dumb","Infrared",...} -- the form the missile round defs actually use): price [1].
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

-- Armor material id -> { KE effectiveness, CHEM effectiveness }.
-- These mirror the CANONICAL ace_points_model.py MATERIALS table, which the parity/live gate
-- compares against. INTENDED DESIGN (confirmed 2026-07-12): these are calibrated PRICING
-- weights validated against the ranked-dupe corpus, NOT a live mirror of the armor resolver.
-- They are a curated read of lua/acf/shared/armor/*.lua, not the raw fields:
--   * RHA/CHA/Cer/DU/Ti define no HEATeffectiveness, so chem == ke (their ke = raw effectiveness).
--   * Alum: chem = ke / HEATMul (0.8325 / 5); the file carries HEATMul=5, not HEATeffectiveness.
--   * ERA: hand-tuned (2.5, 8.0); the live era.lua raw fields (3 / 10) are pre-angle-factor
--     combat values, deliberately not used for pricing.
-- Do not "fix" these to track the armor files -- retune them via the corpus fit instead.
-- Unknown material -> (1, 1), matching MATERIALS.get(mat, (1.0, 1.0)).
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

-- Public accessor so displays (e.g. the armor tool's client-side cost preview) price with the
-- SAME curated weights the server charges. Returns nil for unknown materials so callers can
-- fall back to live material data. Pure: safe in any realm.
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

	-- Guidance folds the old per-missile pricing premium into roundCost. Candidates:
	-- BulletData.guidance/Guidance, else Data7 (the runtime-configured guidance object the
	-- legacy pricing read). GLATGM (gun-launched grenade ammo) opts out, as it always has.
	-- Non-missiles carry none, so guidance stays nil (1.0).
	local guid = bdata.guidance or bdata.Guidance or bdata.Data7
	if guid ~= nil and not ACE_IsGLATGMAmmoType(bdata.Type) then
		round.guidance = resolveGuidanceName(guid)
	end

	return round
end

-- Highest round score the gun is built to fire. Candidate order matches ace_points_model.py:
--   1. rounds of valid crates in gun.AmmoLink that have BulletData (link membership only);
--   2. else acf_ammo crates in the gun's contraption whose BulletData.Id == gun.Id;
--   3. else the gun's own BulletData.
-- conEnts is the gun's contraption entity list (caller-supplied). Returns 0 with no candidates.
function ACE_Points_GunBestScore(gun, conEnts)
	if not ACE_IsEnt(gun) then return 0 end

	local best   = 0
	local scored = false

	local link = gun.AmmoLink
	if istable(link) then
		for _, crate in pairs(link) do
			if ACE_IsEnt(crate) and istable(crate.BulletData) then
				local round = ACE_Points_RoundFromBullet(crate.BulletData)
				if round then
					best   = max(best, ACE_Points_RoundScore(round))
					scored = true
				end
			end
		end
	end

	if not scored and istable(conEnts) then
		for _, ent in ipairs(conEnts) do
			if ACE_IsEnt(ent) and ent:GetClass() == "acf_ammo" and istable(ent.BulletData)
				and ent.BulletData.Id == gun.Id then
				local round = ACE_Points_RoundFromBullet(ent.BulletData)
				if round then
					best   = max(best, ACE_Points_RoundScore(round))
					scored = true
				end
			end
		end
	end

	if not scored and istable(gun.BulletData) then
		local round = ACE_Points_RoundFromBullet(gun.BulletData)
		if round then
			best = max(best, ACE_Points_RoundScore(round))
		end
	end

	return best
end

-- Highest round score the rack is BUILT to fire. STATIC DESIGN: prices the linked-crate round,
-- NEVER the live-loaded tube state, so points don't jump when a missile actually loads. Candidates:
--   1. rounds of valid crates in rack.AmmoLink (racks share the gun AmmoLink field, acf_rack/init.lua:99);
--   2. else the rack's own BulletData when it holds a real (non-Empty) round.
-- Returns 0 with no candidates (RACK_FLAT then floors the cost).
function ACE_Points_RackBestScore(rack)
	if not ACE_IsEnt(rack) then return 0 end

	local best   = 0
	local scored = false

	local link = rack.AmmoLink
	if istable(link) then
		for _, crate in pairs(link) do
			if ACE_IsEnt(crate) and istable(crate.BulletData) then
				local round = ACE_Points_RoundFromBullet(crate.BulletData)
				if round then
					best   = max(best, ACE_Points_RoundScore(round))
					scored = true
				end
			end
		end
	end

	if not scored and istable(rack.BulletData) then
		local rtype = rack.BulletData.Type
		if rtype and rtype ~= "" and rtype ~= "Empty" then
			local round = ACE_Points_RoundFromBullet(rack.BulletData)
			if round then
				best = max(best, ACE_Points_RoundScore(round))
			end
		end
	end

	return best
end

-- Static sustained RPS for a gun: base = ACE_GetGunConfiguredRps(gun, 0) (wire ROFLimit forced
-- out), then magazine/loader-adjusted by the pure model. loaders = the gun's OWN linked loader
-- seats (gun.LoaderCount, maintained by the gun's Link/Unlink paths) -- the same source the
-- live reload mechanic uses. Deliberately NOT contraption crew: that smeared the main gun's
-- loader buff onto smoke mortars and missed loaders linked across contraption fragments.
-- Gun class for the auto check is gun.Class (weapon class id like "AC"/"MG";
-- acf_gun/init.lua sets self.Class = Lookup.gunclass at init.lua:181).
function ACE_Points_GunSustainedRps(gun)
	if not ACE_IsEnt(gun) then return 0 end
	local base = ACE_GetGunConfiguredRps(gun, 0)
	return ACE_Points_SustainedRps(base, gun.MagSize, gun.MagReload, gun.Class, gun.LoaderCount)
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

	local armourMm = tonumber(acf.MaxArmour or acf.Armour) or 0
	local hp       = tonumber(acf.MaxHealth or acf.Health) or 0
	if armourMm <= 0 or hp <= 0 then return nil end

	local ke, chem = materialEff(acf.Material or ent.ACF_Material)
	return ACE_Points_EffectiveMm(armourMm, ke, chem), hp
end
