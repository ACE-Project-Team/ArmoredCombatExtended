AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local APSModel = "models/props_lab/reciever01a.mdl"
local LinkDistance = 512

CreateConVar("sbox_max_ace_aps", 2)

local RadarClasses = {
	acf_missileradar = true,
}

local function IsLinkInRange(aps, ent)
	return aps:GetPos():DistToSqr(ent:GetPos()) <= LinkDistance * LinkDistance
end

local function IsRadar(ent)
	return IsValid(ent) and RadarClasses[ent:GetClass()] == true
end

local function NotifyPoints(aps, ent, reason)
	if ACE_PointsInputChanged and IsValid(ent) then
		ACE_PointsInputChanged({aps, ent}, reason)
	end
end

function ENT:Initialize()
	BaseClass.Initialize(self)

	self:SetModel(APSModel)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local physics = self:GetPhysicsObject()
	if IsValid(physics) then
		physics:SetMass(25)
		physics:Wake()
	end

	self.IsMaster = true
	self.RadarLinks = {}
	self.LinkedGun = nil
	self.Inputs = WireLib.CreateInputs(self, {"Active"})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Active",
		"Radar Count",
		"Gun Linked",
		"Gimbal",
	})
	self.Active = true
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

--- Creates an APS entity for the ACE menu and duplicator.
-- @param Owner Player who owns the entity.
-- @param Pos Vector spawn position.
-- @param Angle Angle spawn orientation.
-- @param Class string APS entity class.
-- @return Entity spawned APS, or false when creation is denied.
function ACE.MakeAPS(Owner, Pos, Angle, Class)
	if not IsValid(Owner) or not Owner:CheckLimit("_ace_aps") then return false end

	local APS = ents.Create(Class)
	if not IsValid(APS) then return false end

	APS:SetPos(Pos)
	APS:SetAngles(Angle)
	APS:Spawn()
	APS:Activate()
	APS:CPPISetOwner(Owner)

	Owner:AddCount("_ace_aps", APS)
	Owner:AddCleanup("acemenu", APS)

	return APS
end

--- Checks whether an entity can be linked to this APS.
-- @param Target Entity to validate.
-- @return boolean Whether the link is allowed.
-- @return string|nil Failure reason.
function ENT:CanLink(Target)
	if not IsValid(Target) then
		return false, "Invalid entity!"
	end

	if not IsLinkInRange(self, Target) then
		return false, "That entity is too far away to link!"
	end

	if IsRadar(Target) then
		for _, radar in ipairs(self.RadarLinks) do
			if radar == Target then
				return false, "That radar is already linked!"
			end
		end

		return true
	end

	if Target:GetClass() == "acf_gun" then
		if IsValid(self.LinkedGun) then
			return false, "This APS can only link to one gun!"
		end

		return true
	end

	return false, "APS can only link to missile radars or an ACF gun!"
end

--- Links a missile radar or gun to this APS.
-- @param Target Entity to link.
-- @return boolean Whether the link succeeded.
-- @return string Result or failure message.
function ENT:Link(Target)
	local canLink, message = self:CanLink(Target)
	if not canLink then
		return false, message
	end

	if IsRadar(Target) then
		table.insert(self.RadarLinks, Target)
	elseif Target:GetClass() == "acf_gun" then
		self.LinkedGun = Target
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
	NotifyPoints(self, Target, "aps-link")

	return true, "Link successful!"
end

--- Removes a linked missile radar or gun from this APS.
-- @param Target Entity to unlink.
-- @return boolean Whether the unlink succeeded.
-- @return string Result or failure message.
function ENT:Unlink(Target)
	local removed = false

	for index = #self.RadarLinks, 1, -1 do
		if self.RadarLinks[index] == Target then
			table.remove(self.RadarLinks, index)
			removed = true
		end
	end

	if self.LinkedGun == Target then
		self.LinkedGun = nil
		removed = true
	end

	if not removed then
		return false, "That entity is not linked to this APS!"
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
	NotifyPoints(self, Target, "aps-unlink")

	return true, "Unlink successful!"
end

function ENT:TriggerInput(Input, Value)
	if Input ~= "Active" then return end

	self.Active = Value ~= 0
	self:UpdateWireOutputs()
	self:UpdateOverlayText()
end

function ENT:UpdateWireOutputs()
	WireLib.TriggerOutput(self, "Active", self.Active and 1 or 0)
	WireLib.TriggerOutput(self, "Radar Count", #self.RadarLinks)
	WireLib.TriggerOutput(self, "Gun Linked", IsValid(self.LinkedGun) and 1 or 0)
	WireLib.TriggerOutput(self, "Gimbal", self.Gimbal and 1 or 0)
end

function ENT:UpdateOverlayText()
	local gunStatus = IsValid(self.LinkedGun) and "Linked" or "Not linked"
	local variant = self.Gimbal and "Gimbal" or "Static"

	self:SetOverlayText(
		"APS: " .. variant ..
		"\nStatus: " .. (self.Active and "On" or "Off") ..
		"\nRadars: " .. #self.RadarLinks ..
		"\nGun: " .. gunStatus
	)
end

function ENT:Think()
	for index = #self.RadarLinks, 1, -1 do
		if not IsValid(self.RadarLinks[index]) then
			table.remove(self.RadarLinks, index)
		end
	end

	if not IsValid(self.LinkedGun) then
		self.LinkedGun = nil
	end

	self:UpdateWireOutputs()
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

--- Stores APS links for duplicator persistence.
function ENT:PreEntityCopy()
	local entityIDs = {}

	for _, radar in ipairs(self.RadarLinks) do
		if IsValid(radar) then
			table.insert(entityIDs, radar:EntIndex())
		end
	end

	if IsValid(self.LinkedGun) then
		table.insert(entityIDs, self.LinkedGun:EntIndex())
	end

	duplicator.StoreEntityModifier(self, "ACEAPSLinks", {entities = entityIDs})
	BaseClass.PreEntityCopy(self)
end

--- Restores APS links after duplicator paste.
-- @param Player Player who pasted the entity.
-- @param Ent Duplicator source entity data.
-- @param CreatedEntities Entities created by the duplicator.
function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	if Ent.EntityMods and Ent.EntityMods.ACEAPSLinks then
		for _, entityID in ipairs(Ent.EntityMods.ACEAPSLinks.entities or {}) do
			local linked = CreatedEntities[entityID]
			if IsValid(linked) then
				self:Link(linked)
			end
		end

		Ent.EntityMods.ACEAPSLinks = nil
	end

	BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)
end

function ENT:OnRemove()
	Wire_Remove(self)

	for _, radar in ipairs(self.RadarLinks) do
		NotifyPoints(self, radar, "aps-removed")
	end

	if IsValid(self.LinkedGun) then
		NotifyPoints(self, self.LinkedGun, "aps-removed")
	end
end
