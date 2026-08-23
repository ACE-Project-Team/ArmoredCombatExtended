AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

CreateConVar("sbox_max_ace_vheat_source", 3)

DEFINE_BASECLASS( "base_wire_entity" )

local VHeatSrcTable = ACE.Weapons.Tools["VHeatSrc"]

function ENT:Initialize()
	self.ThinkDelay			= 0.1
	self.StatusUpdateDelay	= 0.5
	self.LastStatusUpdate	= CurTime()
	self.Active				= false

	self.Heat = ACE.AmbientTemp
	self.HeatingRate = 0
	self.CoolingRate = 0
	self.MaxTemperature = self.Heat

	self.SpecialHealth       = true  --If true needs a special ACE_Activate function

	self.Inputs = WireLib.CreateInputs(self, {
		"Active (Whether to turn the virtual heat source on or off)",
		"Max Temperature (The maximum temperature of the virtual heat source, C°)",
		"Heating Rate (The rate at which the virtual heat source temperature increases when active, C°/s)",
		"Cooling Rate (The rate at which the virtual heat source temperature decreases when not active, C°/s)",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Heat",
	})

end

function ENT:ACF_Activate( _ )
	ACE.GetEntityState(self, true)

	local PhysObj = self:GetPhysicsObject()

	self.ACE.Area 		= PhysObj:GetSurfaceArea()
	self.ACE.Volume 	= PhysObj:GetVolume()
	self.ACE.Health		= 9999
	self.ACE.MaxHealth  = self.ACE.Health
	self.ACE.Armour		= 0.1
	self.ACE.MaxArmour  = self.ACE.Armour
	self.ACE.Type		= nil
	self.ACE.Mass		= self.Mass
	self.ACE.Density	= (PhysObj:GetMass() * 1000) / self.ACE.Volume
	self.ACE.Type		= "Prop"
end

function ACE.MakeVHeatSource(Owner, Pos, Angle, Id)
	if not Owner:CheckLimit("_ace_vheat_source") then return false end

	Id = Id or "VHeatSrc"
	local VHeatSrcEnt = ents.Create("ace_vheat_source")

	if not IsValid(VHeatSrcEnt) then return false end

	VHeatSrcEnt:SetAngles(Angle)
	VHeatSrcEnt:SetPos(Pos)

	VHeatSrcEnt.Model = VHeatSrcTable.model
	VHeatSrcEnt.Weight = VHeatSrcTable.weight
	VHeatSrcEnt.AcfName = VHeatSrcTable.name
	VHeatSrcEnt.ACEPoints = VHeatSrcTable.acepoints

	VHeatSrcEnt.Id = Id

	VHeatSrcEnt:Spawn()
	VHeatSrcEnt:CPPISetOwner(Owner)

	VHeatSrcEnt:SetNWNetwork()
	VHeatSrcEnt:SetModelEasy(VHeatSrcTable.model)
	VHeatSrcEnt:UpdateOverlayText()

	Owner:AddCount( "_ace_vheat_source", VHeatSrcEnt )
	Owner:AddCleanup( "acemenu", VHeatSrcEnt )

	return VHeatSrcEnt
end

list.Set( "ACFCvars", "ace_vheat_source", {"id"} )
duplicator.RegisterEntityClass("ace_vheat_source", ACE.MakeVHeatSource, "Pos", "Angle", "Id" )

function ENT:SetNWNetwork()
	self:SetNWString( "WireName", self.ACEName )
end

function ENT:SetModelEasy(mdl)
	local ent = self

	ent:SetModel( mdl )
	ent.Model = mdl

	ent:PhysicsInit( SOLID_VPHYSICS )
	ent:SetMoveType( MOVETYPE_VPHYSICS )
	ent:SetSolid( SOLID_VPHYSICS )

	local phys = ent:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:SetMass(ent.Weight)
	end
end

function ENT:TriggerInput(inp, value)
	if inp == "Active" then
		self.Active = value ~= 0
	elseif inp == "Max Temperature" then
		self.MaxTemperature = math.max(value, ACE.AmbientTemp)
		self.Heat = math.Clamp(self.Heat, ACE.AmbientTemp, self.MaxTemperature)
	elseif inp == "Heating Rate" then
		self.HeatingRate = value
	elseif inp == "Cooling Rate" then
		self.CoolingRate = value
	end
	self:UpdateOverlayText()
end

function ENT:UpdateOverlayText()
	local txt = "Status: " .. (self.Active and "On" or "Off")
	txt = txt .. "\n\nHeating rate: " .. self.HeatingRate .. "°C/s"
	txt = txt .. "\nCooling rate: " .. self.CoolingRate .. "°C/s"
	txt = txt .. "\nMax temp: " .. self.MaxTemperature .. "°C"
	txt = txt .. "\nTemp: " .. math.Round(self.Heat) .. "°C"
	self:SetOverlayText(txt)
end

function ENT:Think()
	local curTime = CurTime()
	self:NextThink(curTime + self.ThinkDelay)

	local rateTemperature = self.Active and self.HeatingRate or self.CoolingRate
	self.Heat = math.Clamp(self.Heat + rateTemperature * self.ThinkDelay, ACE.AmbientTemp, self.MaxTemperature)

	WireLib.TriggerOutput(self, "Heat", self.Heat)
	self:UpdateOverlayText()

	return true --Needed for think delay override
end
