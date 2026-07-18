AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

CreateConVar("sbox_max_ace_wind_sensor", 10)

DEFINE_BASECLASS("base_wire_entity")

local ExtrasTable = ACF.Weapons.Extras

function ENT:Initialize()
	self.ThinkDelay = 0.1

	self.Inputs = WireLib.CreateInputs(self, {})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Wind (Raw wind vector) [VECTOR]",
		"WindSpeed (Wind speed in units per second)",
		"WindAngle (Wind direction as angle) [ANGLE]"
	})

	self:UpdateOutputs()
	self:UpdateOverlayText()
end

function ACE.MakeWindSensor(Owner, Pos, Angle, Id)
	if not Owner:CheckLimit("_ace_wind_sensor") then return false end

	Id = Id or "WindSensor"

	local entData = ExtrasTable[Id]
	if not entData then return false end

	local Sensor = ents.Create("ace_wind_sensor")

	if not IsValid(Sensor) then return false end

	Sensor:SetAngles(Angle)
	Sensor:SetPos(Pos)

	Sensor.Model = entData.model
	Sensor.Weight = entData.weight
	Sensor.ACFName = entData.name
	Sensor.ACEPoints = entData.acepoints or 0

	Sensor.Id = Id

	Sensor:Spawn()
	Sensor:CPPISetOwner(Owner)

	Sensor:SetNWNetwork()
	Sensor:SetModelEasy(entData.model)
	Sensor:UpdateOverlayText()

	Owner:AddCount("_ace_wind_sensor", Sensor)
	Owner:AddCleanup("acfmenu", Sensor)

	return Sensor
end

list.Set("ACFCvars", "ace_wind_sensor", {"id", "entitydata"})
duplicator.RegisterEntityClass("ace_wind_sensor", ACE.MakeWindSensor, "Pos", "Angle", "Id", "Data")

function ENT:SetNWNetwork()
	self:SetNWString("WireName", self.ACFName)
end

function ENT:SetModelEasy(mdl)
	self:SetModel(mdl)
	self.Model = mdl

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetMass(self.Weight)
	end
end

function ENT:UpdateOutputs()
	local Wind = ACF.Wind or Vector(0, 0, 0)
	local WindSpeed = Wind:Length()
	local WindAngle = Wind:Angle()

	WireLib.TriggerOutput(self, "Wind", Wind)
	WireLib.TriggerOutput(self, "WindSpeed", WindSpeed)
	WireLib.TriggerOutput(self, "WindAngle", WindAngle)
end

function ENT:UpdateOverlayText()
	local Wind = ACF.Wind or Vector(0, 0, 0)
	local WindSpeed = math.Round(Wind:Length(), 1)
	local WindAngle = Wind:Angle()

	local txt = "Wind Sensor"
	txt = txt .. "\n\nWind Direction: " .. math.Round(WindAngle.y, 1) .. "°"
	txt = txt .. "\nWind Speed: " .. WindSpeed .. " u/s"
	txt = txt .. " (" .. math.Round(WindSpeed / 39.37, 1) .. " m/s)"

	self:SetOverlayText(txt)
end

function ENT:Think()
	local curTime = CurTime()

	self:UpdateOutputs()
	self:UpdateOverlayText()

	self:NextThink(curTime + self.ThinkDelay)
	return true
end
