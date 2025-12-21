-- Shared crewseat data (client and server)
AddCSLuaFile()

ACE = ACE or {}

ACE.CrewseatModels = {
	["Sitting"] = "models/chairs_playerstart/sitpose.mdl",
	["Sitting Alt"] = "models/chairs_playerstart/sitposealt.mdl",
	["Standing"] = "models/chairs_playerstart/standingpose.mdl",
	["Jeep"] = "models/chairs_playerstart/jeeppose.mdl",
	["Airboat"] = "models/chairs_playerstart/airboatpose.mdl",
}

ACE.CrewseatModelList = {
	"Sitting",
	"Sitting Alt",
	"Standing",
	"Jeep",
	"Airboat",
}

ACE.CrewseatDefaults = {
	["ace_crewseat_driver"] = "Sitting",
	["ace_crewseat_gunner"] = "Sitting",
	["ace_crewseat_loader"] = "Standing",
}

-- Reverse lookup: model path -> model type name
ACE.CrewseatModelLookup = {}
for name, path in pairs(ACE.CrewseatModels) do
	ACE.CrewseatModelLookup[path] = name
end

-- Which models count as "standing"
ACE.CrewseatStandingModels = {
	["Standing"] = true,
}

-- Pose modifiers: Standing vs Sitting
ACE.CrewseatPoseModifiers = {
	["ace_crewseat_driver"] = {
		["sitting"] = {
			gforce = 1.0,
			tilt = 1.0,
			desc = "Stable driving position"
		},
		["standing"] = {
			gforce = 1.5,
			tilt = 1.5,
			desc = "Unstable - not recommended"
		},
	},

	["ace_crewseat_gunner"] = {
		["sitting"] = {
			gforce = 1.0,
			tilt = 1.0,
			accuracy = 1.0,
			desc = "Stable aiming position"
		},
		["standing"] = {
			gforce = 1.5,
			tilt = 1.5,
			accuracy = 1.2,
			desc = "Less stable - reduced accuracy"
		},
	},

	["ace_crewseat_loader"] = {
		["sitting"] = {
			gforce = 0.8,
			tilt = 0.8,
			stamina = 0.9,
			desc = "Stable but slower loading"
		},
		["standing"] = {
			gforce = 1.2,
			tilt = 1.2,
			stamina = 1.15,
			desc = "Mobile - faster loading"
		},
	},
}

-- Helper function to check if pose is standing
function ACE_IsStandingPose(modelType)
	return ACE.CrewseatStandingModels[modelType] or false
end

-- Helper function to get pose modifiers
function ACE_GetPoseModifiers(ent)
	if not IsValid(ent) then return nil end

	local class = ent:GetClass()
	local modelType = ent.ModelType or "Sitting"
	local isStanding = ACE_IsStandingPose(modelType)
	local poseKey = isStanding and "standing" or "sitting"

	local classModifiers = ACE.CrewseatPoseModifiers[class]
	if not classModifiers then return nil end

	return classModifiers[poseKey] or classModifiers["sitting"]
end

-- Check if a model is a valid crewseat model
function ACE_IsValidCrewseatModel(modelPath)
	if not modelPath then return false end
	return ACE.CrewseatModelLookup[modelPath] ~= nil
end