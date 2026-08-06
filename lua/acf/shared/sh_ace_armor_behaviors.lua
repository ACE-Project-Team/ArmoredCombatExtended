-- Shared behavior vocabulary and opt-in resolver for armor materials.
-- Armor definitions are declarative; legacy coefficients are retained as compatibility inputs.
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
		fields = { "densityKgM3", "shockTransmission", "spallCapture" }
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
		fields = { "shockTransmission" }
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
	shockTransmission = { label = "Shock transmission", unit = "0–1" },
	residualDamageMultiplier = { label = "Residual damage", unit = "×" },
	tileMassKgM2 = { label = "Tile mass", unit = "kg/m²" },
	singleUse = { label = "Single-use", unit = "boolean" },
	degradation = { label = "Impact degradation", unit = "0–1" }
}

ACE.ArmorResolvers = ACE.ArmorResolvers or {}

local CopyValues
CopyValues = function(source)
	local copy = {}
	for key, value in pairs(source or {}) do
		copy[key] = type(value) == "table" and CopyValues(value) or value
	end
	return copy
end

local function HasBehavior(material, behaviorId)
	for _, id in ipairs(material.BehaviorModules or {}) do
		if id == behaviorId then return true end
	end

	return false
end

local function IsFiniteNumber(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function ValidateLegacyFields(material)
	for _, field in ipairs({ "massMod", "curve", "effectiveness", "resiliance", "HEATeffectiveness", "HEATresiliance", "HEeffectiveness", "HEresiliance", "spallresist", "ArmorMul", "NormMult" }) do
		if material[field] ~= nil then assert(IsFiniteNumber(material[field]) and material[field] > 0, field .. " must be a positive number") end
	end
	if material.spallmult ~= nil then assert(IsFiniteNumber(material.spallmult) and material.spallmult >= 0, "spallmult must be a non-negative number") end
end

local function ValidateResolverConfig(config)
	local allowed = {
		legacyMode = true,
		ductilityFactor = true,
		ductilityBase = true,
		ductilityScale = true,
		breachCaliberMultiplier = true,
		impactHook = true,
		triggerOnPenetration = true,
		threats = true,
		defaultThreat = true
	}
	local modes = { common = true, ceramic = true, rubber = true, textolite = true, era = true }
	local hooks = { du_secondary_blast = true, era_detonation = true }

	for key in pairs(config or {}) do assert(allowed[key], "unknown armor resolver configuration: " .. tostring(key)) end
	if config.legacyMode ~= nil then assert(modes[config.legacyMode], "unknown armor resolver mode: " .. tostring(config.legacyMode)) end
	for _, key in ipairs({ "ductilityFactor", "ductilityBase", "ductilityScale", "breachCaliberMultiplier" }) do
		if config[key] ~= nil then assert(IsFiniteNumber(config[key]) and config[key] > 0, key .. " must be a positive number") end
	end
	if config.impactHook ~= nil then assert(hooks[config.impactHook], "unknown armor impact hook: " .. tostring(config.impactHook)) end
	if config.triggerOnPenetration ~= nil then assert(type(config.triggerOnPenetration) == "boolean", "triggerOnPenetration must be boolean") end
	if config.threats ~= nil then assert(type(config.threats) == "table", "threats must be a table") end
	if config.defaultThreat ~= nil then assert(type(config.defaultThreat) == "table", "defaultThreat must be a table") end
end

--- Validates optional physical/test inputs before registering a material.
-- @param spec table Physical/test specification.
-- @return boolean valid Whether all supplied values are usable.
-- @return table errors Human-readable validation errors.
function ACE.ValidateArmorSpec(spec)
	local errors = {}
	local positive = {
		"densityKgM3", "hardnessHB", "fractureToughnessMPaSqrtM", "kineticRHAe", "chemicalRHAe", "heRHAe",
		"curve", "overmatchRatio", "kineticResilience", "chemicalResilience", "heResilience", "penetrationDamageMultiplier",
		"spallResistance", "residualDamageMultiplier", "tileMassKgM2"
	}
	local fractions = { "ductility", "multiHitRetention", "spallCapture", "shockTransmission", "degradation" }

	for field in pairs(spec) do
		if not ACE.ArmorSpecFields[field] then errors[#errors + 1] = "unknown armor spec field: " .. tostring(field) end
	end

	for _, field in ipairs(positive) do
		if spec[field] ~= nil and (not IsFiniteNumber(spec[field]) or spec[field] <= 0) then
			errors[#errors + 1] = field .. " must be a positive number"
		end
	end

	for _, field in ipairs(fractions) do
		if spec[field] ~= nil and (not IsFiniteNumber(spec[field]) or spec[field] < 0 or spec[field] > 1) then
			errors[#errors + 1] = field .. " must be between 0 and 1"
		end
	end

	if spec.spallProduction ~= nil and (not IsFiniteNumber(spec.spallProduction) or spec.spallProduction < 0) then
		errors[#errors + 1] = "spallProduction must be non-negative"
	end

	if IsFiniteNumber(spec.overmatchRatio) and spec.overmatchRatio <= 1.3 then
		errors[#errors + 1] = "overmatchRatio must be greater than 1.3"
	end

	if spec.singleUse ~= nil and type(spec.singleUse) ~= "boolean" then errors[#errors + 1] = "singleUse must be boolean" end

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

local function AttachBehaviorModules(material, behaviorIds, behaviorConfig)
	assert(type(behaviorIds) == "table", "armor behaviors must be a table")
	material.BehaviorModules = {}
	material.BehaviorConfig = CopyValues(behaviorConfig)
	local behaviorCount = 0
	for key in pairs(behaviorIds) do
		assert(type(key) == "number" and key >= 1 and key % 1 == 0, "armor behavior list must use contiguous numeric keys")
		behaviorCount = behaviorCount + 1
	end
	assert(behaviorCount == #behaviorIds, "armor behavior list must be contiguous")

	for _, behavior in ipairs(behaviorIds) do
		assert(type(behavior) == "string" or type(behavior) == "table", "armor behavior entry must be a module ID or table")
		if type(behavior) == "table" then
			for key in pairs(behavior) do assert(key == "id" or key == "parameters", "unknown armor behavior entry key: " .. tostring(key)) end
			if behavior.parameters ~= nil then assert(type(behavior.parameters) == "table", "behavior parameters must be a table") end
		end
		local behaviorId = type(behavior) == "table" and behavior.id or behavior
		assert(ACE.ArmorBehaviorModules[behaviorId], "unknown armor behavior module: " .. tostring(behaviorId))
		material.BehaviorModules[#material.BehaviorModules + 1] = behaviorId
		if type(behavior) == "table" and behavior.parameters ~= nil then
			material.BehaviorConfig[behaviorId] = CopyValues(behavior.parameters)
		end
	end

	material.BehaviorLabels = {}

	for _, behaviorId in ipairs(material.BehaviorModules) do
		local behavior = ACE.ArmorBehaviorModules[behaviorId]
		material.BehaviorLabels[#material.BehaviorLabels + 1] = behavior.label
	end

	local activeBehaviors = {}
	for _, behaviorId in ipairs(material.BehaviorModules) do activeBehaviors[behaviorId] = true end
	for behaviorId in pairs(material.BehaviorConfig) do
		assert(activeBehaviors[behaviorId], "behavior configuration is not active: " .. tostring(behaviorId))
	end

	for behaviorId, parameters in pairs(material.BehaviorConfig) do
		assert(ACE.ArmorBehaviorModules[behaviorId], "unknown armor behavior configuration: " .. tostring(behaviorId))
		assert(type(parameters) == "table", "behavior configuration must be a table: " .. tostring(behaviorId))
		local declaredFields = {}
		for _, field in ipairs(ACE.ArmorBehaviorModules[behaviorId].fields or {}) do declaredFields[field] = true end

		for field, value in pairs(parameters) do
			assert(declaredFields[field], "unsupported " .. behaviorId .. " parameter: " .. tostring(field))
			if field == "singleUse" then
				assert(type(value) == "boolean", "singleUse must be boolean")
			elseif field == "ductility" or field == "multiHitRetention" or field == "spallCapture" or field == "shockTransmission" or field == "degradation" then
				assert(IsFiniteNumber(value) and value >= 0 and value <= 1, field .. " must be between 0 and 1")
			elseif field == "spallProduction" then
				assert(IsFiniteNumber(value) and value >= 0, field .. " must be non-negative")
			else
				assert(IsFiniteNumber(value) and value > 0, field .. " must be a positive number")
			end
		end
	end
end

--- Applies a real-world-oriented spec and reusable behaviors to a material.
-- @param material table Material definition to configure.
-- @param definition table `{spec = ArmorSpecFields, behaviors = module IDs or entries,
-- behaviorConfig = module parameter tables, legacy = compatibility fields,
-- resolver = "modular"}`.
-- @return table material The configured material definition.
function ACE.ConfigureArmorMaterial(material, definition)
	definition = definition or {}
	material.ArmorSpec = CopyValues(definition.spec or material.ArmorSpec)
	material.ArmorResolverConfig = CopyValues(definition.resolverConfig or material.ArmorResolverConfig)
	ValidateResolverConfig(material.ArmorResolverConfig)

	local legacy = definition.legacy or {}
	for key, value in pairs(legacy) do
		if material[key] == nil then material[key] = value end
	end

	AttachBehaviorModules(material, definition.behaviors or material.BehaviorModules, definition.behaviorConfig or material.BehaviorConfig)
	for _, behaviorId in ipairs(material.BehaviorModules) do
		local parameters = material.BehaviorConfig[behaviorId]
		for field, value in pairs(parameters or {}) do material.ArmorSpec[field] = value end
	end

	local valid, errors = ACE.ValidateArmorSpec(material.ArmorSpec)
	assert(valid, "invalid armor spec: " .. table.concat(errors, "; "))

	local spec = material.ArmorSpec
	local modular = definition.resolver == "modular" or material.ArmorResolver == "modular"
	if modular then
		material.massMod = material.massMod or (spec.densityKgM3 and spec.densityKgM3 / 7850)
		material.curve = material.curve or spec.curve or 1
		material.effectiveness = material.effectiveness or spec.kineticRHAe
		material.resiliance = material.resiliance or spec.kineticResilience or 1
		material.HEATeffectiveness = material.HEATeffectiveness or spec.chemicalRHAe or material.effectiveness
		material.HEeffectiveness = material.HEeffectiveness or spec.heRHAe or material.effectiveness
		material.HEATresiliance = material.HEATresiliance or spec.chemicalResilience or material.resiliance
		material.HEresiliance = material.HEresiliance or spec.heResilience or material.resiliance
		material.spallresist = material.spallresist or spec.spallResistance or 1
		material.spallmult = material.spallmult or spec.spallProduction or 1
		material.ArmorMul = material.ArmorMul or 1
		material.NormMult = material.NormMult or 1
		assert(IsFiniteNumber(material.massMod) and material.massMod > 0, "modular armor requires densityKgM3 or massMod")
		assert(IsFiniteNumber(material.effectiveness) and material.effectiveness > 0, "modular armor requires kineticRHAe or effectiveness")
	end

	if spec.densityKgM3 and material.massMod == nil then material.massMod = spec.densityKgM3 / 7850 end
	if spec.kineticRHAe and material.effectiveness == nil then material.effectiveness = spec.kineticRHAe end
	if spec.chemicalRHAe and material.HEATeffectiveness == nil then material.HEATeffectiveness = spec.chemicalRHAe end
	if spec.heRHAe and material.HEeffectiveness == nil then material.HEeffectiveness = spec.heRHAe end
	if spec.curve and material.curve == nil then material.curve = spec.curve end
	if spec.spallResistance and material.spallresist == nil then material.spallresist = spec.spallResistance end
	if spec.spallProduction and material.spallmult == nil then material.spallmult = spec.spallProduction end
	if spec.shockTransmission and material.Stopshock == nil then material.Stopshock = spec.shockTransmission <= 0 end

	if definition.resolver == "modular" then
		material.ArmorResolver = "modular"
		if SERVER then
			material.ArmorResolution = function(Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
				return ACE.ArmorResolvers.Modular(material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
			end
		end
	end
	ValidateLegacyFields(material)

	return material
end

--- Defines and registers a declarative armor material.
-- @param definition table Material identity plus `spec`, `behaviors`, `behaviorConfig`,
-- `legacy`, and `resolver = "modular"`; modular definitions require density/mass and kinetic RHAe/effectiveness.
-- @return table material The registered material definition.
function ACE.DefineArmorMaterial(definition)
	assert(type(definition) == "table", "armor material definition must be a table")
	assert(type(definition.id) == "string" and definition.id ~= "", "armor material definition requires a non-empty id")
	local allowed = { id = true, name = true, sname = true, desc = true, year = true, material = true, spec = true, behaviors = true, behaviorConfig = true, resolverConfig = true, legacy = true, resolver = true }
	for key in pairs(definition) do assert(allowed[key], "unknown armor material definition key: " .. tostring(key)) end
	for _, key in ipairs({ "name", "sname", "desc" }) do
		if definition[key] ~= nil then assert(type(definition[key]) == "string", key .. " must be a string") end
	end
	if definition.year ~= nil then assert(IsFiniteNumber(definition.year), "year must be a finite number") end
	if definition.resolver ~= nil then assert(definition.resolver == "modular", "resolver must be modular") end
	for _, key in ipairs({ "material", "spec", "behaviors", "behaviorConfig", "resolverConfig", "legacy" }) do
		if definition[key] ~= nil then assert(type(definition[key]) == "table", key .. " must be a table") end
	end

	local material = CopyValues(definition.material)
	material.id = definition.id
	material.name = definition.name or material.name or definition.id
	material.sname = definition.sname or material.sname or definition.id
	material.desc = definition.desc or material.desc or ""
	material.year = definition.year or material.year

	ACE.ConfigureArmorMaterial(material, definition)
	assert(definition.resolver == "modular" or type(material.ArmorResolution) == "function", "armor material requires resolver = modular or ArmorResolution")
	ACE.ArmorTypes[material.id] = material

	return material
end

if SERVER then
	local HEATTypes = {
		HEAT = true,
		THEAT = true,
		HEATFS = true,
		THEATFS = true
	}

	local HETypes = {
		HE = true,
		HESH = true,
		Frag = true
	}

	local function Probability(penetration, armor, effectiveness)
		return (math.Clamp(1 / (1 + math.exp(-43.9445 * (penetration / armor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997
	end

	local function LegacyDuctility(Entity, config)
		local value = ((Entity and Entity.ACF and Entity.ACF.Ductility) or 0) * (config.ductilityFactor or 1.25)
		local base = config.ductilityBase or 2
		return base / (base + value * (config.ductilityScale or 1.5))
	end

	local function TriggerImpactHook(hook, Entity, armor, maxPenetration)
		if not Entity or not hook then return end

		if hook == "du_secondary_blast" then
			if not ACE.HE or not Entity.GetPos then return end
			local weight = math.min(maxPenetration * 0.001, 30)
			local owner = (CPPI and Entity.CPPIGetOwner and Entity:CPPIGetOwner()) or NULL
			local position = Entity:GetPos()
			ACE.HE(position, vector_up, weight, weight, owner, Entity, Entity)
			if timer and timer.Simple and ACE.CalculateHERadius and EffectData and util and util.Effect then
				local radius = ACE.CalculateHERadius(weight)
				timer.Simple(0.001, function()
					local flash = EffectData()
					flash:SetOrigin(position)
					flash:SetNormal(-vector_up)
					flash:SetRadius(math.Round(math.max(radius / 39.37 * 0.25, 1), 2))
					util.Effect("ace_scaled_detonation", flash)
				end)
			end
		elseif hook == "era_detonation" then
			if Entity.Remove then Entity:Remove() end
			ACE.ERABoomPerTick = (ACE.ERABoomPerTick or 0) + 1
			if not ACE.HE or not Entity.GetPos or ACE.ERABoomPerTick > 3 then return end
			local weight = math.min(armor * 0.2, 200)
			local owner = (CPPI and Entity.CPPIGetOwner and Entity:CPPIGetOwner()) or NULL
			local position = Entity:GetPos()
			ACE.HE(position, vector_up, weight, weight, owner, Entity, Entity, 0.1)
			if timer and timer.Create and ACE.CalculateHERadius and EffectData and util and util.Effect then
				local radius = ACE.CalculateHERadius(weight)
				if not timer.Exists or not timer.Exists("ACE_ERA_Reset") then
					timer.Create("ACE_ERA_Reset", 0.01, 1, function() ACE.ERABoomPerTick = 0 end)
				end
				timer.Simple(0.001, function()
					local flash = EffectData()
					flash:SetOrigin(position)
					flash:SetNormal(-vector_up)
					flash:SetRadius(math.Round(math.max(radius / 39.37 * 0.125, 1), 2))
					util.Effect("ACE_Scaled_Explosion", flash)
				end)
			end
		end
	end

	local function LegacyResult(armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, effectiveness, resilience, ductility, config, options, Entity, originalArmor)
		local breachCaliber = caliber * (options.breachCaliberMultiplier or 1)
		local breachLimit = options.breachLimit or 7
		local breachProbability = math.Clamp((breachCaliber / armor / effectiveness - 1.3) / (breachLimit - 1.3), 0, 1)
		local penetrationProbability = Probability(maxPenetration, losArmor, effectiveness)
		local damageFactor = options.damageFactor or 1
		local passedDamageMult = options.ignoreDamageMult and 1 or damageMult
		local breachArmor = options.breachUsesRawArmor and armor or armor * effectiveness

		if not options.ignoreBreach and breachProbability > math.random() and maxPenetration > breachArmor then
			if options.impactHook then TriggerImpactHook(options.impactHook, Entity, originalArmor, maxPenetration) end
			return {
				Damage = FrArea * resilience * passedDamageMult * damageFactor * ductility,
				Overkill = maxPenetration - breachArmor,
				Loss = breachArmor / maxPenetration
			}
		end

		if penetrationProbability > math.random() then
			local penetration = math.min(maxPenetration, losArmor * effectiveness)
			local denominator = options.penetrationDamageDenominator == "los" and losArmor or losArmorHealth
			local penetrationDamageFactor = maxPenetration > losArmor * effectiveness and (options.penetrationDamageFactor or 1) or 1
			if (penetrationDamageFactor ~= 1 or options.triggerOnPenetration) and options.impactHook then TriggerImpactHook(options.impactHook, Entity, originalArmor, maxPenetration) end
			return {
				Damage = (penetration / denominator / effectiveness) ^ (options.penetrationDamagePower or 2) * FrArea * resilience * passedDamageMult * damageFactor * penetrationDamageFactor * ductility,
				Overkill = maxPenetration - penetration,
				Loss = penetration / maxPenetration
			}
		end

		local penetration = math.min(maxPenetration, losArmor * effectiveness)
		local denominator = options.failedDamageDenominator == "los" and losArmor or losArmorHealth
		return {
			Damage = (penetration / denominator / effectiveness) ^ (options.failedDamagePower or 1) * FrArea * resilience * passedDamageMult * damageFactor * (options.failedDamageFactor or 1) * ductility,
			Overkill = 0,
			Loss = 1
		}
	end

	local function ResolveLegacy(material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		local config = material.ArmorResolverConfig or {}
		local mode = config.legacyMode or "common"
		local legacy = material
		local curve = legacy.curve or 1
		local effectiveArmor = armor ^ curve
		local effectiveLosArmor = losArmor ^ curve
		local ductility = LegacyDuctility(Entity, config)

		if mode == "ceramic" then
			local factor = effectiveLosArmor / effectiveArmor
			if HETypes[Type] then factor = factor * 15 end
			local result = LegacyResult(effectiveArmor, effectiveLosArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, legacy.effectiveness, legacy.resiliance, ductility, config, {
				breachLimit = 0,
				breachCaliberMultiplier = 0,
				damageFactor = factor,
				penetrationDamageFactor = 4,
				ignoreBreach = true
			}, Entity, armor)
			return result
		end

		if mode == "textolite" then
			local heat = HEATTypes[Type]
			local other = HETypes[Type] or Type == "Spall"
			local effectiveness = heat and legacy.HEATeffectiveness or other and legacy.HEeffectiveness or legacy.effectiveness
			local resilience = heat and legacy.HEATresiliance or other and legacy.HEresiliance or legacy.resiliance
			local options = {
				breachCaliberMultiplier = heat and 1 or 10,
				breachUsesRawArmor = not heat,
				failedDamageDenominator = (heat or other) and "los" or nil,
				failedDamagePower = (heat or other) and 2 or 1,
				ignoreDamageMult = true
			}
			return LegacyResult(effectiveArmor, effectiveLosArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, effectiveness, resilience, ductility, config, options, Entity, armor)
		end

		if mode == "rubber" then
			if Type == "Spall" then
				effectiveArmor = armor ^ curve
				effectiveLosArmor = losArmor ^ curve
				return LegacyResult(effectiveArmor, effectiveLosArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, legacy.spallresist, legacy.resiliance, ductility, config, {
					breachCaliberMultiplier = 1,
					breachUsesRawArmor = true,
					failedDamageDenominator = "los",
					failedDamagePower = 2,
					failedDamageFactor = legacy.Catchresiliance
				}, Entity, armor)
			end

			local heat = HEATTypes[Type]
			local effectiveness = heat and legacy.HEATeffectiveness or legacy.effectiveness
			local resilience = heat and legacy.HEATresiliance or Type == "HE" and legacy.HEresiliance or legacy.resiliance
			local options = {
				breachCaliberMultiplier = heat and 1 or 10,
				breachUsesRawArmor = true,
				failedDamageDenominator = heat and "los" or nil,
				failedDamagePower = heat and 2 or 2,
				damageFactor = Type == "HE" and 1 or 1
			}
			if not heat and Type ~= "HE" then
				options.breachCaliberMultiplier = Type == "Spall" and 1 or 10
				options.failedDamageFactor = legacy.Catchresiliance
			end
			return LegacyResult(effectiveArmor, effectiveLosArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, effectiveness, resilience, ductility, config, options, Entity, armor)
		end

		if mode == "era" then
			local health = Entity and Entity.ACF and Entity.ACF.Health or 1
			local maxHealth = Entity and Entity.ACF and Entity.ACF.MaxHealth or 1
			local condition = math.Clamp(health / math.max(maxHealth, 1), 0, 1)
			local blastArmor = legacy.effectiveness * losArmor * condition
			local sensor = legacy.APSensorFactor or 4
			local resilience = legacy.resiliance

			if HEATTypes[Type] then
				blastArmor = legacy.HEATeffectiveness * losArmor
				resilience = legacy.HEATresiliance
				sensor = legacy.HEATSensorFactor or 16
			elseif HETypes[Type] then
				blastArmor = legacy.Neffectiveness * armor
				resilience = legacy.Nresiliance
				sensor = 1
			end

			if (not HETypes[Type] and maxPenetration > blastArmor / sensor) or condition < 0.15 then
				TriggerImpactHook(config.impactHook, Entity, armor, maxPenetration)
				return {
					Damage = 9999999999999,
					Overkill = math.Clamp(maxPenetration - blastArmor, 0, 1),
					Loss = math.Clamp(blastArmor / maxPenetration, 0, 0.98)
				}
			end

			return LegacyResult(armor ^ (legacy.NCurve or 1), losArmor ^ (legacy.NCurve or 1), losArmorHealth, maxPenetration, FrArea, caliber, damageMult, legacy.Neffectiveness, legacy.Nresiliance, 1, config, { breachLimit = 7, breachUsesRawArmor = true }, Entity, armor)
		end

		local effectiveness = legacy.effectiveness
		local resilience = legacy.resiliance
		local options = { breachCaliberMultiplier = 1, breachUsesRawArmor = true }
		options.impactHook = config.impactHook
		options.triggerOnPenetration = config.triggerOnPenetration
		if HEATTypes[Type] then
			effectiveness = legacy.effectiveness
			if legacy.HEATMul then options.damageFactor = legacy.HEATMul end
		end
		return LegacyResult(effectiveArmor, effectiveLosArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, effectiveness, resilience, ductility, config, options, Entity, armor)
	end

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
	-- @param material table Configured material definition.
	-- @param Entity entity Impacted armor entity.
	-- @param armor number Normal armor thickness.
	-- @param losArmor number Line-of-sight armor thickness.
	-- @param losArmorHealth number Current armor-health normalization.
	-- @param maxPenetration number Incoming RHA penetration.
	-- @param FrArea number Impact area.
	-- @param caliber number Projectile caliber.
	-- @param damageMult number ACE threat damage multiplier.
	-- @param Type string ACE threat type.
	-- @return table result ACE-compatible damage result.
	function ACE.ArmorResolvers.Modular(material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		if (material.ArmorResolverConfig or {}).legacyMode then
			return ResolveLegacy(material, Entity, armor, losArmor, losArmorHealth, maxPenetration, FrArea, caliber, damageMult, Type)
		end
		local spec = material.ArmorSpec or {}
		local resolverConfig = material.ArmorResolverConfig or {}
		local _, effectiveness, resilience = ThreatValues(material, Type)
		local threatConfig = resolverConfig.threats and resolverConfig.threats[Type]
			or resolverConfig.defaultThreat
			or {}
		effectiveness = threatConfig.effectiveness or effectiveness
		resilience = threatConfig.resilience or resilience
		local curve = threatConfig.curve or spec.curve or material.curve or 1
		local overmatchRatio = threatConfig.overmatchRatio or spec.overmatchRatio or 7
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
			damageMultiplier = damageMultiplier * (config.shockTransmission or spec.shockTransmission or 1)
		end

		local condition = 1
		if Entity and Entity.ACF and Entity.ACF.MaxHealth and Entity.ACF.MaxHealth > 0 then
			condition = math.Clamp((Entity.ACF.Health or Entity.ACF.MaxHealth) / Entity.ACF.MaxHealth, 0, 1)
		end

		-- Degradation is the linear loss as health falls; retention is the hard floor
		-- that repeated impacts cannot reduce past.
		local retention = spec.multiHitRetention or 0
		local degradation = spec.degradation or 0
		local degradationFactor = 1 - degradation * (1 - condition)
		effectiveness = effectiveness * math.max(retention, degradationFactor)

		local ductility = math.Clamp((Entity and Entity.ACF and Entity.ACF.Ductility or spec.ductility or 0) * (resolverConfig.ductilityFactor or 1), 0, 1)
		local ductilityBase = resolverConfig.ductilityBase or 2
		local ductilityScale = resolverConfig.ductilityScale or 1.5
		local ductilityMultiplier = ductilityBase / (ductilityBase + ductility * ductilityScale)
		local effectiveArmor = armor ^ curve
		local effectiveLosArmor = losArmor ^ curve
		local breachCaliber = caliber * (threatConfig.breachCaliberMultiplier or resolverConfig.breachCaliberMultiplier or 1)
		local breachProbability = math.Clamp((breachCaliber / effectiveArmor / effectiveness - 1.3) / (overmatchRatio - 1.3), 0, 1)
		local breachArmor = effectiveArmor * effectiveness
		local penetrationProbability = (math.Clamp(1 / (1 + math.exp(-43.9445 * (maxPenetration / effectiveLosArmor / effectiveness - 1))), 0.0015, 0.9985) - 0.0015) / 0.997

		if breachProbability > math.random() and maxPenetration > breachArmor then
			return {
				Damage = FrArea * resilience * damageMult * ductilityMultiplier * damageMultiplier,
				Overkill = maxPenetration - breachArmor,
				Loss = breachArmor / maxPenetration
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

--- Attaches the standard behavior profile to loaded legacy materials.
-- @param materials table Loaded ACE armor material definitions.
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
