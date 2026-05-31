AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain   = ACE.Sustain
local HeatLogic = Sustain.Heat

local MODE_IDLE, MODE_SOURCE, MODE_SINK, MODE_RELAY = 0, 1, 2, 3
local MAX_LINKS = 6   -- mirrors ACF.GridStationMaxLinks for the NW slots

-- Other grid nodes a station can wire into (the homogeneous grid graph).
local GRID_NODES = {
	ace_transfer_station = true,
	ace_transformer      = true,
	ace_power_line       = true,
	ace_capacitor        = true,
}

function ENT:Initialize()
	self.GridStations  = {}            -- directly-linked neighbour nodes (the graph)
	self.Battery       = nil           -- linked Electric battery (DC side)
	self.Mode          = MODE_IDLE
	self.Voltage       = ACF.GridStationDefaultVoltage or 5
	self.CapacityKW    = 0             -- build-fixed throughput capacity (set from size at spawn)
	self.Phases        = 1             -- 1 = single-phase, 3 = three-phase (more capacity, cooler)
	self.Throughput    = 0             -- kW currently moving through (last tick)
	self.ThroughputAccum = 0           -- accumulated by Sustain.GridPull during a tick
	self.Heat          = ACE.AmbientTemp or 20
	self.Tripped       = false
	self.Legal         = true
	self.SpecialHealth = true          -- ACF health = condition; torch repairs it
	self.IsScalable    = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Mode (0 idle, 1 source -> grid, 2 sink <- grid, 3 relay) [NORMAL]",
		"Voltage (1-" .. (ACF.GridStationMaxVoltage or 10) .. ", higher = less line loss but more heat; capacity is set by size) [NORMAL]",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Mode [NORMAL]",
		"Voltage [NORMAL]",
		"Throughput (kW) [NORMAL]",
		"Energized (1 when live on the grid) [NORMAL]",
		"Temperature (C) [NORMAL]",
		"Tripped (1 when overheated offline) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_TransferStation(Owner, Pos, Angle, Id, Data1, Data2, Data3, Data4)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_transfer_station") then return false end

	local def = ACF.Weapons.TransferStations[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Station = ents.Create("ace_transfer_station")
	if not IsValid(Station) then return false end

	Station:SetAngles(Angle)
	Station:SetPos(Pos)
	Station:Spawn()

	local info = Sustain.ApplyShape(Station, scaleVec, Data2, def)
	if not info then Station:Remove() return false end

	Station.Id         = Id
	Station.SizeId     = Data1
	Station.Shape      = Data2
	-- Capacity is fixed by the hardware's size; voltage only trades line loss vs heat.
	Station.CapacityKW = info.volume * (ACF.GridStationCapacityPerVolume or 0.0056)
	Station.Voltage    = math.Clamp(math.floor(tonumber(Data3) or (ACF.GridStationDefaultVoltage or 5)), 1, ACF.GridStationMaxVoltage or 10)
	Station.Phases     = (tostring(Data4) == "3") and 3 or 1
	Station.Mass       = math.max(info.volume * 0.0025, 20)
	Station.ACEPoints  = info.volume * 0.02

	local phys = Station:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(Station.Mass) end
	Station:ACF_Activate()

	Station:SetColor(Color(70, 95, 80))   -- dark green by default
	Sustain.FinishSpawn(Station, Owner, "_ace_transfer_station", def.name or "Transfer Station")

	Wire_TriggerOutput(Station, "Voltage", Station.Voltage)
	return Station
end

list.Set("ACFCvars", "ace_transfer_station", {"id", "data1", "data2", "data3", "data4"})
duplicator.RegisterEntityClass("ace_transfer_station", MakeACE_TransferStation, "Pos", "Angle", "Id", "SizeId", "Shape", "Voltage", "Phases")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_TransferStation, "TransferStations")

------------------------------------------------------------------
-- Linking: a battery (DC side) OR another station (the grid graph).
------------------------------------------------------------------
function ENT:NetworkLinks()
	local n = 0
	for _, S in ipairs(self.GridStations) do
		if IsValid(S) and n < MAX_LINKS then
			n = n + 1
			self:SetNWEntity("GL" .. n, S)
		end
	end
	self:SetNWInt("GLN", n)
end

-- Leaf devices (consumer/collector) store the link on themselves; delegate so
-- linking works regardless of which entity the player picked first.
local LEAF_DEVICES = {
	ace_power_consumer  = true,
	ace_power_collector = true,
}

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if LEAF_DEVICES[Target:GetClass()] and Target.Link then return Target:Link(self) end

	if GRID_NODES[Target:GetClass()] then
		if Target == self then return false, "Can't link a station to itself!" end
		for _, S in ipairs(self.GridStations) do
			if S == Target then return false, "Already linked to that node!" end
		end
		if #self.GridStations >= (ACF.GridStationMaxLinks or MAX_LINKS) then
			return false, "This station already has the maximum number of links!"
		end
		local dist = self:GetPos():Distance(Target:GetPos())
		if dist > (ACF.GridStationLinkRange or 5000) then
			return false, "Too far (" .. math.Round(dist, 0) .. "u). Place a relay between them."
		end
		-- Link both ways so the graph is undirected (works for any grid node).
		table.insert(self.GridStations, Target)
		if Target.GridStations then table.insert(Target.GridStations, self) end
		self:NetworkLinks()
		if Target.NetworkLinks then Target:NetworkLinks() end
		self:UpdateOverlayText()
		if Target.UpdateOverlayText then Target:UpdateOverlayText() end
		return true, "Linked into the grid."
	end

	if Target:GetClass() == "acf_fueltank" then
		if Target.FuelType ~= "Electric" then return false, "Stations only work with Electric batteries!" end
		self.Battery = Target
		self:UpdateOverlayText()
		return true, "Battery linked (the station's DC side)."
	end

	return false, "Link an Electric battery, or another Transfer Station."
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end

	if GRID_NODES[Target:GetClass()] then
		local removed = false
		for k = #self.GridStations, 1, -1 do
			if self.GridStations[k] == Target then table.remove(self.GridStations, k) removed = true end
		end
		if Target.GridStations then
			for k = #Target.GridStations, 1, -1 do
				if Target.GridStations[k] == self then table.remove(Target.GridStations, k) end
			end
		end
		if removed then
			self:NetworkLinks() if Target.NetworkLinks then Target:NetworkLinks() end
			self:UpdateOverlayText() if Target.UpdateOverlayText then Target:UpdateOverlayText() end
			return true, "Unlinked from the grid."
		end
	end

	if Target == self.Battery then
		self.Battery = nil
		self:UpdateOverlayText()
		return true, "Battery unlinked."
	end

	return false, "That entity is not linked!"
end

------------------------------------------------------------------
-- Grid role interface (used by Sustain.GridPull).
------------------------------------------------------------------
function ENT:GridCapacity()
	return (self.CapacityKW or 0) * (self.Phases == 3 and (ACF.GridStation3PhaseMul or 1.732) or 1)
end
-- Offline if thermally tripped OR a linked breaker has opened this station.
function ENT:Offline()   return self.Tripped or self.BreakerOpen end
function ENT:IsSource()  return not self:Offline() and self.Mode == MODE_SOURCE and IsValid(self.Battery) end
function ENT:IsSink()    return not self:Offline() and self.Mode == MODE_SINK   and IsValid(self.Battery) end
function ENT:IsRelay()   return not self:Offline() and self.Mode == MODE_RELAY end
function ENT:GridHasEnergy() return IsValid(self.Battery) and (self.Battery.Fuel or 0) > 0 end

-- A source's battery is what the traversal draws from.
function ENT:DrawEnergy(wantKWh, dt)
	if not IsValid(self.Battery) or not self.Battery.DrawEnergy then return 0 end
	return self.Battery:DrawEnergy(wantKWh, dt) or 0
end

function ENT:Energized()
	return (self:IsSource() and self:GridHasEnergy()) or false
end

------------------------------------------------------------------
-- ACF health (condition) - torch-repairable, like the pipe.
------------------------------------------------------------------
function ENT:ACF_Activate(Recalc)
	self.ACF = self.ACF or {}
	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end

	self.ACF.Area   = self.ACF.Area or (phys:GetSurfaceArea() * 6.45)
	self.ACF.Volume = self.ACF.Volume or (phys:GetVolume() * 16.38)

	local Health  = math.max((self.ACF.Volume / ACF.Threshold) / 20, 50)
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
	if iname == "Mode" then
		local m = math.Clamp(math.floor(value or 0), MODE_IDLE, MODE_RELAY)
		if m ~= self.Mode then
			self.Mode = m
			self:EmitSound("buttons/lever" .. math.random(1, 6) .. ".wav", 60, 100)
		end
		self:UpdateOverlayText()
	elseif iname == "Voltage" then
		self.Voltage = math.Clamp(math.floor(value or 1), 1, ACF.GridStationMaxVoltage or 10)
		Wire_TriggerOutput(self, "Voltage", self.Voltage)
		self:UpdateOverlayText()
	end
end

local MODE_NAME = { [0] = "Idle", [1] = "Source", [2] = "Sink", [3] = "Relay" }

function ENT:UpdateOverlayText()
	local txt = "Transfer Station"
	if self.Tripped then txt = txt .. "  [TRIPPED - overheated]" end
	txt = txt .. "\nMode: " .. (MODE_NAME[self.Mode] or "?") .. "   Voltage: " .. (self.Voltage or 0) .. "   " .. (self.Phases == 3 and "3-phase" or "1-phase")
	txt = txt .. "\nCapacity: " .. math.Round(self:GridCapacity(), 0) .. " kW   Throughput: " .. math.Round(self.Throughput or 0, 1) .. " kW"
	txt = txt .. "\nTemp: " .. math.Round(self.Heat or 0, 0) .. " C   Condition: " .. math.Round(self:HealthFrac() * 100, 0) .. "%"
	txt = txt .. "\nBattery: " .. (IsValid(self.Battery) and "linked" or "MISSING") .. "   Links: " .. #self.GridStations
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	-- Drop deleted neighbour links.
	local changed = false
	for k = #self.GridStations, 1, -1 do
		if not IsValid(self.GridStations[k]) then table.remove(self.GridStations, k) changed = true end
	end
	if changed then self:NetworkLinks() end

	-- A sink charges its battery by pulling through the grid.
	if self:IsSink() then
		local want = self:GridCapacity() * dt / 3600
		local got  = Sustain.GridPull(self, want, dt)
		if got > 0 and IsValid(self.Battery) and self.Battery.ChargeBattery then
			self.Battery:ChargeBattery(got * (1 - (Sustain.Grid.ConvLoss or 0.04)), dt)
		end
	end

	-- Throughput accumulated by GridPull this tick (as source/relay/sink node).
	local tp = self.ThroughputAccum
	self.ThroughputAccum = 0
	self.Throughput = tp

	-- Heat: the conversion loss becomes heat; overload past capacity heats hard.
	local cap     = self:GridCapacity()
	local heatJ   = tp * (ACF.GridStationHeatPerKW or 9) * dt
	if tp > cap then
		heatJ = heatJ + (tp - cap) * (ACF.GridStationHeatPerKW or 9) * (ACF.GridStationOverloadHeatMul or 6) * dt
	end
	if self.Phases == 3 then heatJ = heatJ * (ACF.GridStation3PhaseHeatMul or 0.6) end   -- smoother delivery = cooler
	self.Heat = HeatLogic.HeatStep(self.Heat, heatJ, self.Mass or 60, 1, ambient, dt)

	-- Overheating slowly cooks the station's health.
	if self.Heat > (ACF.GridStationOverheatTemp or 140) and self.ACF and self.ACF.MaxHealth then
		self.ACF.Health = math.max(0, (self.ACF.Health or 0) - self.ACF.MaxHealth * (ACF.GridStationDamagePerSec or 0.03) * dt)
	end

	-- Trip / revive on condition.
	local hf = self:HealthFrac()
	if not self.Tripped and hf <= (ACF.GridStationTripHealth or 0.15) then
		self.Tripped = true
		self:EmitSound("ambient/energy/spark6.wav", 80, 80)
	elseif self.Tripped and hf >= (ACF.GridStationReviveHealth or 0.40) then
		self.Tripped = false
		self:EmitSound("buttons/combine_button1.wav", 70, 100)
	end

	-- Spark when it's hurting (low condition), a bit more often if tripped.
	if hf < 0.35 and CurTime() > (self.NextSparkFX or 0) then
		local fx = EffectData()
		fx:SetOrigin(self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z * 0.6)))
		fx:SetMagnitude(1)
		fx:SetScale(1)
		fx:SetRadius(8)
		util.Effect("Sparks", fx)
		self.NextSparkFX = CurTime() + (self.Tripped and math.Rand(0.6, 1.4) or math.Rand(1.5, 3.5))
	end

	-- Fault hazard: only walk the grid when actually broken or overloaded (rare).
	local overCurrent = (cap > 0) and math.max(tp - cap, 0) or 0
	if self.Tripped or overCurrent > 0 then
		Sustain.UpdateFault(self, {
			voltage     = self.Voltage or 0,
			currentKW   = tp,
			broken      = self.Tripped,
			energized   = self.Tripped and Sustain.GridHasSource(self) or (tp > 0),
			overCurrent = overCurrent,
		})
	elseif self.FaultArc then
		Sustain.ClearFault(self)
	end

	Sustain.NetworkViz(self, {
		v = self.Voltage, kw = tp, cap = cap, heat = self.Heat,
		live = self:Energized() or (tp > 0),
		state = self.Tripped and 2 or (overCurrent > 0 and 1 or 0),
	})

	Wire_TriggerOutput(self, "Mode", self.Mode)
	Wire_TriggerOutput(self, "Throughput", math.Round(tp, 2))
	Wire_TriggerOutput(self, "Energized", self:Energized() and 1 or 0)
	Wire_TriggerOutput(self, "Temperature", math.Round(self.Heat, 1))
	Wire_TriggerOutput(self, "Tripped", self.Tripped and 1 or 0)

	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:OnRemove()
	Sustain.ClearFault(self)
	-- Detach from neighbours so they don't keep a stale link.
	for _, S in ipairs(self.GridStations) do
		if IsValid(S) then
			for k = #S.GridStations, 1, -1 do
				if S.GridStations[k] == self then table.remove(S.GridStations, k) end
			end
			if S.NetworkLinks then S:NetworkLinks() end
		end
	end
end

do
	function ENT:PreEntityCopy()
		local stations = {}
		for _, S in ipairs(self.GridStations) do
			if IsValid(S) then stations[#stations + 1] = S:EntIndex() end
		end
		duplicator.StoreEntityModifier(self, "StationLink", {
			battery  = IsValid(self.Battery) and self.Battery:EntIndex() or nil,
			mode     = self.Mode,
			voltage  = self.Voltage,
			stations = stations,
		})
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.StationLink then return end
		local info = Ent.EntityMods.StationLink
		if info.mode then self.Mode = info.mode end
		if info.voltage then self.Voltage = info.voltage end
		if info.battery then
			local B = CreatedEntities[info.battery]
			if IsValid(B) and B:GetClass() == "acf_fueltank" then self:Link(B) end
		end
		for _, idx in ipairs(info.stations or {}) do
			local S = CreatedEntities[idx]
			if IsValid(S) and S:GetClass() == "ace_transfer_station" then self:Link(S) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.StationLink = nil
	end
end
