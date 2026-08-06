-- Shared, data-only behavior vocabulary for armor materials.
-- This metadata layer deliberately does not alter legacy armor coefficients or resolvers.
AddCSLuaFile()

ACE = ACE or {}
ACE.ArmorBehaviorModules = {
	homogeneous_metal = {
		label = "Homogeneous metal",
		description = "Single-material plate with conventional ductile penetration behavior.",
		fields = { "densityKgM3", "hardnessHB", "fractureToughnessMPaSqrtM", "ductility" }
	},
	lightweight_metal = {
		label = "Lightweight metal",
		description = "Weight-saving metal whose protection depends strongly on alloy and thickness.",
		fields = { "densityKgM3", "hardnessHB", "ductility", "overmatchRatio" }
	},
	dense_metal = {
		label = "Dense metal",
		description = "High-density armor layer with increased mass and protection per thickness.",
		fields = { "densityKgM3", "hardnessHB", "fractureToughnessMPaSqrtM" }
	},
	brittle_strike_face = {
		label = "Brittle strike face",
		description = "High initial resistance with localized fracture and reduced multi-hit tolerance.",
		fields = { "kineticRHAe", "fractureToughnessMPaSqrtM", "penetrationDamageMultiplier", "multiHitRetention" }
	},
	composite_backing = {
		label = "Composite backing",
		description = "Fiber or resin backing that absorbs residual energy and limits fragments.",
		fields = { "densityKgM3", "chemicalRHAe", "spallCapture", "residualDamageMultiplier" }
	},
	elastomer_liner = {
		label = "Elastomer liner",
		description = "Deformable layer focused on shock, fragment, and spall control.",
		fields = { "densityKgM3", "shockAttenuation", "spallCapture" }
	},
	reactive_tile = {
		label = "Reactive tile",
		description = "Expendable explosive tile that disrupts an incoming projectile.",
		fields = { "tileMassKgM2", "chemicalRHAe", "kineticRHAe", "singleUse" }
	},
	spall_response = {
		label = "Spall response",
		description = "Controls fragment production and residual spall energy after impact.",
		fields = { "spallProduction", "spallResistance", "spallCapture" }
	},
	shock_barrier = {
		label = "Shock barrier",
		description = "Limits blast or shock continuation through layered armor.",
		fields = { "shockAttenuation" }
	},
	failure_state = {
		label = "Impact state",
		description = "Supports fractured, depleted, or otherwise degraded post-hit behavior.",
		fields = { "multiHitRetention", "singleUse", "degradation" }
	}
}

-- These are physical/test-facing inputs, not replacements for ACE's legacy coefficients.
-- RHAe values should come from a stated test threat or a deliberately chosen game balance
-- baseline; hardness and density alone do not predict ballistic equivalence.
ACE.ArmorSpecFields = {
	densityKgM3 = { label = "Density", unit = "kg/m³" },
	hardnessHB = { label = "Hardness", unit = "HB" },
	fractureToughnessMPaSqrtM = { label = "Fracture toughness", unit = "MPa√m" },
	ductility = { label = "Ductility", unit = "0–1" },
	kineticRHAe = { label = "Kinetic RHAe", unit = "× RHA" },
	chemicalRHAe = { label = "Chemical RHAe", unit = "× RHA" },
	heRHAe = { label = "HE RHAe", unit = "× RHA" },
	kineticResilience = { label = "Kinetic resilience", unit = "×" },
	chemicalResilience = { label = "Chemical resilience", unit = "×" },
	heResilience = { label = "HE resilience", unit = "×" },
	curve = { label = "Thickness curve", unit = "power" },
	overmatchRatio = { label = "Overmatch ratio", unit = "caliber / thickness" },
	penetrationDamageMultiplier = { label = "Penetration damage", unit = "×" },
	multiHitRetention = { label = "Multi-hit retention", unit = "0–1" },
	spallProduction = { label = "Spall production", unit = "×" },
	spallResistance = { label = "Spall resistance", unit = "×" },
	spallCapture = { label = "Spall capture", unit = "0–1" },
	shockAttenuation = { label = "Shock attenuation", unit = "0–1" },
	residualDamageMultiplier = { label = "Residual damage", unit = "×" },
	tileMassKgM2 = { label = "Tile mass", unit = "kg/m²" },
	singleUse = { label = "Single-use", unit = "boolean" },
	degradation = { label = "Impact degradation", unit = "0–1" }
}

ACE.ArmorResolvers = ACE.ArmorResolvers or {}

local function CopyValues(source)
	local copy = {}
	for key, value in pairs(source or {}) do copy[key] = value end
	return copy
end

local function HasBehavior(material, behaviorId)
	for _, id in ipairs(material.BehaviorModules or {}) do
		if id == behaviorId then return true end
	end

	return false
end

--- Validates optional physical/test inputs before registering a material.
-- @param spec table Physical/test specification.
-- @return boolean valid Whether all supplied values are usable.
-- @return table errors Human-readable validation errors.
function ACE.ValidateArmorSpec(spec)
	local errors = {}
	local positive = { "densityKgM3", "kineticRHAe", "chemicalRHAe", "heRHAe", "curve", "overmatchRatio" }

	for _, field in ipairs(positive) do
		if spec[field] ~= nil and (type(spec[field]) ~= "number" or spec[field] <= 0) then
			errors[#errors + 1] = field .. " must be a positive number"
		end
	end

	for _, field in ipairs({ "ductility", "multiHitRetention", "spallCapture", "shockAttenuation" }) do
		if spec[field] ~= nil and (type(spec[field]) ~= "number" or spec[field] < 0 or spec[field] > 1) then
			errors[#errors + 1] = field .. " must be between 0 and 1"
		end
	end

	return #errors == 0, errors
end

ACE.ArmorBehaviorSets = {
	RHA = { "homogeneous_metal", "spall_response" },
	CHA = { "homogeneous_metal", "spall_response" },
	Cer = { "brittle_strike_face", "composite_backing", "spall_response", "failure_state" },
	DU = { "dense_metal", "homogeneous_metal", "spall_response" },
	Ti = { "lightweight_metal", "homogeneous_metal", "spall_response" },
	Alum = { "lightweight_metal", "homogeneous_metal", "spall_response" },
	ERA = { "reactive_tile", "shock_barrier", "spall_response", "failure_state" },
	Rub = { "elastomer_liner", "spall_response", "shock_barrier" },
	Texto = { "composite_backing", "spall_response", "failure_state" }
}

--- Attaches descriptive armor behavior metadata to loaded materials.
-- @param materials table Loaded ACE armor material definitions.
local function AttachBehaviorModules(material, behaviorIds, behaviorConfig)
	material.BehaviorModules = {}
	material.BehaviorConfig = CopyValues(behaviorConfig)

	for index, behavior in ipairs(behaviorIds or {}) do
		local behaviorId = type(behavior) == "table" and behavior.id or behavior
		if ACE.ArmorBehaviorModules[behaviorId] then
			material.BehaviorModules[#material.BehaviorModules + 1] = behaviorId
			if type(behavior) == "table" and behavior.parameters then
				material.BehaviorConfig[behaviorId] = CopyValues(behavior.parameters)
			end
		end
	end

	material.BehaviorLabels = {}

	for _, behaviorId in ipairs(material.BehaviorModules) do
		local behavior = ACE.ArmorBehaviorModules[behaviorId]
		material.BehaviorLabels[#material.BehaviorLabels + 1] = behavior.label
	end
end

--- Applies a real-world-oriented spec and reusable behaviors to a material.
-- @param material table Material definition to configure.
-- @param definition table Spec, behavior, legacy, and resolver options.
-- @return table material The configured material definition.
function ACE.ConfigureArmorMaterial(material, definition)
	definition = definition or {}
	material.ArmorSpec = CopyValues(definition.spec or material.ArmorSpec)
	local valid, errors = ACE.ValidateArmorSpec(material.ArmorSpec)
	assert(valid, "invalid armor spec: " .. table.concat(errors, "; "))

	local legacy = definition.legacy or {}
	for key, value in pairs(legacy) do
		if material[key] == nil then material[key] = value end
	end

	local spec = material.ArmorSpec
	if spec.densityKgM3 and material.massMod == nil then material.massMod = spec.densityKgM3 / 7850 end
	if spec.kineticRHAe and material.effectiveness == nil then material.effectiveness = spec.kineticRHAe end
	if spec.chemicalRHAe and material.HEATeffectiveness == nil then material.HEATeffectiveness = spec.chemicalRHAe end
	if spec.heRHAe and material.HEeffectiveness == nil then material.HEeffectiveness = spec.heRHAe end
	if spec.curve and material.curve == nil then material.curve = spec.curve end
	if spec.spallResistance and material.spallresist == nil then material.spallresist = spec.spallResistance end
	if spec.spallProduction and material.spallmult == nil then material.spallmult = spec.spallProduction end
	if spec.shockAttenuation and material.Stopshock == nil then material.Stopshock = spec.shockAttenuation <= 0 end

	AttachBehaviorModules(material, definition.behaviors or material.BehaviorModules, definition.behaviorConfig or material.BehaviorConfig)

	if definition.resolver == "modular" then
		material.ArmorResolver = "modular"
		if SERVER then
			material.ArmorResolution = function(Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
				return ACE.ArmorResolvers.Modular(material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
			end
		end
	end

	return material
end

--- Defines and registers a declarative armor material.
-- @param definition table Material identity, spec, behavior, and legacy options.
-- @return table material The registered material definition.
function ACE.DefineArmorMaterial(definition)
	assert(type(definition) == "table", "armor material definition must be a table")
	assert(definition.id, "armor material definition requires id")

	local material = CopyValues(definition.material)
	material.id = definition.id
	material.name = definition.name or material.name or definition.id
	material.sname = definition.sname or material.sname or definition.id
	material.desc = definition.desc or material.desc or ""
	material.year = definition.year or material.year

	ACE.ConfigureArmorMaterial(material, definition)
	ACE.ArmorTypes[material.id] = material

	return material
end

if SERVER then
	local function ThreatValues(material, Type)
		local spec = material.ArmorSpec or {}
		local threat = "kinetic"

		if Type == "HEAT" or Type == "THEAT" or Type == "HEATFS" or Type == "THEATFS" then
			threat = "chemical"
		elseif Type == "HE" or Type == "HESH" then
			threat = "blast"
		end

		local effectiveness = spec.kineticRHAe or material.effectiveness or 1
		local resilience = spec.kineticResilience or material.resiliance or 1
		if threat == "chemical" then
			effectiveness = spec.chemicalRHAe or material.HEATeffectiveness or effectiveness
			resilience = spec.chemicalResilience or material.HEATresiliance or resilience
		elseif threat == "blast" then
			effectiveness = spec.heRHAe or material.HEeffectiveness or effectiveness
			resilience = spec.heResilience or material.HEresiliance or resilience
		end

		return threat, effectiveness, resilience
	end

	--- Resolves a declarative armor material using test-facing RHAe and failure inputs.
	-- Existing ACE materials retain their bespoke ArmorResolution functions; this resolver is
	-- opt-in through `resolver = "modular"` in ACE.DefineArmorMaterial.
	function ACE.ArmorResolvers.Modular(material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		local spec = material.ArmorSpec or {}
		local _, effectiveness, resilience = ThreatValues(material, Type)
		local curve = spec.curve or material.curve or 1
		local overmatchRatio = spec.overmatchRatio or 7
		local damageMultiplier = spec.penetrationDamageMultiplier or 1
		local behaviorConfig = material.BehaviorConfig or {}

		if HasBehavior(material, "brittle_strike_face") then
			local config = behaviorConfig.brittle_strike_face or {}
			damageMultiplier = config.penetrationDamageMultiplier or damageMultiplier
		end

		if HasBehavior(material, "composite_backing") then
			local config = behaviorConfig.composite_backing or {}
			damageMultiplier = damageMultiplier * (config.residualDamageMultiplier or 1)
		end

		if Type == "HE" or Type == "HESH" then
			local config = behaviorConfig.shock_barrier or {}
			damageMultiplier = damageMultiplier * (config.shockAttenuation or 1)
		end

		local ductility = math.Clamp(spec.ductility or 0, 0, 1)
		local ductilityMultiplier = 2 / (2 + ductility * 1.5)
		local effectiveArmor = armor ^ curve
		local effectiveLosArmor = losArmor ^ curve
		local breachProbability = math.Clamp((caliber / effectiveArmor / effectiveness - 1.3) / (overmatchRatio - 1.3), 0, 1)
		local penetrationProbability = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / effectiveLosArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997

		if breachProbability > math.random() and maxPenetration > effectiveArmor then
			return {
				Damage = FrArea * resilience * damageMult * ductilityMultiplier * damageMultiplier,
				Overkill = maxPenetration - effectiveArmor,
				Loss = effectiveArmor / maxPenetration
			}
		end

		if penetrationProbability > math.random() then
			local penetration = math.min(maxPenetration, effectiveLosArmor * effectiveness)
			return {
				Damage = (penetration / losArmorHealth / effectiveness) ^ 2 * FrArea * resilience * damageMult * ductilityMultiplier * damageMultiplier,
				Overkill = maxPenetration - penetration,
				Loss = penetration / maxPenetration
			}
		end

		local penetration = math.min(maxPenetration, effectiveLosArmor * effectiveness)
		return {
			Damage = (penetration / losArmorHealth / effectiveness) * FrArea * resilience * damageMult * ductilityMultiplier * damageMultiplier,
			Overkill = 0,
			Loss = 1
		}
	end
end

function ACE.ApplyArmorBehaviorModules(materials)
	for materialId, behaviorIds in pairs(ACE.ArmorBehaviorSets) do
		local material = materials[materialId]
		if material then AttachBehaviorModules(material, behaviorIds, material.BehaviorConfig) end
	end

	for materialId, material in pairs(materials) do
		if material.ArmorSpec or material.BehaviorModules then
			ACE.ConfigureArmorMaterial(material, {
				spec = material.ArmorSpec,
				behaviors = material.BehaviorModules,
				behaviorConfig = material.BehaviorConfig
			})
		end
	end
end

--- Returns the behavior module IDs attached to an armor material.
-- @param material table|nil ACE armor material definition.
-- @return table modules Behavior module IDs, or an empty table.
function ACE.GetArmorBehaviorModules(material)
	return material and material.BehaviorModules or {}
end
