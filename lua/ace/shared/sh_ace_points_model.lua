ACE = ACE or {}
ACE.Points = ACE.Points or {}

--[[-----------------------------------------------------------------------------
	ACE Contraption Points -- pricing model

	The most expensive linked configuration sets weapon cost; inventory is not billed.
	Shell length and assigned warhead premiums set firepower; cadence adds a mild premium.
	The pure model must load under vanilla Lua 5.1; GMod calls belong in the adapters.
-------------------------------------------------------------------------------]]

-- ================================================================
--  SECTION 1 -- PURE MODEL  (vanilla Lua 5.1; no GMod calls)
-- ================================================================

-- Mutate these fields in place because Model retains this table.
ACE.PointsModel = ACE.PointsModel or {
	kGun   = 7.5,            -- gun firepower scale
	kRack  = 6.0,            -- rack firepower scale
	kArmor = 0.259845,         -- armor survivability scale
	kEng   = 1.501,            -- engine power scale
	Scale  = 0.65,            -- global display scale shared by all point categories
}

local Model = ACE.PointsModel
-- Existing configurations used kGun for both weapon classes; preserve their rack scale on reload.
Model.kRack = Model.kRack or Model.kGun

local max = math.max
local min = math.min

local ROUND_COST_FLOOR = 1.0
local GUN_FLAT    = 20.0          -- empty or minimal weapons retain a nonzero price
local RACK_FLAT   = 100.0
-- 30s engagement window: a rack's sustained rate is capped at tubes/window -- it is NOT an
-- infinite-reload DPS machine. Tubes are launcher hardware (mountpoint count), not a
-- carried-round choice; keeps missiles/planes sanely priced. Also sets the gun/rack priced-rate
-- floor (1/RACK_WINDOW): no mounted delivery system prices below one round per window, closing
-- the slow-alpha and tiny-ROFLimit aliases of the same cheese.
local RACK_WINDOW = 30.0
-- At the tube/window cap, each tube uses the rack's fixed five-rpm reference scale:
-- 40% delivery value plus 60% ready payload; guidance multiplies the total.
local RACK_REFERENCE_RPS = 5.0 / 60.0
local RACK_READY_SHARE = 1.0 - 1.0 / (RACK_WINDOW * RACK_REFERENCE_RPS)
local FIRE_RATE_EXP = 0.25 -- sixteen times the cadence doubles its price multiplier
local MISSILE_LENGTH_MUL = 2.0
local EXP_MM = 1.4                -- armor thickness exponent (intensive term -- untouched)
-- Armor HP exponent. LINEAR/extensive on purpose: N props of the same total HP price
-- identically to 1 prop, so splitting armor into fragments is points-neutral. A sub-linear
-- exponent would reward that split as a pricing exploit.
local EXP_HP = 1.0

-- Assigned combat premiums; utility and anti-personnel rounds retain lower specialist prices.
local WARHEAD = {
	SM = 0.05, FLR = 0.05, CHF = 0.05, FL = 0.2,
	Refill = 1.0, HP = 1.0, HE = 1.0, HEFS = 1.1, HESH = 1.15,
	HEAT = 1.1, HEATFS = 1.25, THEAT = 1.4, THEATFS = 1.6,
	HVAP = 1.25, AP = 1.5, APHE = 1.7, APDS = 1.75, APFSDS = 2.0,
	CAP = 1.25, CHE = 1.25, CHEAT = 1.75, GLATGM = 1.75, ["GLATGM-HE"] = 1.25,
}

--- Returns the assigned warhead premium; unknown types retain the full length baseline.
-- @param round table Converted round configuration.
-- @return number Positive warhead multiplier, including specialist discounts.
function ACE.Points.WarheadMul(round)
	return WARHEAD[round.Type] or 1.0
end

-- Guidance names omitted from this table use a 1.0 multiplier.
local GUIDANCE = {
	Dumb = 0.5,
	Straight_Running = 0.6,
	Radar = 1.4,
	Semiactive = 0.8,
	Infrared = 1.2,
	Top_Attack_IR = 1.8,
	GPS = 0.7,
	GPS_TerrainAvoidant = 0.8,
	AntiRadiation = 0.6, --Cost lowered to increase viability of antiradiation missiles as a backup weapon.
	Beam_Riding = 0.8, --Beamriding is an inferior guidance method due to inability to see in 3d and wasted energy.
}

-- Total rack-price ratios against the reference gun, applied after weapon floors.
-- Unlisted guidance keeps its existing relative factor; guns/explosives are unchanged.
local RACK_GUIDANCE = {
	Dumb = 0.7, Laser = 1.1, Infrared = 2.5, Radar = 2.5, Top_Attack_IR = 3.5,
}

--- Returns the rack's guidance price ratio against the reference gun.
-- @param round table Converted round configuration.
-- @return number Guidance ratio; unspecified guidance uses parity.
function ACE.Points.RackGuidanceMul(round)
	local guidance = round and round.guidance
	return RACK_GUIDANCE[guidance] or GUIDANCE[guidance] or 1.0
end

-- Guidance multiplier for a round (1.0 for everything but guided missile ammo). Public so
-- displays can show the "x 1.5 guidance" factor instead of hiding it inside baseRoundCost.
function ACE.Points.GuidanceMul(round)
	local g = round.guidance
	if g and g ~= "" then
		return GUIDANCE[g] or 1.0
	end
	return 1.0
end

--- Computes priced shell length times the assigned warhead premium.
-- Missile projectile length carries a premium; propellant length is unchanged.
-- @param round table Converted round, with ProjLength/PropLength in centimeters and optional IsMissile flag.
-- @param unguided boolean Omit guidance when the weapon applies it to its final price.
-- @return number Intrinsic round value; inventory is not billed.
function ACE.Points.BaseRoundCost(round, unguided)
	local length = max(tonumber(round.ProjLength) or 0, 0) * (round.IsMissile and MISSILE_LENGTH_MUL or 1)
	local propellant = max(tonumber(round.PropLength) or 0, 0)
	local guidance = unguided and 1.0 or ACE.Points.GuidanceMul(round)
	return max((length + propellant) * ACE.Points.WarheadMul(round) * guidance, ROUND_COST_FLOOR)
end

--- Returns the configured round value used to rank weapon candidates.
-- @param round table Converted round configuration.
-- @return number Round value.
function ACE.Points.RoundScore(round)
	return ACE.Points.BaseRoundCost(round)
end

-- Candidate ordering is final weapon output, then per-shot score, then stable source order.
function ACE.Points.IsBetterCandidate(candidate, best)
	if not best then return true end
	if candidate.FinalScore ~= best.FinalScore then return candidate.FinalScore > best.FinalScore end
	if candidate.RoundScore ~= best.RoundScore then return candidate.RoundScore > best.RoundScore end
	return candidate.SourceIndex < best.SourceIndex
end

--- Prices magazine-aware cadence without crew reload modifiers.
-- @param baseRps number Configured rounds per second, including the wire ROFLimit.
-- @param magSize number Magazine capacity.
-- @param magReload number Magazine reload time in seconds.
-- @return number Sustained rounds per second used for points.
function ACE.Points.SustainedRps(baseRps, magSize, magReload)
	local base   = tonumber(baseRps) or 0
	local mag    = tonumber(magSize) or 0
	local magrel = tonumber(magReload) or 0

	if mag > 1 and magrel > 0 and base > 0 then
		base = mag / (mag / base + magrel)
	end
	return base
end

--- Returns the mild cadence premium relative to a five-rpm weapon.
-- @param rate number Configured rounds per second.
-- @return number Fourth-root rate multiplier, before the delivery-rate floor.
function ACE.Points.FireRateMul(rate)
	return (max(tonumber(rate) or 0, 0) / RACK_REFERENCE_RPS) ^ FIRE_RATE_EXP
end

--- Prices each gun's configured delivery rate and round value.
-- @param sustainedRps number Configured sustained rounds per second.
-- @param baseRoundCost number Total-length/warhead round value.
-- @return number Scaled firepower points, additive per gun entity.
function ACE.Points.GunCost(sustainedRps, baseRoundCost)
	local pricedRps = max(tonumber(sustainedRps) or 0, 1.0 / RACK_WINDOW)
	return max(Model.kGun
		* ACE.Points.FireRateMul(pricedRps)
		* (tonumber(baseRoundCost) or 0), GUN_FLAT) * Model.Scale
end

function ACE.Points.RackRate(reloadTime, maxMissile)
	local rt = tonumber(reloadTime) or 0
	if rt == 0 then rt = 10.0 end
	local mm = tonumber(maxMissile) or 0
	if mm == 0 then mm = 1 end
	return min(1.0 / max(rt, 0.5), mm / RACK_WINDOW)
end

--- Prices rack delivery and one base-round charge per ready tube.
-- @param rate number Sustained rounds per second.
-- @param bestScore number Selected round's round value.
-- @param baseRoundCost number Selected round's base cost.
-- @param maxMissile number Ready tube count, default/minimum 1.
-- @param guidance number Final guidance ratio; omitted retains legacy helper pricing.
-- @return number Scaled rack points.
-- @return number Scaled ready-tube points.
-- @return number Scaled total before flat minima, with the delivery-rate floor applied.
function ACE.Points.RackCostFromRate(rate, bestScore, baseRoundCost, maxMissile, guidance)
	local pricedRate = max(tonumber(rate) or 0, 1.0 / RACK_WINDOW)
	local tubes = max(tonumber(maxMissile) or 1, 1)
	if guidance then
		local score = max(tonumber(bestScore) or 0, 0)
		local scale = Model.Scale * guidance
		local deliveryShare = 1.0 - RACK_READY_SHARE
		local rateFraction = pricedRate / (tubes / RACK_WINDOW)
		local delivery = Model.kRack * deliveryShare * tubes * rateFraction ^ FIRE_RATE_EXP * score
		local ready = Model.kRack * RACK_READY_SHARE * score
		local deliveryFloor = GUN_FLAT / (RACK_WINDOW * RACK_REFERENCE_RPS)
		local readyFloor = GUN_FLAT - deliveryFloor
		local readyPoints = max(ready, readyFloor) * tubes * scale
		return max(delivery, deliveryFloor * tubes) * scale + readyPoints, readyPoints,
			(delivery + ready * tubes) * scale
	end
	local deliveryCost = max(Model.kRack * pricedRate
		* (tonumber(bestScore) or 0), RACK_FLAT)
	local readyCost = max(tonumber(baseRoundCost) or 0, 0) * max(tonumber(maxMissile) or 1, 1)
	return (deliveryCost + readyCost) * Model.Scale
end

-- Public so readouts can tell a player when the priced-rate floor changed their bill, instead
-- of leaving the window a silently duplicated magic number.
function ACE.Points.RateFloor()
	return 1.0 / RACK_WINDOW
end

--- Prices a rack from its configured reload time and ready capacity.
-- @param reloadTime number Configured reload time in seconds.
-- @param maxMissile number Ready tube count.
-- @param bestScore number Selected round's round value.
-- @param baseRoundCost number Selected round's base cost.
-- @param guidance number Final guidance ratio; omitted retains legacy helper pricing.
-- @return number Scaled rack points.
function ACE.Points.RackCost(reloadTime, maxMissile, bestScore, baseRoundCost, guidance)
	return ACE.Points.RackCostFromRate(ACE.Points.RackRate(reloadTime, maxMissile), bestScore, baseRoundCost, maxMissile, guidance)
end

-- Mounted charges use one tube-window without the rack hardware floor. Stored ammo remains free.
function ACE.Points.ChargeCost(fillerKg)
	fillerKg = tonumber(fillerKg) or 0
	if fillerKg <= 0 then return 0 end
	-- Mounted explosives have no shell dimensions; retain their existing filler-only pricing.
	local pen = 30 * fillerKg ^ (2 / 3)
	local reach = max(pen, fillerKg * (8000 / 3500))
	local value = pen * (1 + math.sqrt(fillerKg / 6)) * 0.5 * 1.5
	return 5.408 * (1 / RACK_WINDOW) * (reach / (reach + 548.5)) * max(value, ROUND_COST_FLOOR) * Model.Scale
end

--- Blends normal-incidence protection after the material's thickness curve.
-- @param armourMm number Nominal armor thickness in mm.
-- @param ke number Kinetic effectiveness.
-- @param chem number Chemical effectiveness.
-- @param curve number Optional thickness exponent, default 1.
-- @return number Blended effective thickness in mm.
function ACE.Points.EffectiveMm(armourMm, ke, chem, curve)
	return max(tonumber(armourMm) or 0, 0) ^ (tonumber(curve) or 1)
		* (0.7 * (tonumber(ke) or 1) + 0.3 * (tonumber(chem) or 1))
end

--- Prices protection and its mass efficiency relative to RHA.
-- @param effMm number Blended effective thickness in mm.
-- @param maxHealth number Undamaged prop health.
-- @param massEfficiency number Optional equal-protection mass ratio, default 1.
-- @return number Scaled armor points.
function ACE.Points.ArmorProp(effMm, maxHealth, massEfficiency)
	return Model.kArmor * 100.0
		* ((tonumber(effMm) or 0) / 50.0) ^ EXP_MM
		* ((tonumber(maxHealth) or 0) / 75.0) ^ EXP_HP
		* (tonumber(massEfficiency) or 1)
		* Model.Scale
end

--- Prices peak engine power independently of fuel type.
-- @param hp number Peak horsepower (peakkw / 0.7457).
-- @return number Scaled engine points.
function ACE.Points.EngineCost(hp)
	return Model.kEng * (tonumber(hp) or 0) * Model.Scale
end

--- Keeps required crew and their reload benefits free.
-- @return number Zero crew points.
function ACE.Points.CrewCost()
	return 0
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
		local name = ACE.GetConfigurableName(guidanceValue, "")
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

-- KE/CHEM weights, mass modifier, pricing thickness curve. Unknown materials use RHA.
-- ERA's active detonation path uses linear thickness, not its depleted-plate curve.
local MATERIAL_EFF = {
	RHA   = { 1.0,    1.0,          1.0,   1.0 },
	CHA   = { 0.98,   0.98,         1.2,   1.0 },
	Cer   = { 2.05,   2.05,         1.2,   0.99 },
	DU    = { 3.0,    3.0,          2.43,  1.06 },
	Ti    = { 1.7,    1.7,          0.61,  1.0 },
	Alum  = { 0.8325, 0.8325 / 5.0, 0.333, 0.92 },
	ERA   = { 2.5,    8.0,          2.0,   1.0 },
	Rub   = { 0.05,   3.0,          0.2,   0.93 },
	Texto = { 0.5,    1.2,          0.35,  0.94 },
}

-- Returns nil for unknown materials so display code can fall back to live material data.
function ACE.Points.MaterialEff(mat)
	local eff = MATERIAL_EFF[mat]
	if not eff then return nil end
	return eff[1], eff[2]
end

--- Resolves shared billing and preview inputs for a material.
-- @param armourMm number Nominal armor thickness in mm.
-- @param mat string Material identifier; unknown materials price as RHA.
-- @return number Blended effective thickness in mm.
-- @return number RHA mass divided by material mass at equal blended protection and area.
function ACE.Points.MaterialArmor(armourMm, mat)
	armourMm = tonumber(armourMm) or 0
	if armourMm <= 0 then return 0, 1 end

	local eff = MATERIAL_EFF[mat or "RHA"] or MATERIAL_EFF.RHA
	local effMm = ACE.Points.EffectiveMm(armourMm, eff[1], eff[2], eff[4])
	return effMm, effMm / (armourMm * eff[3])
end

--- Builds static pricing inputs without changing the configured ammunition.
-- @param bdata table Gun/crate/rack BulletData.
-- @return table Plain pricing round, or nil for invalid bullet data.
function ACE.Points.RoundFromBullet(bdata)
	if not istable(bdata) then return nil end

	local round = {
		Type        = ACE.ResolveAmmoType(nil, bdata),   -- bdata branch: bdata.Type or bdata.RoundType
		ProjLength = tonumber(bdata.ProjLength) or 0,
		PropLength = tonumber(bdata.PropLength) or 0,
		IsMissile = ACE.IsAmmoMissileType(bdata) and not ACE.IsGLATGMAmmoType(bdata.Type),
	}

	-- Guidance folds the old per-missile pricing premium into baseRoundCost. Candidates:
	-- BulletData.guidance/Guidance, else Data7 (the runtime-configured guidance object the
	-- legacy pricing read). GLATGM (gun-launched grenade ammo) opts out, as it always has.
	-- Non-missiles carry none, so guidance stays nil (1.0).
	local guid = bdata.guidance or bdata.Guidance or bdata.Data7
	if guid ~= nil and not ACE.IsGLATGMAmmoType(bdata.Type) then
		round.guidance = resolveGuidanceName(guid)
	end

	return round
end

--- Resolves priced gun cadence without loader bonuses or uncrewed penalties.
-- ROFLimit remains a pricing input and its trigger path must dirty points.
-- @param gun Entity Gun being priced.
-- @param bdata table Candidate bullet data.
-- @param crate Entity Candidate ammo crate.
-- @return number Sustained rounds per second used for points.
function ACE.Points.GunSustainedRps(gun, bdata, crate)
	if not ACE.IsEnt(gun) then return 0 end
	local base = ACE.GetGunConfiguredRps(gun, tonumber(gun.ROFLimit) or 0, bdata, crate)
	return ACE.Points.SustainedRps(base, gun.MagSize, gun.MagReload)
end

-- Mounted charge (scalable explosives / bombs family) -> scaled points. Prices the charge's
-- REAL filler mass -- self.FillerMass, kg of HE, set once at spawn from the scaled charge
-- volume -- as mounted ordnance via ACE.Points.ChargeCost. 0 for a filler-less/invalid entity.
function ACE.Points.ChargeEntCost(ent)
	if not ACE.IsEnt(ent) then return 0 end
	return ACE.Points.ChargeCost(tonumber(ent.FillerMass) or 0)
end

--- Resolves a prop's static armor pricing inputs.
-- Skips components, pods and props with no armor/health. Uses undamaged state, shared
-- with the armor-tool preview.
-- @param ent Entity Armor prop.
-- @return number Effective thickness, or nil for an excluded/unready entity.
-- @return number Undamaged health.
-- @return number Relative mass efficiency.
function ACE.Points.PropArmor(ent)
	if not ACE.IsEnt(ent) then return nil end
	if ent.ACE_PrimitiveArmorPending or ent.ACE_PrimitivePropertiesPending
		or ent.ACE_PrimitiveRestoreSavedArmor then
		return nil
	end

	local cls = ent:GetClass() or ""
	if cls:sub(1, 4) == "acf_" or cls:sub(1, 4) == "ace_" or cls:sub(1, 5) == "gmod_"
		or cls:find("pod", 1, true) then
		return nil
	end

	local acf = ACE.GetEntityState(ent)
	if not istable(acf) then return nil end

	local armourMm = tonumber(acf.MaxArmour) or 0
	local hp       = tonumber(acf.MaxHealth) or 0
	if armourMm <= 0 or hp <= 0 then return nil end

	local effMm, massEfficiency = ACE.Points.MaterialArmor(armourMm, acf.Material or ent.ACE_Material)
	return effMm, hp, massEfficiency
end
