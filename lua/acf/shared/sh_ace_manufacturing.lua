--[[-----------------------------------------------------------------------------
	ACE Manufacturing Cost -- real-dollar build cost model

	The cost constants below are anchored to real-world component prices (see the allocation
	targets). Retune them together, never one number in isolation.

	SEPARATE from contraption points (combat power): manufacturing answers "what would
	this cost to BUILD", points answer "how hard does it fight". AMMO IS FREE for points
	but very much not free to manufacture; a missile's seeker dominates its manufacturing
	cost while its combat value cares only about the kill-probability multiplier.

	Real-life allocation targets for a modern western MBT (~$6M flyaway):
		armor/structure ~30% : powerpack ~18% : armament ~12% : electronics/FCS ~30% : crew ~5%
	Categories: Armor / Powerpack / Armament / Ammo / Electronics / Crew.

	SECTION 1 -- PURE MODEL. Plain Lua 5.1 (only math/string/table + base coercion).
	No GMod/ACE global is CALLED at load time or inside these functions; they take
	plain values/tables. This section must load and run under a vanilla Lua interpreter
	(no GMod) so the cost model can be tested outside the game.

	SECTION 2 -- ADAPTERS. GLua: entity in -> plain tables/numbers out, then it calls
	the pure functions. Every GMod/ACE call lives INSIDE an adapter body (never at file
	scope), so the whole file still loads cleanly under vanilla Lua.
-------------------------------------------------------------------------------]]

ACE = ACE or {}

-- ================================================================
--  SECTION 1 -- PURE MODEL  (vanilla Lua 5.1; no GMod calls)
-- ================================================================

-- THE manufacturing constant table -- all tunables live here.
-- Retune fields IN PLACE so the pure upvalue below keeps pointing at the live table.
ACE.ManuCost = ACE.ManuCost or {
	-- armor: $ per TON of prop mass, by armor material (composite/exotic >> steel)
	armor_per_ton = { RHA = 14000.0, CHA = 16000.0, Alum = 20000.0, Ti = 90000.0,
	                  Cer = 120000.0, DU = 180000.0, ERA = 60000.0, Rub = 5000.0,
	                  Texto = 25000.0 },
	-- engines: $ per hp by fuel/type (turbines/multifuel premium)
	engine_per_hp = { Petrol = 250.0, Diesel = 350.0, Multifuel = 500.0, Electric = 400.0 },
	-- guns: $ = gun_cal_sq * caliber_mm^2 * class factor (feed-system complexity; utility
	-- launchers are stamped tubes, rotaries are the expensive end)
	gun_cal_sq = 48.0,
	gun_class_mul = { MG = 1.5, HMG = 2.0, AC = 4.0, RAC = 8.0, SA = 2.0,
	                  GL = 0.5, SL = 0.15, MO = 0.1, FLR = 0.15 },
	rack_flat = 15000.0,                     -- launcher rail/tube hardware per tube
	-- ammo: $ per KG of round mass (Proj+Prop), by damage family
	round_per_kg = { APFSDS = 450.0, APDS = 350.0, HEAT = 250.0, APHE = 120.0,
	                 AP = 80.0, HVAP = 200.0, HE = 100.0, HESH = 120.0,
	                 HP = 60.0, SM = 40.0, Refill = 0.0 },
	-- missiles: body $/kg + seeker cost by guidance (seekers dominate real prices)
	missile_body_per_kg = 300.0,
	seeker = { Dumb = 0.0, Straight_Running = 10000.0, Wire = 20000.0, Laser = 60000.0,
	           Beam_Riding = 50000.0, Infrared = 100000.0, Top_Attack_IR = 170000.0,
	           Radar = 500000.0, Semiactive = 250000.0, AntiRadiation = 300000.0,
	           GPS = 25000.0, GPS_TerrainAvoidant = 40000.0, Command = 30000.0 },
	-- electronics: reuse the existing acepoints tier ladder as relative tiers
	electronics_per_tier = 2000.0,           -- search radar 600 -> $1.2M, tracking 280 -> $560k
	crew_seat = 20000.0,
	refill_crate = 50000.0,
}

local M = ACE.ManuCost

-- round type id -> manufacturing family (same families as the points model's type map).
local TYPE_FAMILY = {
	AP = "AP", APHE = "APHE", APDS = "APDS", APFSDS = "APFSDS", HVAP = "HVAP",
	HP = "HP", CAP = "AP",
	HEAT = "HEAT", HEATFS = "HEAT", THEAT = "HEAT", THEATFS = "HEAT", CHEAT = "HEAT",
	GLATGM = "HEAT", ["GLATGM-HE"] = "HE",
	HE = "HE", HEFS = "HE", CHE = "HE", CHF = "HE", HESH = "HESH",
	SM = "SM", FLR = "SM", FL = "SM", Refill = "Refill",
}

-- Manufacturing $ for ONE round. Missiles (guidance present) = body $/kg + seeker cost;
-- shells = round mass (Proj+Prop) x its family $/kg rate. Refill rounds are free here.
-- round = { Type, ProjMass, PropMass, guidance }.
function ACE_Manu_RoundCost(round)
	local t = round.Type
	if not t or t == "" then t = "AP" end
	local fam = TYPE_FAMILY[t] or "AP"
	if fam == "Refill" then return 0.0 end

	local mass = (tonumber(round.ProjMass) or 0.0) + (tonumber(round.PropMass) or 0.0)

	local guid = round.guidance
	if guid and guid ~= "" then                       -- missile round: seeker + body
		local seeker = M.seeker[guid] or 0.0
		return mass * M.missile_body_per_kg + seeker
	end

	return mass * (M.round_per_kg[fam] or 80.0)
end

-- Gun manufacturing $ = gun_cal_sq * caliber_mm^2 * class factor. caliberMm is millimetres
-- (adapter passes Caliber_cm * 10). Unknown class -> factor 1.0.
function ACE_Manu_GunCost(caliberMm, gunClass)
	local calMm = tonumber(caliberMm) or 0.0
	local mul = M.gun_class_mul[gunClass] or 1.0
	return M.gun_cal_sq * calMm ^ 2 * mul
end

-- Rack manufacturing $ = tube count x flat rail/tube hardware. 0/nil tubes default to 1.
function ACE_Manu_RackCost(maxMissile)
	local mm = tonumber(maxMissile) or 0
	if mm == 0 then mm = 1 end
	return mm * M.rack_flat
end

-- Armor manufacturing $ = mass (tonnes) x $/ton for the material. Unknown material -> RHA rate.
function ACE_Manu_ArmorCost(massKg, material)
	local mass = tonumber(massKg) or 0.0
	return mass / 1000.0 * (M.armor_per_ton[material] or 14000.0)
end

-- Engine manufacturing $ = peak hp x $/hp for the fuel type. hp is peak power (peakkw/0.7457).
-- nil fuel -> Petrol (250); a known-name-but-unmapped fuel -> 350.
function ACE_Manu_EngineCost(hp, fuelType)
	return (tonumber(hp) or 0.0) * (M.engine_per_hp[fuelType or "Petrol"] or 350.0)
end

-- Electronics manufacturing $ = acepoints tier x $/tier.
function ACE_Manu_ElectronicsCost(tierPoints)
	return (tonumber(tierPoints) or 0.0) * M.electronics_per_tier
end

-- Crew seat manufacturing $ (flat).
function ACE_Manu_CrewCost()
	return M.crew_seat
end

-- Refill/supply crate manufacturing $ (flat -- NOT per round).
function ACE_Manu_RefillCost()
	return M.refill_crate
end

-- ================================================================
--  SECTION 2 -- ADAPTERS  (GLua; entity -> plain values -> pure funcs)
-- ================================================================

-- Ammo crate -> Ammo $. Refill crates take the flat refill cost; every other crate is
-- round_cost x Capacity. Type/guidance come from the EXISTING public round adapter
-- (ACE_Points_RoundFromBullet resolves missile guidance from guidance/Guidance/Data7);
-- masses come straight off BulletData. Returns 0 for a crate with no BulletData.
local function manuCrateCost(ent)
	local bdata = ent.BulletData
	if not istable(bdata) then return 0 end

	local round = ACE_Points_RoundFromBullet(bdata)
	if not round then return 0 end

	if round.Type == "Refill" then
		return ACE_Manu_RefillCost()
	end

	round.ProjMass = tonumber(bdata.ProjMass)
	round.PropMass = tonumber(bdata.PropMass)
	return ACE_Manu_RoundCost(round) * (tonumber(ent.Capacity) or 0)
end

-- Manufacturing $ for ONE entity, plus its category (one of Armor/Powerpack/Armament/Ammo/
-- Electronics/Crew), routed by entity class.
-- Returns 0, nil for unpriceable ents. Server-realm inputs (physics mass, BulletData) -- called
-- from the armor tool's server-side popup path.
function ACE_Manu_EntCost(ent)
	if not ACE_IsEnt(ent) then return 0, nil end

	local cls = ent:GetClass() or ""

	if cls == "acf_engine" then
		return ACE_Manu_EngineCost((tonumber(ent.peakkw) or 0) / 0.7457, ent.FuelType), "Powerpack"
	elseif cls == "acf_gun" then
		return ACE_Manu_GunCost((tonumber(ent.Caliber) or 0) * 10, ent.Class), "Armament"
	elseif cls == "acf_rack" then
		return ACE_Manu_RackCost(ent.MaxMissile), "Armament"
	elseif cls == "acf_ammo" then
		return manuCrateCost(ent), "Ammo"
	elseif cls == "ace_explosive" or cls == "ace_explosive_prebuilt"
		or cls == "ace_bomb_satchel" or cls == "ace_bomb_aerial"
		or cls == "ace_bomb_barrel" then
		-- Cast-explosive charge: filler mass x the HE ammo $/kg rate (it is bulk explosive fill).
		return (tonumber(ent.FillerMass) or 0) * (M.round_per_kg.HE or 100.0), "Ammo"
	elseif cls:find("crewseat", 1, true) then
		return ACE_Manu_CrewCost(), "Crew"
	end

	-- Armor prop: same class-skip as ACE_Points_PropArmor (skip acf_/ace_/gmod_/pod). Priced
	-- by physics mass x the prop's armor-material $/ton.
	if cls:sub(1, 4) ~= "acf_" and cls:sub(1, 4) ~= "ace_" and cls:sub(1, 5) ~= "gmod_"
		and not cls:find("pod", 1, true) then
		local acf = ent.ACF
		if istable(acf) and acf.Armour then
			local phys = ent:GetPhysicsObject()
			local mass = (IsValid(phys) and phys:GetMass()) or 0
			return ACE_Manu_ArmorCost(mass, acf.Material or ent.ACF_Material), "Armor"
		end
		return 0, nil
	end

	-- Any other ACF/ACE component carrying an ACEPoints tier prices as electronics.
	local tier = tonumber(ent.ACEPoints) or 0
	if tier > 0 then
		return ACE_Manu_ElectronicsCost(tier), "Electronics"
	end

	return 0, nil
end

-- Manufacturing $ for a whole contraption: sums ACE_Manu_EntCost over an entity list into the
-- six categories + Total. conEnts is a caller-supplied list (e.g. ACE_GetContraptionEntities).
function ACE_Manu_ContraptionCost(conEnts)
	local out = { Armor = 0, Powerpack = 0, Armament = 0, Ammo = 0, Electronics = 0, Crew = 0, Total = 0 }

	if istable(conEnts) then
		for _, ent in ipairs(conEnts) do
			local cost, cat = ACE_Manu_EntCost(ent)
			if cat and cost and cost > 0 then
				out[cat] = (out[cat] or 0) + cost
			end
		end
	end

	out.Total = out.Armor + out.Powerpack + out.Armament + out.Ammo + out.Electronics + out.Crew
	return out
end
