-- Server-side crewseat functionality and G-force system
-- Notes:
--  - G-force is computed per-seat from seat position delta (works even when parented).
--  - Resting should read ~1G (gravity).
--  - No timer.Create() here to avoid duplicate timers during lua refresh.

include("ace/shared/sh_crewseat_base.lua")

local crewseatDebug = CreateConVar("ace_debug_crewseat_models", "0", FCVAR_ARCHIVE, "Log crewseat model/type changes during dupe paste")

-- Resolve a crewseat model type from dupe data or the current model path.
function ACE.CrewseatResolveModelType(ent, info)
	if not IsValid(ent) then return nil end

	local modelPath = (info and info.Model) or ent:GetModel()
	if not modelPath then return nil end

	local modelType = ACE.CrewseatModelLookup and ACE.CrewseatModelLookup[modelPath]
	if not modelType or not (ACE.CrewseatModels and ACE.CrewseatModels[modelType]) then
		return nil
	end

	if ent.ModelType ~= modelType then
		ent.ModelType = modelType
	end

	local model = ACE.CrewseatModels[modelType]
	if model and ent.Model ~= model then
		ent:SetModel(model)
		ent.Model = model
	end

	return modelType
end

-- Check whether crewseat model debugging is enabled.
function ACE.CrewseatDebugEnabled()
	return crewseatDebug:GetBool()
end

-- Print a crewseat debug line when enabled.
function ACE.CrewseatDebugLog(ent, stage, info, extra)
	if not ACE.CrewseatDebugEnabled() then return end

	local owner = "Unknown"
	if ent.CPPIGetOwner then
		local ply = ent:CPPIGetOwner()
		if IsValid(ply) then owner = ply:Nick() end
	end

	local infoModel = info and info.Model or "nil"
	local infoModelType = info and info.ModelType or "nil"
	local entClass = IsValid(ent) and ent:GetClass() or "unknown"
	local entIndex = IsValid(ent) and ent:EntIndex() or 0
	local model = IsValid(ent) and ent:GetModel() or "nil"
	local modelType = IsValid(ent) and (ent.ModelType or "nil") or "nil"

	print(string.format("[ACE Crewseat] %s(%d) owner=%s stage=%s infoModel=%s infoModelType=%s model=%s modelType=%s extra=%s",
		entClass, entIndex, owner, stage, infoModel, infoModelType, model, modelType, extra or "none"))
end

-- Apply dupe model data with a fallback model type and optional legacy override.
function ACE.CrewseatApplyDupeModel(ent, info, defaultModelType, legacyForceSitting)
	local modelType = info.ModelType
	local legacyLocked = false
	local reason = "preserved"

	ent.ACE_DupeInfoModel = info.Model
	ent.ACE_DupeInfoModelType = info.ModelType

	if legacyForceSitting and info.ModelType == nil and info.Model == nil then
		modelType = "Sitting"
		legacyLocked = true
		reason = "legacy forced sitting"
	end

	if not modelType or not ACE.CrewseatModels[modelType] then
		local modelPath = info.Model or ent:GetModel()
		modelType = (modelPath and ACE.CrewseatModelLookup[modelPath]) or modelType
		if modelType and ACE.CrewseatModels[modelType] then
			reason = "restored from model path"
		end
	end

	if not modelType or not ACE.CrewseatModels[modelType] then
		modelType = defaultModelType or "Sitting"
		reason = "class default fallback"
	end

	ent.ModelType = modelType
	ent.ACE_LegacyCrewseatModelLocked = legacyLocked or nil
	ent.ACE_DupeResolveReason = reason

	local model = ACE.CrewseatModels[modelType]
	if model then
		ent:SetModel(model)
		ent.Model = model
	end

	return modelType, legacyLocked, reason
end

-- Defer model sync so the duplicator can finish applying model data.
function ACE.CrewseatDeferredModelSync(ent, info)
	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if ent.ACE_LegacyCrewseatModelLocked then return end
		local beforeModel = ent:GetModel()
		local beforeType = ent.ModelType
		local modelType = ACE.CrewseatResolveModelType(ent, info)
		if modelType and (beforeModel ~= ent:GetModel() or beforeType ~= ent.ModelType) then
			ent.ACE_DupeDeferredModel = ent:GetModel()
			ent.ACE_DupeDeferredModelType = ent.ModelType
			ent.ACE_DupeDeferredResolved = modelType
			ACE.CrewseatDebugLog(ent, "DeferredSync", info, "resolved=" .. tostring(modelType))
		end
	end)
end

ACE = ACE or {}

-- Dump crewseat state for debugging from console.
concommand.Add("ace_crewseat_dump", function(_, _, args)
	local target = tonumber(args[1] or "")

	local function dumpSeat(ent)
		if not IsValid(ent) then return end

		local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
		local ownerName = IsValid(owner) and owner:Nick() or "Unknown"
		local model = ent:GetModel() or "nil"
		local modelType = ent.ModelType or "nil"
		local infoModel = ent.ACE_DupeInfoModel or "nil"
		local infoModelType = ent.ACE_DupeInfoModelType or "nil"
		local resolveReason = ent.ACE_DupeResolveReason or "nil"
		local spawnModel = ent.ACE_DupeSpawnModel or "nil"
		local spawnModelType = ent.ACE_DupeSpawnModelType or "nil"
	local spawnLegacy = ent.ACE_DupeSpawnLegacy and "true" or "false"
		local initModel = ent.ACE_InitModel or "nil"
		local initModelType = ent.ACE_InitModelType or "nil"
		local deferredModel = ent.ACE_DupeDeferredModel or "nil"
		local deferredType = ent.ACE_DupeDeferredModelType or "nil"
		local deferredResolved = ent.ACE_DupeDeferredResolved or "nil"
		local weight = tonumber(ent.Weight) or 0
		local legal = ent.Legal and "true" or "false"
		local issues = ent.LegalIssues or ""

		print(string.format("[ACE Crewseat] %s(%d) owner=%s model=%s modelType=%s weight=%.2f legal=%s issues=%s",
			ent:GetClass(), ent:EntIndex(), ownerName, model, modelType, weight, legal, issues))
		print(string.format("[ACE Crewseat] dupe infoModel=%s infoModelType=%s resolveReason=%s deferredModel=%s deferredModelType=%s deferredResolved=%s",
			infoModel, infoModelType, resolveReason, deferredModel, deferredType, deferredResolved))
		print(string.format("[ACE Crewseat] dupe spawnModel=%s spawnModelType=%s initModel=%s initModelType=%s",
			spawnModel, spawnModelType, initModel, initModelType))
		print(string.format("[ACE Crewseat] dupe spawnLegacy=%s", spawnLegacy))
	end

	if target then
		dumpSeat(Entity(target))
		return
	end

	for _, seat in pairs(ACE.Crewseats or {}) do
		dumpSeat(seat)
	end
end)

-- Rare crew names (easter eggs)
local rareNames = {
	"Mr.Marty", "RDC", "Cheezus", "KemGus", "Golem Man", "Arend", "Mac",
	"Firstgamerable", "kerbal cadet", "Psycho Dog", "Ferv", "Rice",
	"spEAM", "Orange_Fox", "Dedem", "Garry"
}

local randomPrefixes = {
	"John", "Bob", "Sam", "Joe", "Ben", "Alex", "Chris", "David", "Eric", "Frank",
	"Antonio", "Ivan", "Alexander", "Victor", "Elon", "Vladimir", "Donald"
}
local randomSuffixes = {
	"Smith", "Johnson", "Dover", "Wang", "Kim", "Lee", "Brown", "Davis", "Evans",
	"Garcia", "", "Russel", "King", "Musk", "Popov"
}

function ACE.GenerateCrewName()
	local randomNum = math.random(1, 100)

	if randomNum <= 2 then
		return rareNames[math.random(1, #rareNames)]
	end

	local prefix = randomPrefixes[math.random(1, #randomPrefixes)]
	local suffix = randomSuffixes[math.random(1, #randomSuffixes)]
	return prefix .. " " .. suffix
end

-- =========================================================
-- G-FORCE CALCULATION (PER ENTITY)
-- =========================================================

local vec_up = Vector(0, 0, 1)
local INCHES_PER_S2_PER_G = 386.22

local function EnsureGForceState(ent)
	local st = ent.ACE_GForceState
	if st then return st end

	st = {
		LastTime = CurTime(),
		LastPos = ent:GetPos(),
		LastVel = Vector(0, 0, 0),

		-- Smoothed felt-g in local space
		GVec = Vector(0, 0, 1),
		GMag = 1,
	}

	ent.ACE_GForceState = st
	ent.CurrentGForce = 1
	ent.GForceVector = st.GVec

	return st
end

-- Returns:
--  gMag: number (includes gravity, so resting ~= 1)
--  gVec: Vector (local-space felt acceleration in Gs; resting ~= (0,0,1))
function ACE.CalcEntityGForce(ent)
	if not IsValid(ent) then
		return 1, Vector(0, 0, 1)
	end

	local st = EnsureGForceState(ent)

	local now = CurTime()
	local dt = now - st.LastTime

	-- Avoid divide-by-zero and massive spikes after lag/loading
	if dt <= 0 then
		return st.GMag, st.GVec
	end

	if dt > 0.5 then
		-- If we skipped too long, reset state
		st.LastTime = now
		st.LastPos = ent:GetPos()
		st.LastVel = Vector(0, 0, 0)
		st.GVec = Vector(0, 0, 1)
		st.GMag = 1
		ent.CurrentGForce = 1
		ent.GForceVector = st.GVec
		return 1, st.GVec
	end

	local pos = ent:GetPos()
	local vel = (pos - st.LastPos) / dt
	local accel_world = (vel - st.LastVel) / dt

	-- Convert world accel to local accel
	-- (WorldToLocal on a position, so use pos+accel trick)
	local accel_local = ent:WorldToLocal(pos + accel_world) - ent:WorldToLocal(pos)

	-- Add gravity so resting reads 1G upward (felt acceleration)
	accel_local.z = accel_local.z + INCHES_PER_S2_PER_G

	local gVec = accel_local / INCHES_PER_S2_PER_G
	local gMag = gVec:Length()

	-- Smooth factor based on dt (exponential smoothing)
	-- Higher multiplier = snappier response
	local alpha = 1 - math.exp(-dt * 10)

	st.GVec = st.GVec + (gVec - st.GVec) * alpha
	st.GMag = st.GMag + (gMag - st.GMag) * alpha

	-- Snap to exactly 1G when almost stationary and near 1G
	if math.abs(st.GMag - 1) < 0.05 and vel:Length() < 5 then
		st.GMag = 1
		st.GVec = Vector(0, 0, 1)
	end

	st.LastTime = now
	st.LastPos = pos
	st.LastVel = vel

	ent.CurrentGForce = st.GMag
	ent.GForceVector = st.GVec

	return st.GMag, st.GVec
end

-- =========================================================
-- CREWSEAT COMMON HELPERS
-- =========================================================

-- Shared initialization for crewseats
function ACE.InitializeCrewseat(ent, modelType)
	local class = ent:GetClass()

	-- Validate model type, fallback to default if invalid
	if not modelType or not ACE.CrewseatModels or not ACE.CrewseatModels[modelType] then
		modelType = (ACE.CrewseatDefaults and ACE.CrewseatDefaults[class]) or "Sitting"
	end

	local model = ACE.CrewseatModels[modelType]

	ent:SetModel(model)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetUseType(SIMPLE_USE)
	ent:SetSolid(SOLID_VPHYSICS)

	local phys = ent:GetPhysicsObject()
	local crewData = ent.CrewseatData
	local weight = (crewData and crewData.weight) or ent.Weight or 85

	if IsValid(phys) then
		phys:SetMass(weight) -- requested seat weight
	end

	ent.Master = {}
	ACE.GetEntityState(ent, true)
	ent.ACE.Health = ent.ACE.Health or 1
	ent.ACE.MaxHealth = ent.ACE.MaxHealth or 1
	ent.ACE.Armour = ent.ACE.Armour or 1

	ent.Name = ent.Name or ACE.GenerateCrewName()
	ent.Weight = weight
	ent.AnglePenalty = 0
	ent.GForcePenalty = 0

	ent.ModelType = modelType
	ent.Model = model

	ent.ACE_InitModelType = modelType
	ent.ACE_InitModel = model

	ent.Sound = ent.Sound or ("npc/combine_soldier/die" .. tostring(math.random(1, 3)) .. ".wav")
	ent.SoundPitch = ent.SoundPitch or 100

	ent.NextLegalCheck = ACE.CurTime + math.random(ACE.Legal.Min, ACE.Legal.Max)
	ent.Legal = true
	ent.LegalIssues = ""

	ent.SpecialHealth = false
	ent.SpecialDamage = true

	-- Initialize g-force state
	ent.ACE_GForceState = nil
	EnsureGForceState(ent)

	return model
end

-- Shared angle penalty calculation
local startPenalty = 45
local maxPenalty = 90

function ACE.UpdateCrewseatAnglePenalty(ent)
	-- Clamp dot to avoid NaN from acos
	local dot = math.Clamp(ent:GetUp():Dot(vec_up), -1, 1)
	local curSeatAngle = math.deg(math.acos(dot))

	ent.AnglePenalty = math.Clamp(math.Remap(curSeatAngle, startPenalty, maxPenalty, 0, 1), 0, 1)
	return ent.AnglePenalty
end

-- G-force penalty calculation (0..1)
-- Penalties start at 2G and max out at 6G
function ACE.UpdateGForcePenalty(ent)
	local gTotal, gVec = ACE.CalcEntityGForce(ent) -- gVec is local-space felt G vector; rest ~= (0,0,1)
	ent.CurrentGForce = gTotal
	ent.GForceVector = gVec

	-- Excess over gravity (rest -> 0)
	local gExcess = (gVec - Vector(0, 0, 1)):Length()
	ent.CurrentGForceExcess = gExcess

	ent.GForcePenalty = math.Clamp(math.Remap(gExcess, 2, 6, 0, 1), 0, 1)
	return ent.GForcePenalty, gTotal, gExcess
end

-- Crewseat-specific legal check (includes model validation)
function ACE.CrewseatLegalCheck(ent)
	if ACE.CurTime > ent.NextLegalCheck then
		local currentModel = ent:GetModel()
		if ent.Model ~= currentModel then
			ent.Model = currentModel
		end

		ent.Legal, ent.LegalIssues = ACE.CheckLegal(ent, ent.Model, math.Round(ent.Weight, 2), nil, true, true)

		if ent.Legal and not (ACE.IsValidCrewseatModel and ACE.IsValidCrewseatModel(currentModel)) then
			ent.Legal = false
			ent.LegalIssues = "Invalid crewseat model"
		end

		ent.NextLegalCheck = ACE.Legal.NextCheck(ent.Legal)
	end

	return ent.Legal
end

-- Shared OnRemove
function ACE.CrewseatOnRemove(ent)
	for Key in pairs(ent.Master or {}) do
		if ent.Master[Key] and ent.Master[Key]:IsValid() then
			ent.Master[Key]:Unlink(ent)
		end
	end
end

-- Shared damage function
function ACE.CrewseatDamage(ent, Entity, Energy, FrArea, Inflictor)
	ent.ACE.Armour = 3
	local HitRes = ACE.PropDamage(Entity, Energy, FrArea, 0, Inflictor)
	return HitRes
end

-- Play death sound
function ACE.CrewseatDeathSound(ent)
	EmitSound(ent.Sound, ent:GetPos(), 50, CHAN_AUTO, 1, 75, 0, ent.SoundPitch)
end

-- Find replacement loader seat
function ACE.FindReplacementLoader(ent, maxDistSqr)
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
