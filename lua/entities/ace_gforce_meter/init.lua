AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

CreateConVar("sbox_max_ace_gforce_meter", 10)

DEFINE_BASECLASS("base_wire_entity")

local ExtrasTable = ACE.Weapons.Extras

function ENT:Initialize()
	self.ThinkDelay = 0.05
	self.CurrentGForce = 1
	self.GForceVector = Vector(0, 0, 1)
	self.LastGForcePos = self:GetPos()
	self.LastGForceVel = Vector(0, 0, 0)
	self.LastGForceTime = CurTime()

	self.Inputs = WireLib.CreateInputs(self, {})

	self.Outputs = WireLib.CreateOutputs(self, {
		"GForce (Current G-force magnitude)",
		"GForceVec (G-force as a direction vector) [VECTOR]",
		"GForceX (G-force on local X axis - forward/back)",
		"GForceY (G-force on local Y axis - left/right)",
		"GForceZ (G-force on local Z axis - up/down)",
	})

	self:UpdateOutputs()
	self:UpdateOverlayText()
end

function ACE.MakeGForceMeter(Owner, Pos, Angle, Id)
	if not Owner:CheckLimit("_ace_gforce_meter") then return false end

	Id = Id or "GForceMeter"

	local entData = ExtrasTable[Id]
	if not entData then return false end

	local ent = ents.Create("ace_gforce_meter")
	if not IsValid(ent) then return false end

	ent:SetAngles(Angle)
	ent:SetPos(Pos)

	ent.Model = entData.model
	ent.Weight = entData.weight
	ent.ACFName = entData.name
	ent.ACEPoints = entData.acepoints or 0

	ent.Id = Id

	ent:Spawn()
	ent:CPPISetOwner(Owner)

	ent:SetNWNetwork()
	ent:SetModelEasy(entData.model)
	ent:UpdateOverlayText()

	Owner:AddCount("_ace_gforce_meter", ent)
	Owner:AddCleanup("acemenu", ent)

	return ent
end

list.Set("ACFCvars", "ace_gforce_meter", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_gforce_meter", ACE.MakeGForceMeter, "Pos", "Angle", "Id", "Data")

function ENT:SetNWNetwork()
	self:SetNWString("WireName", self.ACFName or "G-Force Meter")
end

function ENT:SetModelEasy(mdl)
	self:SetModel(mdl)
	self.Model = mdl

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(self.Weight or 2)
	end
end

function ENT:CalculateGForce()
	local curTime = CurTime()
	local deltaTime = curTime - self.LastGForceTime

	if deltaTime <= 0.01 then return end

	local curPos = self:GetPos()
	local lastPos = self.LastGForcePos

	-- Calculate velocity from position delta (works with parented entities)
	local curVel = (curPos - lastPos) / deltaTime
	local lastVel = self.LastGForceVel

	-- Calculate acceleration
	local deltaVel = curVel - lastVel
	local worldAccel = deltaVel / deltaTime

	-- Convert to local space
	local localAccel = self:WorldToLocal(self:GetPos() + worldAccel) - self:WorldToLocal(self:GetPos())

	-- Add gravity compensation on Z axis (we feel 1G upward when stationary)
	localAccel.z = localAccel.z + 386.22

	-- Convert to G-force (386.22 in/s² = 1G in Source units)
	self.GForceVector = localAccel / 386.22

	local gforce = self.GForceVector:Length()

	-- Smooth the value
	local smoothFactor = 0.5
	self.CurrentGForce = self.CurrentGForce + (gforce - self.CurrentGForce) * smoothFactor

	-- Snap to 1G when nearly stationary
	if math.abs(self.CurrentGForce - 1) < 0.08 and curVel:Length() < 20 then
		self.CurrentGForce = 1
		self.GForceVector = Vector(0, 0, 1)
	end

	self.LastGForceTime = curTime
	self.LastGForcePos = curPos
	self.LastGForceVel = curVel
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "GForce", self.CurrentGForce)
	WireLib.TriggerOutput(self, "GForceVec", self.GForceVector)
	WireLib.TriggerOutput(self, "GForceX", self.GForceVector.x)
	WireLib.TriggerOutput(self, "GForceY", self.GForceVector.y)
	WireLib.TriggerOutput(self, "GForceZ", self.GForceVector.z)
end

function ENT:UpdateOverlayText()
	local gforce = math.Round(self.CurrentGForce, 2)
	local vertical = math.Round(self.GForceVector.z, 2)
	local lateral = math.Round(math.sqrt(self.GForceVector.x^2 + self.GForceVector.y^2), 2)

	local txt = "G-Force Meter"
	txt = txt .. "\n\nTotal: " .. gforce .. " G"
	txt = txt .. "\nVertical: " .. vertical .. " G"
	txt = txt .. "\nLateral: " .. lateral .. " G"

	if gforce > 6 then
		txt = txt .. "\n\n[!] EXTREME G-FORCE"
	elseif gforce > 4 then
		txt = txt .. "\n\n[!] High G-Force"
	end

	self:SetOverlayText(txt)
end

function ENT:Think()
	local curTime = CurTime()

	self:CalculateGForce()
	self:UpdateOutputs()
	self:UpdateOverlayText()

	self:NextThink(curTime + self.ThinkDelay)
	return true
end
