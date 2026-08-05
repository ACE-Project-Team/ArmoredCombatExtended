-- Shared, data-only behavior vocabulary for armor materials.
-- This metadata layer deliberately does not alter legacy armor coefficients or resolvers.
AddCSLuaFile()

ACE = ACE or {}
ACE.ArmorBehaviorModules = {
	homogeneous_metal = {
		label = "Homogeneous metal",
		description = "Single-material plate with conventional ductile penetration behavior."
	},
	lightweight_metal = {
		label = "Lightweight metal",
		description = "Weight-saving metal whose protection depends strongly on alloy and thickness."
	},
	dense_metal = {
		label = "Dense metal",
		description = "High-density armor layer with increased mass and protection per thickness."
	},
	brittle_strike_face = {
		label = "Brittle strike face",
		description = "High initial resistance with localized fracture and reduced multi-hit tolerance."
	},
	composite_backing = {
		label = "Composite backing",
		description = "Fiber or resin backing that absorbs residual energy and limits fragments."
	},
	elastomer_liner = {
		label = "Elastomer liner",
		description = "Deformable layer focused on shock, fragment, and spall control."
	},
	reactive_tile = {
		label = "Reactive tile",
		description = "Expendable explosive tile that disrupts an incoming projectile."
	},
	spall_response = {
		label = "Spall response",
		description = "Controls fragment production and residual spall energy after impact."
	},
	shock_barrier = {
		label = "Shock barrier",
		description = "Limits blast or shock continuation through layered armor."
	},
	failure_state = {
		label = "Impact state",
		description = "Supports fractured, depleted, or otherwise degraded post-hit behavior."
	}
}

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
function ACE.ApplyArmorBehaviorModules(materials)
	for materialId, behaviorIds in pairs(ACE.ArmorBehaviorSets) do
		local material = materials[materialId]
		if material then
			material.BehaviorModules = {}

			for index, behaviorId in ipairs(behaviorIds) do
				material.BehaviorModules[index] = behaviorId
			end

			material.BehaviorLabels = {}

			for _, behaviorId in ipairs(behaviorIds) do
				local behavior = ACE.ArmorBehaviorModules[behaviorId]
				if behavior then material.BehaviorLabels[#material.BehaviorLabels + 1] = behavior.label end
			end
		end
	end
end

--- Returns the behavior module IDs attached to an armor material.
-- @param material table|nil ACE armor material definition.
-- @return table modules Behavior module IDs, or an empty table.
function ACE.GetArmorBehaviorModules(material)
	return material and material.BehaviorModules or {}
end
