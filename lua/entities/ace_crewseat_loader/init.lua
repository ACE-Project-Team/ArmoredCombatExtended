AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local round, ceil = math.Round, math.ceil
local clamp = math.Clamp

local EntityTable = ACF.Weapons.Entities

function ENT:Initialize()
	ACE_InitializeCrewseat(self, self.ModelType)

	self.Stamina = 100
	self.LinkedGun = nil
	self.ACEPoints = 400

	self.Inputs = WireLib.CreateInputs(self, {})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Health (Current health percentage)",
		"Stamina (Current stamina percentage)",
		"IsLinked (1 if linked to a gun)",
		"Name (Crew member name) [STRING]",
	})

	self:UpdateWireOutputs()
end

function MakeACE_Crewseat_Loader(Owner, Pos, Angle, Id, EntityData)
	if not Owner:CheckLimit("_ace_crewseat") then return false end

	Id = Id or "Crewseat_Loader"

	local entData = EntityTable[Id]
	if not entData then return false end

	local ent = ents.Create("ace_crewseat_loader")
	if not IsValid(ent) then return false end

	ent:SetAngles(Angle)
	ent:SetPos(Pos)

	local modelType = EntityData
	if not modelType or modelType == "" then
		modelType = entData.defaultModel or "Standing"
	end
	ent.ModelType = modelType

	ent:Spawn()
	ent:CPPISetOwner(Owner)

	ent.Id = Id

	Owner:AddCount("_ace_crewseat", ent)
	Owner:AddCleanup("acfmenu", ent)

	return ent
end

list.Set("ACFCvars", "ace_crewseat_loader", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_crewseat_loader", MakeACE_Crewseat_Loader, "Pos", "Angle", "Id", "Data")

function ENT:GetPoseModifiers()
	return ACE_GetPoseModifiers(self) or { gforce = 1, tilt = 1, stamina = 1 }
end

function ENT:DecreaseStamina()
	local linkedGun = self.LinkedGun

	if IsValid(linkedGun) then
		local bulletWeight = 0
		local distanceToCrate = 0

		if linkedGun.BulletData then
			local ProjMass = linkedGun.BulletData.ProjMass or 0
			local PropMass = linkedGun.BulletData.PropMass or 0
			bulletWeight = ProjMass + PropMass
		end

		if linkedGun.AmmoLink and linkedGun.CurAmmo then
			local CurAmmo = linkedGun.CurAmmo
			if IsValid(linkedGun.AmmoLink[CurAmmo]) then
				local gunPos = linkedGun:GetPos()
				local ammoPos = linkedGun.AmmoLink[CurAmmo]:GetPos()
				distanceToCrate = gunPos:Distance(ammoPos)
			end
		end

		local pose = self:GetPoseModifiers()
		local staminaMod = pose.stamina or 1

		local distanceMultiplier = 0.032
		local weightMultiplier = 1
		local staminaMultipliers = bulletWeight * weightMultiplier + distanceToCrate * distanceMultiplier
		local staminaCost = (5 + staminaMultipliers) / staminaMod -- Better pose = less stamina cost

		self.Stamina = round(self.Stamina - staminaCost)
	end
end

function ENT:IncreaseStamina()
	local staminaHeal = 0.32
	local pose = self:GetPoseModifiers()

	-- Apply pose modifiers
	local tiltMod = pose.tilt or 1
	local gforceMod = pose.gforce or 1
	local staminaMod = pose.stamina or 1

	local angleMod = 1 - ((self.AnglePenalty or 0) * tiltMod)
	local gforceModifier = 1 - (((self.GForcePenalty or 0) * 0.8) * gforceMod)

	-- Standing gives bonus stamina regen (more mobile)
	self.Stamina = clamp(self.Stamina + staminaHeal * angleMod * gforceModifier * staminaMod, 0, 100)

	return self.Stamina
end

function ENT:Think()
	ACE_UpdateCrewseatAnglePenalty(self)
	ACE_UpdateGForcePenalty(self)
	ACE_CrewseatLegalCheck(self)

	if self.Legal then
		self:IncreaseStamina()
	end

	local gun = self.LinkedGun
	if not self.Legal and IsValid(gun) then
		gun:Unlink(self)
	end

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
	WireLib.TriggerOutput(self, "Stamina", round(self.Stamina))
	WireLib.TriggerOutput(self, "IsLinked", isLinked)
	WireLib.TriggerOutput(self, "Name", self.Name or "Unknown")
end

function ENT:UpdateOverlayText()
	local hp = round(self.ACF.Health / self.ACF.MaxHealth * 100)
	local stamina = round(self.Stamina)
	local pose = self:GetPoseModifiers()
	local isStanding = ACE_IsStandingPose(self.ModelType)

	local str = self.Name
	str = str .. "\n\nHealth: " .. hp .. "%"
	str = str .. "\nStamina: " .. stamina .. "%"
	str = str .. "\nPose: " .. (isStanding and "Standing" or "Sitting")

	if pose.desc then
		str = str .. "\n  " .. pose.desc
	end

	-- Only show penalties if significant
	local hasPenalty = false
	local tiltPenalty = (self.AnglePenalty or 0) * (pose.tilt or 1)
	local gforcePenalty = (self.GForcePenalty or 0) * (pose.gforce or 1)

	if tiltPenalty > 0.1 then
		if not hasPenalty then
			str = str .. "\n\nActive Penalties:"
			hasPenalty = true
		end
		str = str .. "\n  - Tilt: -" .. round(tiltPenalty * 100) .. "% stamina regen"
	end

	if gforcePenalty > 0.1 then
		if not hasPenalty then
			str = str .. "\n\nActive Penalties:"
			hasPenalty = true
		end
		str = str .. "\n  - G-Force: -" .. round(gforcePenalty * 80) .. "% stamina regen"
	end

	if not self.Legal then
		str = str .. "\n\nNot legal, disabled for " .. ceil(self.NextLegalCheck - ACF.CurTime) .. "s\nIssues: " .. self.LegalIssues
	end

	self:SetOverlayText(str)
end

function ENT:ACF_OnDamage(Entity, Energy, FrArea, _, Inflictor, _, _)
	local HitRes = ACE_CrewseatDamage(self, Entity, Energy, FrArea, Inflictor)

	if HitRes.Kill or HitRes.Overkill > 1 then
		ACE_CrewseatDeathSound(self)
		ACF_HEKill(self, VectorRand(), 0)
		return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }
	end

	return HitRes
end

function ENT:BuildDupeInfo()
	local info = self.BaseClass.BuildDupeInfo(self) or {}
	info.ModelType = self.ModelType
	return info
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
    self.BaseClass.ApplyDupeInfo(self, ply, ent, info, GetEntByID)

    local modelType = info.ModelType

    -- Old dupes don't have ModelType saved, default to Sitting (original behavior)
    if not modelType or not ACE.CrewseatModels[modelType] then
        modelType = "Sitting"
    end

    self.ModelType = modelType
    local model = ACE.CrewseatModels[modelType]
    if model then
        self:SetModel(model)
        self.Model = model
    end
end