AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local round, ceil = math.Round, math.ceil

local CrewseatTable = ACE.Weapons.Crewseats

function ENT:Initialize()
	ACE_InitializeCrewseat(self, self.ModelType)

	self.LinkedGun = nil

	self.Inputs = WireLib.CreateInputs(self, {})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Health (Current health percentage)",
		"IsLinked (1 if linked to a gun)",
		"AccuracyPenalty (Current accuracy penalty multiplier)",
		"Name (Crew member name) [STRING]",
	})

	self:UpdateWireOutputs()
end

function ACE_MakeCrewseatGunner(Owner, Pos, Angle, Id, EntityData)
	if not IsValid(Owner) then return false end
	if not Owner:CheckLimit("_ace_crewseat") then return false end

	Id = Id or "Crewseat_Gunner"

	local entData = CrewseatTable and CrewseatTable[Id]
	if not entData then return false end

	local ent = ents.Create("ace_crewseat_gunner")
	if not IsValid(ent) then return false end

	ent:SetAngles(Angle)
	ent:SetPos(Pos)

	ent.CrewseatData = entData

	local modelType = EntityData
	if not modelType or modelType == "" then
		modelType = entData.defaultModel or "Sitting"
	end
	ent.ModelType = modelType
	ent.ACE_DupeSpawnModelType = modelType
	ent.ACE_DupeSpawnModel = ACE.CrewseatModels and ACE.CrewseatModels[modelType] or nil

	ent:Spawn()
	ent:CPPISetOwner(Owner)

	ent.Id = Id

	Owner:AddCount("_ace_crewseat", ent)
	Owner:AddCleanup("acemenu", ent)

	return ent
end

list.Set("ACFCvars", "ace_crewseat_gunner", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_crewseat_gunner", ACE_MakeCrewseatGunner, "Pos", "Angle", "Id", "ModelType")

function ENT:GetPoseModifiers()
	return ACE_GetPoseModifiers(self) or { gforce = 1, tilt = 1, accuracy = 1 }
end

function ENT:GetAccuracyPenalty()
	local anglePenalty = self.AnglePenalty or 0
	local gforcePenalty = self.GForcePenalty or 0
	local pose = self:GetPoseModifiers()

	-- Apply pose modifiers
	local tiltMod = pose.tilt or 1
	local gforceMod = pose.gforce or 1
	local accuracyMod = pose.accuracy or 1

	-- Calculate total penalty with pose modifiers
	local totalPenalty = accuracyMod * (1 + (anglePenalty * 0.5 * tiltMod) + (gforcePenalty * 1.0 * gforceMod))

	return totalPenalty
end

function ENT:Think()
	ACE_UpdateCrewseatAnglePenalty(self)
	ACE_UpdateGForcePenalty(self)
	local legal = ACE.RequireEntityLegal(self)

	-- An illegal crewseat stays linked: the gun already ignores illegal crew for its rate of fire
	-- and gunner checks, so the link recovers on its own once the seat is legal again.
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:OnRemove()
	ACE_CrewseatOnRemove(self)
end

function ENT:UpdateWireOutputs()
	local hp = round(self.ACF.Health / self.ACF.MaxHealth * 100)
	local isLinked = IsValid(self.LinkedGun) and 1 or 0

	WireLib.TriggerOutput(self, "Health", hp)
	WireLib.TriggerOutput(self, "IsLinked", isLinked)
	WireLib.TriggerOutput(self, "AccuracyPenalty", self:GetAccuracyPenalty())
	WireLib.TriggerOutput(self, "Name", self.Name or "Unknown")
end

function ENT:UpdateOverlayText()
	local hp = round(self.ACF.Health / self.ACF.MaxHealth * 100)
	local pose = self:GetPoseModifiers()
	local isStanding = ACE_IsStandingPose(self.ModelType)

	local str = self.Name
	str = str .. "\n\nHealth: " .. hp .. "%"
	str = str .. "\nPose: " .. (isStanding and "Standing" or "Sitting")

	if pose.desc then
		str = str .. "\n  " .. pose.desc
	end

	-- Only show penalties if significant
	local totalPenalty = self:GetAccuracyPenalty()
	if totalPenalty > 1.05 then
		local accuracyPercent = round(100 / totalPenalty)
		str = str .. "\n\nAccuracy: " .. accuracyPercent .. "%"

		local tiltContrib = (self.AnglePenalty or 0) * (pose.tilt or 1) * 50
		local gforceContrib = (self.GForcePenalty or 0) * (pose.gforce or 1) * 100

		if tiltContrib > 5 then
			str = str .. "\n  - Tilt: -" .. round(tiltContrib) .. "%"
		end

		if gforceContrib > 5 then
			str = str .. "\n  - G-Force: -" .. round(gforceContrib) .. "%"
		end

		if isStanding then
			str = str .. "\n  - Standing: -20%"
		end
	end

	if not self.Legal then
		str = str .. "\n\nNot legal, disabled for " .. math.max(0, ceil(self.NextLegalCheck - ACE.CurTime)) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end

function ENT:ACF_OnDamage(Entity, Energy, FrArea, _, Inflictor, _, _)
	local HitRes = ACE_CrewseatDamage(self, Entity, Energy, FrArea, Inflictor)

	if HitRes.Kill or HitRes.Overkill > 1 then
		self:ConsumeCrewseats()
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	return HitRes
end

function ENT:ConsumeCrewseats()
	ACE_CrewseatDeathSound(self)

	self.Legal = false
	self.LegalIssues = "Apparently He Died"

	ACE.WithMutationScope(self, "crewseat-death", function()
		self:SetNoDraw(true)
		self:SetNotSolid(true)
	end)

	for _, Link in pairs(self.Master) do
		if IsValid(Link) then
			Link.HasGunner = false
			if ACE_PointsInputChanged then
				ACE_PointsInputChanged({ Link, self }, "gunner-status-changed")
			end
		end
	end

	local ReplaceEnt, ClosestDist = ACE_FindReplacementLoader(self)

	if IsValid(ReplaceEnt) then
		self.Name = ReplaceEnt.Name
		ACE_HEKill(ReplaceEnt, VectorRand(), 0)

		local ReplaceTime = 5 + math.sqrt(ClosestDist) / 39.37 * 1

		timer.Create("CrewDie" .. self:GetCreationID(), ReplaceTime, 1, function()
			if IsValid(self) then
				self:ResetLinks()
			end
		end)
	else
		ACE_HEKill(self, VectorRand(), 0)
	end
end

function ENT:ResetLinks()
	self.ACF.Health = self.ACF.MaxHealth or 1
	self.ACF.Armour = self.ACF.MaxArmour or 1
	self.NextLegalCheck = 0
	ACE.WithMutationScope(self, "crewseat-replacement", function()
		self:SetNoDraw(false)
		self:SetNotSolid(false)
	end)

	for _, Link in pairs(self.Master) do
		if IsValid(Link) then
			if not table.HasValue(Link.CrewLink, self) then
				table.insert(Link.CrewLink, self)
			end
			Link.HasGunner = true
			if ACE_PointsInputChanged then
				ACE_PointsInputChanged({ Link, self }, "gunner-status-changed")
			end
		end
	end
end

function ENT:BuildDupeInfo()
	local info = self.BaseClass.BuildDupeInfo(self) or {}
	info.ModelType = self.ModelType
	info.Model = self.Model
	return info
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
	self.BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)

	local class = self:GetClass()
	local defaultModelType = (ACE.CrewseatDefaults and ACE.CrewseatDefaults[class]) or "Sitting"

	ACE_CrewseatDebugLog(self, "ApplyDupeInfoStart", info, "model=" .. tostring(self:GetModel()))
	local modelType, _, reason = ACE_CrewseatApplyDupeModel(self, info, defaultModelType, false)
	ACE_CrewseatDebugLog(self, "ApplyDupeInfoEnd", info, "resolved=" .. tostring(modelType) .. " reason=" .. tostring(reason))
	ACE_CrewseatDeferredModelSync(self, info)
end
