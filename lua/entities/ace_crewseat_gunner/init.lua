AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local round, ceil = math.Round, math.ceil

local CrewseatTable = ACF.Weapons.Crewseats

function ENT:Initialize()
	ACE.InitializeCrewseat(self, self.ModelType)

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

function ACE.MakeCrewseatGunner(Owner, Pos, Angle, Id, EntityData)
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
	Owner:AddCleanup("acfmenu", ent)

	return ent
end

list.Set("ACFCvars", "ace_crewseat_gunner", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_crewseat_gunner", ACE.MakeCrewseatGunner, "Pos", "Angle", "Id", "ModelType")

function ENT:GetPoseModifiers()
	return ACE.GetPoseModifiers(self) or { gforce = 1, tilt = 1, accuracy = 1 }
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
	ACE.UpdateCrewseatAnglePenalty(self)
	ACE.UpdateGForcePenalty(self)
	ACE.CrewseatLegalCheck(self)

	local gun = self.LinkedGun
	if not self.Legal and IsValid(gun) then
		gun:Unlink(self)
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:OnRemove()
	ACE.CrewseatOnRemove(self)
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
	local isStanding = ACE.IsStandingPose(self.ModelType)

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
		str = str .. "\n\nNot legal, disabled for " .. ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end

function ENT:ACF_OnDamage(Entity, Energy, FrArea, _, Inflictor, _, _)
	local HitRes = ACE.CrewseatDamage(self, Entity, Energy, FrArea, Inflictor)

	if HitRes.Kill or HitRes.Overkill > 1 then
		self:ConsumeCrewseats()
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	return HitRes
end

function ENT:ConsumeCrewseats()
	ACE.CrewseatDeathSound(self)

	self.Legal = false
	self.LegalIssues = "Apparently He Died"

	self:SetNoDraw(true)
	self:SetNotSolid(true)

	for _, Link in pairs(self.Master) do
		if IsValid(Link) then
			Link.HasGunner = false
		end
	end

	local ReplaceEnt, ClosestDist = ACE.FindReplacementLoader(self)

	if IsValid(ReplaceEnt) then
		self.Name = ReplaceEnt.Name
		ACE.HEKill(ReplaceEnt, VectorRand(), 0)

		local ReplaceTime = 5 + math.sqrt(ClosestDist) / 39.37 * 1

		timer.Create("CrewDie" .. self:GetCreationID(), ReplaceTime, 1, function()
			if IsValid(self) then
				self:ResetLinks()
			end
		end)
	else
		ACE.HEKill(self, VectorRand(), 0)
	end
end

function ENT:ResetLinks()
	self.ACF.Health = self.ACF.MaxHealth or 1
	self.ACF.Armour = self.ACF.MaxArmour or 1
	self.NextLegalCheck = 0
	self:SetNoDraw(false)
	self:SetNotSolid(false)

	for _, Link in pairs(self.Master) do
		if IsValid(Link) then
			table.insert(Link.CrewLink, self)
			Link.HasGunner = true
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

	ACE.CrewseatDebugLog(self, "ApplyDupeInfoStart", info, "model=" .. tostring(self:GetModel()))
	local modelType, _, reason = ACE.CrewseatApplyDupeModel(self, info, defaultModelType, false)
	ACE.CrewseatDebugLog(self, "ApplyDupeInfoEnd", info, "resolved=" .. tostring(modelType) .. " reason=" .. tostring(reason))
	ACE.CrewseatDeferredModelSync(self, info)
end
