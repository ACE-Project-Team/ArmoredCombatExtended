AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain    = ACE.Sustain
local HeatLogic  = Sustain.Heat
local PowerLogic = Sustain.Power

local CONSUMER_MODEL = "models/props_c17/consolebox01a.mdl"

function ENT:Initialize()
	self.Station     = nil   -- grid tap (a transfer station) we pull through
	self.Battery     = nil   -- or a battery for a direct local load
	self.Draw        = ACF.ConsumerDefaultDraw or 20   -- kW wanted
	self.MinVoltage  = ACF.ConsumerMinVoltage or 0     -- volts required to run (0 = no requirement)
	self.RatedVoltage = ACF.ConsumerRatedVoltage or 120 -- operating voltage; above it the load overheats
	self.Supplied    = 0
	self.Voltage     = 0
	self.Powered     = false
	self.Active      = false   -- spawns OFF; draws no power until switched on
	self.Legal       = true
	self.IsScalable  = true
	self.SpecialHealth = true
	self.Heat        = ACE.AmbientTemp or 20
	self.Tripped     = false   -- cooked by sustained over-voltage; off until it cools

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
		"Draw (Desired load in kW) [NORMAL]",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Powered (1 when fully supplied at sufficient voltage) [NORMAL]",
		"Supplied (kW actually received) [NORMAL]",
		"Shortfall (kW not met) [NORMAL]",
		"Voltage (V delivered) [NORMAL]",
		"Temperature (C) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_PowerConsumer(Owner, Pos, Angle, Id, Data1, Data2, Data3)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_power_consumer") then return false end

	local def = ACF.Weapons.Consumers[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Cons = ents.Create("ace_power_consumer")
	if not IsValid(Cons) then return false end

	Cons:SetAngles(Angle)
	Cons:SetPos(Pos)
	Cons:Spawn()

	local L, W, H = scaleVec.x, scaleVec.y, scaleVec.z
	local boxMD = ACE.ModelData["Box"]
	local vol = boxMD and boxMD.volumefunction(L, W, H) or (L * W * H)

	local useModel = Data3 == "1"
	if useModel then
		-- Optional real prop model at its natural size (no SetModelScale).
		Cons:SetModel(CONSUMER_MODEL)
		Cons:PhysicsInit(SOLID_VPHYSICS)
		Cons:SetMoveType(MOVETYPE_VPHYSICS)
		Cons:SetSolid(SOLID_VPHYSICS)
		local p = Cons:GetPhysicsObject()
		if IsValid(p) then p:Wake() end
		Cons.IsScalable = false
	else
		local info = Sustain.ApplyShape(Cons, scaleVec, Data2, def)
		if not info then Cons:Remove() return false end
	end

	Cons.Id         = Id
	Cons.SizeId     = Data1
	Cons.Shape      = Data2
	Cons.UseModel   = useModel
	Cons.Dimensions = Vector(L, W, H)
	Cons.Mass       = math.max(vol * 0.002, 5)
	Cons.ACEPoints  = vol * 0.01

	-- Default load scales with the build size (bigger appliance = bigger load):
	-- a small box ~ a house, a large one ~ a small factory. The "Draw" wire input
	-- overrides this; clearing it (0) falls back to the size-based load.
	Cons.BaseDraw   = math.max(vol * (ACF.ConsumerDrawPerVolume or 0.02), 0.1)
	Cons.Draw       = Cons.BaseDraw

	local phys = Cons:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(Cons.Mass) end
	Cons:ACF_Activate()

	Sustain.FinishSpawn(Cons, Owner, "_ace_power_consumer", def.name or "Power Consumer")
	return Cons
end

list.Set("ACFCvars", "ace_power_consumer", {"id", "data1", "data2", "data3"})
duplicator.RegisterEntityClass("ace_power_consumer", MakeACE_PowerConsumer, "Pos", "Angle", "Id", "SizeId", "Shape", "UseModel")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_PowerConsumer, "Consumers")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	local cls = Target:GetClass()
	if cls == "ace_transfer_station" or cls == "ace_transformer" or cls == "ace_power_line" or cls == "ace_capacitor" then
		local dist = self:GetPos():Distance(Target:GetPos())
		if dist > (ACF.GridStationLinkRange or 800) then
			return false, "Too far (" .. math.Round(dist, 0) .. "u). Move the consumer closer to the node."
		end
		self.Station = Target
		self:UpdateOverlayText()
		return true, "Tapped into the grid at that node (its voltage is what this load sees)."
	end
	if cls == "acf_fueltank" and Target.FuelType == "Electric" then
		self.Battery = Target
		self:UpdateOverlayText()
		return true, "Linked directly to a battery."
	end
	return false, "Link a grid node (Transfer Station, Transformer, Power Line, Capacitor) or an Electric battery (local)."
end

function ENT:Unlink(Target)
	if IsValid(Target) and Target == self.Station then self.Station = nil self:UpdateOverlayText() return true, "Unlinked from grid." end
	if IsValid(Target) and Target == self.Battery then self.Battery = nil self:UpdateOverlayText() return true, "Unlinked from battery." end
	return false, "That entity is not linked!"
end

------------------------------------------------------------------
-- ACF health (condition) - so sustained over-voltage can cook it.
------------------------------------------------------------------
function ENT:ACF_Activate(Recalc)
	self.ACF = self.ACF or {}
	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end

	self.ACF.Area   = self.ACF.Area or (phys:GetSurfaceArea() * 6.45)
	self.ACF.Volume = self.ACF.Volume or (phys:GetVolume() * 16.38)

	local Health  = math.max((self.ACF.Volume / ACF.Threshold) / 20, 25)
	local Percent = 1
	if Recalc and self.ACF.Health and self.ACF.MaxHealth then
		Percent = self.ACF.Health / self.ACF.MaxHealth
	end

	self.ACF.Health    = Health * Percent
	self.ACF.MaxHealth = Health
	local Armour = (phys:GetMass() * 1000 / self.ACF.Area / 0.78)
	self.ACF.Armour    = math.max(Armour, 1) * (0.5 + Percent / 2)
	self.ACF.MaxArmour = math.max(Armour, 1)
	self.ACF.Type      = "Prop"
	self.ACF.Mass      = self.Mass
	self.ACF.Material  = self.ACF.Material or "RHA"
end

function ENT:HealthFrac()
	if not self.ACF or not self.ACF.MaxHealth or self.ACF.MaxHealth <= 0 then return 1 end
	return math.Clamp((self.ACF.Health or 0) / self.ACF.MaxHealth, 0, 1)
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then
		self.Active = value ~= 0
	elseif iname == "Draw" then
		-- A positive value overrides the size-based load; 0/blank reverts to it.
		local v = value or 0
		self.Draw = (v > 0) and v or (self.BaseDraw or ACF.ConsumerDefaultDraw or 20)
	end
end

function ENT:UpdateOverlayText()
	local txt = "Power Consumer"
	local src = IsValid(self.Station) and "grid" or (IsValid(self.Battery) and "battery" or "MISSING")
	txt = txt .. "\nSource: " .. src
	txt = txt .. "\nDraw: " .. math.Round(self.Draw or 0, 1) .. " kW"
	txt = txt .. "\nSupplied: " .. math.Round(self.Supplied or 0, 1) .. " kW"
	txt = txt .. "\nVoltage: " .. math.Round(self.Voltage or 0, 0) .. " V"
		.. "  (rated " .. math.Round(self.RatedVoltage or 0, 0)
		.. (((self.MinVoltage or 0) > 0) and (", min " .. math.Round(self.MinVoltage, 0)) or "") .. ")"
	local status
	if self.Tripped then status = "COOKED (over-voltage) - cooling down"
	elseif self.Powered then status = "POWERED"
	elseif (self.MinVoltage or 0) > 0 and (self.Supplied or 0) > 0 and (self.Voltage or 0) < self.MinVoltage then status = "UNDER-VOLTAGE"
	else status = "under-supplied" end
	if (self.Voltage or 0) > (self.RatedVoltage or 0) then status = status .. "  !! OVER-VOLTAGE - overheating" end
	txt = txt .. "\n" .. status
	txt = txt .. "\nTemp: " .. math.Round(self.Heat or 0, 0) .. " C   Condition: " .. math.Round(self:HealthFrac() * 100, 0) .. "%"
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()
	self.Supplied = 0
	self.Voltage  = 0
	self.Powered  = false

	-- Snap a grid tap dragged out of range (like ACF drivetrain links). The local
	-- battery link is left alone - it's a direct on-build connection, not a run.
	if IsValid(self.Station) then
		local maxD2 = ((ACF.GridStationLinkRange or 800) * (ACF.LinkStretchMul or 1.5)) ^ 2
		if self:GetPos():DistToSqr(self.Station:GetPos()) > maxD2 then
			local owner = self.CPPIGetOwner and self:CPPIGetOwner()
			self.Station = nil
			self:UpdateOverlayText()
			if IsValid(owner) then owner:ChatPrint("ACE: the consumer's grid link snapped - dragged too far from the node.") end
		end
	end

	-- A cooked appliance stays off until it has cooled back down (torch repair not
	-- required - it's a thermal trip, not physical breakage).
	if self.Active and not self.Tripped and self.Draw > 0 then
		local want = self.Draw * dt / 3600
		local got, volts = 0, 0
		if IsValid(self.Station) then
			got, volts = Sustain.GridPull(self.Station, want, dt)
		elseif IsValid(self.Battery) and self.Battery.DrawEnergy then
			got   = self.Battery:DrawEnergy(want, dt) or 0
			-- A raw battery is low-voltage DC; it can't satisfy a high-Vmin load.
			volts = (got > 0) and (ACF.BatteryNominalVoltage or 1) or 0
		end
		volts = volts or 0
		self.Supplied = got / math.max(dt / 3600, 1e-9)
		self.Voltage  = volts
		self.Powered  = self.Supplied >= self.Draw * 0.99 and volts >= (self.MinVoltage or 0)
	end

	-- Over-voltage overheats the load: delivered voltage above its rating stresses
	-- it (Breakdown), heating in proportion to the power it's pulling; sustained
	-- overheat cooks its condition until it thermally trips. Step the supply down
	-- with a transformer to keep it in spec. Heat bleeds back to ambient when safe.
	local ambient   = ACE.AmbientTemp or 20
	local breakdown = PowerLogic.Breakdown(self.Voltage or 0, self.RatedVoltage or 1)
	local heatJ     = PowerLogic.OverVoltageHeat(breakdown, self.Supplied or 0) * dt
	self.Heat = HeatLogic.HeatStep(self.Heat, heatJ, self.Mass or 5, 1, ambient, dt)

	if self.Heat > (ACF.ConsumerOverheatTemp or 130) and self.ACF and self.ACF.MaxHealth then
		self.ACF.Health = math.max(0, (self.ACF.Health or 0) - self.ACF.MaxHealth * (ACF.ConsumerDamagePerSec or 0.03) * dt)
	end
	local hf = self:HealthFrac()
	if not self.Tripped and (hf <= (ACF.ConsumerTripHealth or 0.10) or self.Heat > (ACF.ConsumerTripTemp or 200)) then
		self.Tripped = true
		self.Powered = false
		self:EmitSound("ambient/energy/spark6.wav", 80, 80)
	elseif self.Tripped and hf >= (ACF.ConsumerReviveHealth or 0.40) and self.Heat <= ambient + 15 then
		self.Tripped = false
	end

	-- Publish readouts + links so the ACE Grid Tool shows the load and the power
	-- flowing into it (a consumer is a leaf, not a graph node, so without this the
	-- overlay couldn't see it at all).
	local overVolt = (self.Voltage or 0) > (self.RatedVoltage or math.huge)
	Sustain.NetworkViz(self, {
		v = self.Voltage, kw = self.Supplied, cap = self.Draw, heat = self.Heat,
		live = self.Powered,
		state = self.Tripped and 2 or (overVolt and 1 or 0),
		role = "load",
	})
	local aux = {}
	if IsValid(self.Station) then aux[#aux + 1] = { ent = self.Station, label = "grid", into = true } end
	if IsValid(self.Battery) then aux[#aux + 1] = { ent = self.Battery, label = "battery", into = true } end
	Sustain.NetworkAux(self, aux)

	WireLib.TriggerOutput(self, "Powered", self.Powered and 1 or 0)
	WireLib.TriggerOutput(self, "Supplied", math.Round(self.Supplied, 2))
	WireLib.TriggerOutput(self, "Shortfall", math.Round(math.max(self.Draw - self.Supplied, 0), 2))
	WireLib.TriggerOutput(self, "Voltage", math.Round(self.Voltage, 2))
	WireLib.TriggerOutput(self, "Temperature", math.Round(self.Heat, 1))
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

do
	function ENT:PreEntityCopy()
		duplicator.StoreEntityModifier(self, "ConsumerLink", {
			station = IsValid(self.Station) and self.Station:EntIndex() or nil,
			battery = IsValid(self.Battery) and self.Battery:EntIndex() or nil,
			draw    = self.Draw,
		})
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.ConsumerLink then return end
		local info = Ent.EntityMods.ConsumerLink
		if info.draw then self.Draw = info.draw end
		if info.station then
			local S = CreatedEntities[info.station]
			if IsValid(S) then self:Link(S) end
		end
		if info.battery then
			local B = CreatedEntities[info.battery]
			if IsValid(B) then self:Link(B) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.ConsumerLink = nil
	end
end
