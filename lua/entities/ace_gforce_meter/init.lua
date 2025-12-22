AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local EntityTable = ACF.Weapons.Entities

function ENT:Initialize()
	self.ThinkDelay = 0.02
	self.CurrentGForce = 0
	self.SmoothedGForce = 0
	self.GForceVector = Vector(0, 0, 0)
	self.LastVelocity = Vector(0, 0, 0)
	self.LastThinkTime = CurTime()

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

function MakeACE_GForce_Meter(Owner, Pos, Angle, Id, EntityData)
	if not Owner:CheckLimit("_ace_gforce_meter") then return false end

	Id = Id or "GForceMeter"

	local entData = EntityTable[Id]
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
	Owner:AddCleanup("acfmenu", ent)

	return ent
end

list.Set("ACFCvars", "ace_gforce_meter", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_gforce_meter", MakeACE_GForce_Meter, "Pos", "Angle", "Id", "Data")

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
	local deltaTime = curTime - self.LastThinkTime

	if deltaTime <= 0 then return end

	-- Try to use CFW contraption velocity first
	local curVel
	local contraption = self:GetContraption()

	if contraption then
		local baseplate = contraption:GetACEBaseplate()
		if IsValid(baseplate) then
			local phys = baseplate:GetPhysicsObject()
			if IsValid(phys) then
				curVel = phys:GetVelocity()
			end
		end
	end

	-- Fallback to own physics if not in contraption
	if not curVel then
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			curVel = phys:GetVelocity()
		else
			return
		end
	end

	local deltaVel = curVel - self.LastVelocity
	local worldAccel = deltaVel / deltaTime

	-- Convert to local space acceleration
	local localAccel = self:WorldToLocal(self:GetPos() + worldAccel) - self:WorldToLocal(self:GetPos())

	-- Add gravity compensation on Z axis
	localAccel.z = localAccel.z + 386.22

	-- Convert to G-force (386.22 in/s² = 1G in Source units)
	self.GForceVector = localAccel / 386.22

	local gforce = self.GForceVector:Length()

	-- Faster smoothing - reaches target quicker
	local smoothFactor = 0.6
	self.SmoothedGForce = self.SmoothedGForce + (gforce - self.SmoothedGForce) * smoothFactor

	-- Snap to 1.0 when very close and stable (stationary)
	if math.abs(self.SmoothedGForce - 1) < 0.05 and curVel:Length() < 10 then
		self.SmoothedGForce = 1
	end

	self.LastVelocity = curVel
	self.LastThinkTime = curTime
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "GForce", self.SmoothedGForce)
	WireLib.TriggerOutput(self, "GForceVec", self.GForceVector)
	WireLib.TriggerOutput(self, "GForceX", self.GForceVector.x)
	WireLib.TriggerOutput(self, "GForceY", self.GForceVector.y)
	WireLib.TriggerOutput(self, "GForceZ", self.GForceVector.z)
end

function ENT:UpdateOverlayText()
	local gforce = math.Round(self.SmoothedGForce, 2)
	local vertical = math.Round(self.GForceVector.z, 2)
	local lateral = math.Round(math.sqrt(self.GForceVector.x^2 + self.GForceVector.y^2), 2)

	local txt = "G-Force Meter"
	txt = txt .. "\n\nTotal: " .. gforce .. " G"
	txt = txt .. "\nVertical: " .. vertical .. " G"
	txt = txt .. "\nLateral: " .. lateral .. " G"

	-- Warning indicators
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