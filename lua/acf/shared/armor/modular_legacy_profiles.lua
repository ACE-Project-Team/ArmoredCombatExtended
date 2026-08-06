-- Declarative armor profiles for the former built-in materials.
-- The legacy coefficient names are intentionally retained in `legacy` because they are
-- consumed by the armor tool, points model, Starfall, and E2 compatibility APIs.

local function Profile(id, name, sname, desc, year, legacy, behaviors, spec, resolverConfig)
	return ACE.DefineArmorMaterial({
		id = id,
		name = name,
		sname = sname,
		desc = desc,
		year = year,
		legacy = legacy,
		behaviors = behaviors,
		spec = spec,
		resolverConfig = resolverConfig,
		resolver = "modular"
	})
end

local function CommonSpec(legacy)
	return {
		densityKgM3 = legacy.massMod * 7850,
		kineticRHAe = legacy.effectiveness,
		chemicalRHAe = legacy.HEATeffectiveness or legacy.effectiveness,
		heRHAe = legacy.HEeffectiveness or legacy.effectiveness,
		kineticResilience = legacy.resiliance,
		chemicalResilience = legacy.HEATresiliance or legacy.resiliance,
		heResilience = legacy.HEresiliance or legacy.resiliance,
		curve = legacy.curve,
		overmatchRatio = 7,
		spallProduction = legacy.spallmult,
		spallResistance = legacy.spallresist,
		shockTransmission = legacy.Stopshock and 0 or 1
	}
end

local function CommonResolverConfig(legacy)
	return {
		legacyMode = "common",
		ductilityFactor = 1.25,
		ductilityBase = 2,
		ductilityScale = 1.5,
		breachCaliberMultiplier = 1
	}
end

local RHA = {
	massMod = 1, curve = 1, effectiveness = 1, resiliance = 1,
	spallresist = 1.12, spallmult = 1, ArmorMul = 1, NormMult = 1
}

local CHA = {
	massMod = 1.2, curve = 1, effectiveness = 0.98, resiliance = 0.4,
	spallresist = 1.025, spallmult = 2, ArmorMul = 1, NormMult = 0.8
}

local Cer = {
	massMod = 1.2, curve = 0.99, effectiveness = 2.05, resiliance = 15,
	spallresist = 1, spallmult = 3.5, ArmorMul = 1.8, NormMult = 1.5
}

local DU = {
	massMod = 2.43, curve = 1.06, effectiveness = 3, resiliance = 0.9,
	spallresist = 1, spallmult = 3, ArmorMul = 1, NormMult = 1
}

local Ti = {
	massMod = 0.61, curve = 1, effectiveness = 1.7, resiliance = 0.75,
	spallresist = 1, spallmult = 0.7, ArmorMul = 1, NormMult = 1
}

local Alum = {
	massMod = 0.333, curve = 0.92, effectiveness = 0.8325, resiliance = 1.1,
	HEATMul = 5, spallresist = 1, spallmult = 1.2, ArmorMul = 0.334, NormMult = 0.7
}

local ERA = {
	massMod = 2, curve = 0.95, effectiveness = 2.5, HEATeffectiveness = 8,
	resiliance = 1, HEATresiliance = 1, NCurve = 1, Neffectiveness = 0.25,
	Nresiliance = 1, APSensorFactor = 4, HEATSensorFactor = 16,
	spallresist = 1, spallmult = 0, ArmorMul = 1, NormMult = 1, Stopshock = true,
	IsExplosive = true,
	HEATList = { HEAT = true, THEAT = true, HEATFS = true, THEATFS = true },
	HEList = { HE = true, HESH = true, Frag = true }
}

local Rub = {
	massMod = 0.2, curve = 0.93, specialeffect = 20, effectiveness = 0.05,
	resiliance = 0.7, Catchresiliance = 1.25, HEATeffectiveness = 3,
	HEATresiliance = 2, HEresiliance = 6, spallresist = 0.15,
	spallmult = 0.01, ArmorMul = 0.05, NormMult = 0.05, Stopshock = true
}

local Texto = {
	massMod = 0.35, curve = 0.94, effectiveness = 0.5, HEATeffectiveness = 1.2,
	HEeffectiveness = 0.9, resiliance = 2, HEATresiliance = 0.5, HEresiliance = 0.75,
	spallresist = 1, spallmult = 0.7, ArmorMul = 0.23, NormMult = 0.5
}

Profile("RHA", "Rolled homogeneous Armor", "RHA", "Simple, generic, but trusty steel. The standard armor everything else is compared to.", 1900, RHA, { "homogeneous_metal", "spall_response" }, CommonSpec(RHA), CommonResolverConfig(RHA))
local CHAConfig = CommonResolverConfig(CHA)
CHAConfig.breachDuctility = false
Profile("CHA", "Cast homogeneous Armor", "Cast", "Despite of being heavier than RHA, Cast steel material provides more resiliance against damage than its rolled counterpart. Highly vulnerable to spalling.", 1930, CHA, { "homogeneous_metal", "spall_response" }, CommonSpec(CHA), CHAConfig)
Profile("Cer", "Ceramic", "Ceramic", "Ceramic is usually used as a material to ensure shells do not penetrate due to its high penetration resistance. Due to its frailty it is usually only used as a backing and is not meant to take the brunt of damage. Do not let it get penetrated or it will shatter.", 1955, Cer, { "brittle_strike_face", "composite_backing", "spall_response", "failure_state" }, CommonSpec(Cer), { legacyMode = "ceramic", impactHook = "ceramic_shatter", ductilityFactor = 1.25, ductilityBase = 4, ductilityScale = 1.5 })
local DUConfig = CommonResolverConfig(DU)
DUConfig.impactHook = "du_secondary_blast"
DUConfig.triggerOnPenetration = true
Profile("DU", "Depleted Uranium", "DU", "Heavy yet extremely effective armor. Though costly, a slab of this can stop just about anything.\n Has some nasty secondary effects when penetrated. More effective at higher thicknesses.", 1970, DU, { "dense_metal", "homogeneous_metal", "spall_response" }, CommonSpec(DU), DUConfig)
Profile("Ti", "Titanium", "Titanium", "Lightweight and super resiliant. But E X P E N S I V E. 60% Lighter than RHA for a given thickness.\nUnlike aluminum works at high thicknesses but for a price.", 1950, Ti, { "lightweight_metal", "homogeneous_metal", "spall_response" }, CommonSpec(Ti), CommonResolverConfig(Ti))
Profile("Alum", "Aluminum", "Aluminum", "Aluminum is normally used by AFVs or light constructions, as it provides significantly more protection for a given weight. It is more costly and prone to spalling though.", 1955, Alum, { "lightweight_metal", "homogeneous_metal", "spall_response" }, CommonSpec(Alum), CommonResolverConfig(Alum))
Profile("ERA", "Explosive Reactive Armor", "ERA", "An explosive composite sandwiched between 2 plates. When penetrated the plate detonates damaging or even destroying the incoming shell degrading its performance. Explosive rounds can make short work of this material. This material is heavy compared to RHA and unlike other materials, will damage anything near the detonation.", 1955, ERA, { "reactive_tile", "shock_barrier", "spall_response", "failure_state" }, CommonSpec(ERA), { legacyMode = "era", impactHook = "era_detonation", ductilityFactor = 1.25, ductilityBase = 2, ductilityScale = 1.5 })
Profile("Rub", "Rubber", "Rubber", "Another material that while useless against kinetic rounds, excels at stopping shaped charges and spall", 1955, Rub, { "elastomer_liner", "spall_response", "shock_barrier" }, CommonSpec(Rub), { legacyMode = "rubber", ductilityFactor = 1.25, ductilityBase = 2, ductilityScale = 1.5 })
Profile("Texto", "Textolite", "Textolite", "Fiberglass based material, this material provides decent protection agaisnt both chemical especially and kinetic rounds, while taking reduced damage from explosions.", 1955, Texto, { "composite_backing", "spall_response", "failure_state" }, CommonSpec(Texto), { legacyMode = "textolite", ductilityFactor = 1.25, ductilityBase = 2, ductilityScale = 1.5 })

ACE.ERABoomPerTick = ACE.ERABoomPerTick or 0
