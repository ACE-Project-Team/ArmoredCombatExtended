-- Server-side crewseat functionality and G-force system
include("acf/shared/sh_crewseat_base.lua")

-- Rare crew names (easter eggs)
local rareNames = {
	"Mr.Marty", "RDC", "Cheezus", "KemGus", "Golem Man", "Arend", "Mac",
	"Firstgamerable", "kerbal cadet", "Psycho Dog", "Ferv", "Rice",
	"spEAM", "Orange_Fox", "Dedem", "Garry"
}

local randomPrefixes = {"John", "Bob", "Sam", "Joe", "Ben", "Alex", "Chris", "David", "Eric", "Frank", "Antonio", "Ivan", "Alexander", "Victor", "Elon", "Vladimir", "Donald"}
local randomSuffixes = {"Smith", "Johnson", "Dover", "Wang", "Kim", "Lee", "Brown", "Davis", "Evans", "Garcia", "", "Russel", "King", "Musk", "Popov"}

function ACE_GenerateCrewName()
	local randomNum = math.random(1, 100)

	if randomNum <= 2 then
		return rareNames[math.random(1, #rareNames)]
	else
		local prefix = randomPrefixes[math.random(1, #randomPrefixes)]
		local suffix = randomSuffixes[math.random(1, #randomSuffixes)]
		return prefix .. " " .. suffix
	end
end

-- G-Force tracking for contraptions
local ContraptionGForce = {}
local GForceThinkDelay = 0.1

local function GetContraptionKey(contraption)
	if not contraption then return nil end
	return tostring(contraption)
end

function ACE_GetContraptionGForce(ent)
	if not IsValid(ent) then return 0 end

	local contraption = ent:GetContraption()
	if not contraption then return 0 end

	local key = GetContraptionKey(contraption)
	if not key then return 0 end

	local data = ContraptionGForce[key]
	if not data then return 0 end

	return data.gforce or 0
end

-- Update G-force for all contraptions with crewseats
timer.Create("ACE_CrewseatGForce", GForceThinkDelay, 0, function()
	local processedContraptions = {}

	for _, seat in ipairs(ACE.Crewseats or {}) do
		if not IsValid(seat) then continue end

		local contraption = seat:GetContraption()
		if not contraption then continue end

		local key = GetContraptionKey(contraption)
		if not key or processedContraptions[key] then continue end
		processedContraptions[key] = true

		local baseplate = contraption:GetACEBaseplate()
		if not IsValid(baseplate) then continue end

		local phys = baseplate:GetPhysicsObject()
		if not IsValid(phys) then continue end

		local curVel = phys:GetVelocity()
		local curTime = CurTime()

		local data = ContraptionGForce[key]
		if not data then
			ContraptionGForce[key] = {
				lastVel = curVel,
				lastTime = curTime,
				gforce = 0,
				smoothGforce = 0,
			}
			continue
		end

		local deltaTime = curTime - data.lastTime
		if deltaTime <= 0 then continue end

		local deltaVel = curVel - data.lastVel
		local acceleration = deltaVel:Length() / deltaTime

		-- Convert to G-force (386.22 in/s² = 1G, Source uses inches)
		local gforce = acceleration / 386.22

		-- Smooth the G-force value to avoid spikes
		local smoothFactor = 0.3
		data.smoothGforce = data.smoothGforce + (gforce - data.smoothGforce) * smoothFactor
		data.gforce = data.smoothGforce

		data.lastVel = curVel
		data.lastTime = curTime
	end

	-- Cleanup old entries
	for key, data in pairs(ContraptionGForce) do
		if CurTime() - data.lastTime > 5 then
			ContraptionGForce[key] = nil
		end
	end
end)

-- Shared initialization for crewseats
function ACE_InitializeCrewseat(ent, modelType)
	local class = ent:GetClass()

	-- Validate model type, fallback to default if invalid
	if not modelType or not ACE.CrewseatModels[modelType] then
		modelType = ACE.CrewseatDefaults[class] or "Sitting"
	end

	local model = ACE.CrewseatModels[modelType]

	ent:SetModel(model)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetUseType(SIMPLE_USE)
	ent:SetSolid(SOLID_VPHYSICS)

	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(80)
	end

	ent.Master = {}
	ent.ACF = {}
	ent.ACF.Health = 1
	ent.ACF.MaxHealth = 1
	ent.ACF.Armour = 1
	ent.Name = ACE_GenerateCrewName()
	ent.Weight = 80
	ent.AnglePenalty = 0
	ent.GForcePenalty = 0
	ent.ModelType = modelType
	ent.Model = model
	ent.Sound = "npc/combine_soldier/die" .. tostring(math.random(1, 3)) .. ".wav"
	ent.SoundPitch = 100

	ent.NextLegalCheck = ACF.CurTime + math.random(ACF.Legal.Min, ACF.Legal.Max)
	ent.Legal = true
	ent.LegalIssues = ""

	ent.SpecialHealth = false
	ent.SpecialDamage = true

	return model
end

-- Shared angle penalty calculation
local startPenalty = 45
local maxPenalty = 90

function ACE_UpdateCrewseatAnglePenalty(ent)
	local curSeatAngle = math.deg(math.acos(ent:GetUp():Dot(Vector(0, 0, 1))))
	ent.AnglePenalty = math.Clamp(math.Remap(curSeatAngle, startPenalty, maxPenalty, 0, 1), 0, 1)
	return ent.AnglePenalty
end

-- G-force penalty calculation (0 to 1, where 1 is maximum penalty)
-- Penalties start at 2G and max out at 6G
function ACE_UpdateGForcePenalty(ent)
	local gforce = ACE_GetContraptionGForce(ent)
	ent.GForcePenalty = math.Clamp(math.Remap(gforce, 2, 6, 0, 1), 0, 1)
	ent.CurrentGForce = gforce
	return ent.GForcePenalty, gforce
end

-- Shared legal check
function ACE_CrewseatLegalCheck(ent)
	if ACF.CurTime > ent.NextLegalCheck then
		-- First do standard ACF legal check
		ent.Legal, ent.LegalIssues = ACF_CheckLegal(ent, ent.Model, math.Round(ent.Weight, 2), nil, true, true)

		-- Then check if model is valid crewseat model
		if ent.Legal then
			local currentModel = ent:GetModel()
			if not ACE_IsValidCrewseatModel(currentModel) then
				ent.Legal = false
				ent.LegalIssues = "Invalid crewseat model"
			end
		end

		ent.NextLegalCheck = ACF.Legal.NextCheck(ent.Legal)
	end
	return ent.Legal
end

-- Shared OnRemove
function ACE_CrewseatOnRemove(ent)
	for Key in pairs(ent.Master) do
		if ent.Master[Key] and ent.Master[Key]:IsValid() then
			ent.Master[Key]:Unlink(ent)
		end
	end
end

-- Shared damage function
function ACE_CrewseatDamage(ent, Entity, Energy, FrArea, Inflictor)
	ent.ACF.Armour = 3
	local HitRes = ACF_PropDamage(Entity, Energy, FrArea, 0, Inflictor)
	return HitRes
end

-- Play death sound
function ACE_CrewseatDeathSound(ent)
	EmitSound(ent.Sound, ent:GetPos(), 50, CHAN_AUTO, 1, 75, 0, ent.SoundPitch)
end

-- Find replacement loader seat
function ACE_FindReplacementLoader(ent, maxDistSqr)
	maxDistSqr = maxDistSqr or 624100 -- 20m squared

	local closestDist = math.huge
	local replaceEnt = nil

	for _, SeatEnt in pairs(ACE.Crewseats or {}) do
		if not IsValid(SeatEnt) then continue end
		if SeatEnt:CPPIGetOwner() ~= ent:CPPIGetOwner() then continue end
		if SeatEnt:GetClass() ~= "ace_crewseat_loader" then continue end

		local sqDist = SeatEnt:GetPos():DistToSqr(ent:GetPos())
		if sqDist < maxDistSqr and sqDist < closestDist then
			closestDist = sqDist
			replaceEnt = SeatEnt
		end
	end

	return replaceEnt, closestDist
end