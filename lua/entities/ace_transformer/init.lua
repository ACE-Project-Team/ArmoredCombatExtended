AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain   = ACE.Sustain
local HeatLogic = Sustain.Heat
local PowerLogic = Sustain.Power

local MAX_LINKS = 6   -- NW slots (shares GL1..GLN with stations so beams render across types)

-- Classes this can be wired into as a grid neighbour (forward-compat with wires).
local GRID_NODES = {
	ace_transfer_station = true,
	ace_transformer      = true,
	ace_power_line       = true,
	ace_capacitor        = true,
}

function ENT:Initialize()
	self.GridStations    = {}          -- linked grid neighbours (stations / transformers)
	self.Voltage         = ACF.TransformerDefaultVoltage or 30   -- output (line) voltage it presents
	self.Throughput      = 0
	self.ThroughputAccum = 0
	self.Heat            = ACE.AmbientTemp or 20
	self.Tripped         = false
	self.Active          = true
	self.Legal           = true
	self.SpecialHealth   = true        -- ACF health = condition; torch repairs it
	self.IsScalable      = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
		"Voltage (output line voltage, 1-" .. (ACF.TransformerMaxVoltage or 100) .. ") [NORMAL]",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Voltage [NORMAL]",
		"Throughput (kW) [NORMAL]",
		"Capacity (kW) [NORMAL]",
		"Temperature (C) [NORMAL]",
		"Tripped (1 when overheated offline) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_Transformer(Owner, Pos, Angle, Id, Data1, Data2, Data3)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_transformer") then return false end

	local def = ACF.Weapons.Transformers[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Trans = ents.Create("ace_transformer")
	if not IsValid(Trans) then return false end

	Trans:SetAngles(Angle)
	Trans:SetPos(Pos)
	Trans:Spawn()

	local info = Sustain.ApplyShape(Trans, scaleVec, Data2, def)
	if not info then Trans:Remove() return false end

	Trans.Id        = Id
	Trans.SizeId    = Data1
	Trans.Shape     = Data2
	Trans.Voltage   = math.Clamp(math.floor(tonumber(Data3) or (ACF.TransformerDefaultVoltage or 30)), 1, ACF.TransformerMaxVoltage or 100)
	Trans.Ampacity  = info.volume * (ACF.TransformerAmpacityPerVolume or 0.0009)
	Trans.Mass      = math.max(info.volume * (ACF.TransformerMassPerVolume or 0.01), 5)
	Trans.ACEPoints = info.volume * (ACF.TransformerPointsPerVolume or 0.05)

	local phys = Trans:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(Trans.Mass) end
	Trans:ACF_Activate()

	Trans:SetColor(Color(95, 105, 125))   -- steel-blue by default
	Sustain.FinishSpawn(Trans, Owner, "_ace_transformer", def.name or "Transformer")

	Wire_TriggerOutput(Trans, "Voltage", Trans.Voltage)
	return Trans
end

list.Set("ACFCvars", "ace_transformer", {"id", "data1", "data2", "data3"})
duplicator.RegisterEntityClass("ace_transformer", MakeACE_Transformer, "Pos", "Angle", "Id", "SizeId", "Shape", "Voltage")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_Transformer, "Transformers")

------------------------------------------------------------------
-- Grid graph linking (undirected; shares the GL1..GLN networking with stations).
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

-- Leaf devices store the link on themselves; delegate so the link works no
-- matter which entity the player selected first with the link tool.
local LEAF_DEVICES = {
	ace_power_consumer  = true,
	ace_power_collector = true,
}

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if LEAF_DEVICES[Target:GetClass()] and Target.Link then return Target:Link(self) end
	if not GRID_NODES[Target:GetClass()] then
		return false, "Link another grid node (Transfer Station, Transformer)."
	end
	if Target == self then return false, "Can't link to itself!" end
	for _, S in ipairs(self.GridStations) do
		if S == Target then return false, "Already linked to that node!" end
	end
	if #self.GridStations >= (ACF.TransformerMaxLinks or MAX_LINKS) then
		return false, "This transformer already has the maximum number of links!"
	end
	local dist = self:GetPos():Distance(Target:GetPos())
	if dist > (ACF.TransformerLinkRange or 5000) then
		return false, "Too far (" .. math.Round(dist, 0) .. "u). Place a relay between them."
	end

	table.insert(self.GridStations, Target)
	if Target.GridStations then table.insert(Target.GridStations, self) end
	self:NetworkLinks()
	if Target.NetworkLinks then Target:NetworkLinks() end
	self:UpdateOverlayText()
	if Target.UpdateOverlayText then Target:UpdateOverlayText() end
	return true, "Linked into the grid."
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
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
		self:NetworkLinks()
		if Target.NetworkLinks then Target:NetworkLinks() end
		self:UpdateOverlayText()
		if Target.UpdateOverlayText then Target:UpdateOverlayText() end
		return true, "Unlinked."
	end
	return false, "That entity is not linked!"
end

------------------------------------------------------------------
-- Grid role interface (consumed by Sustain.GridPull / gridFindSource).
-- A transformer is a relay that re-references the line to its OUTPUT voltage and
-- whose throughput is capped by ampacity * voltage. It is never a source/sink.
------------------------------------------------------------------
function ENT:GridCapacity() return PowerLogic.Capacity(self.Ampacity or 0, self.Voltage or 1) end
function ENT:Offline()      return self.Tripped or self.BreakerOpen or not self.Active end
function ENT:IsSource()     return false end
function ENT:IsSink()       return false end
function ENT:IsRelay()      return not self:Offline() end
function ENT:GridHasEnergy() return false end

------------------------------------------------------------------
-- ACF health (condition) - torch-repairable, like the station.
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
	if iname == "Active" then
		self.Active = value ~= 0
		self:UpdateOverlayText()
	elseif iname == "Voltage" then
		self.Voltage = math.Clamp(math.floor(value or 1), 1, ACF.TransformerMaxVoltage or 100)
		Wire_TriggerOutput(self, "Voltage", self.Voltage)
		self:UpdateOverlayText()
	end
end

function ENT:UpdateOverlayText()
	local txt = "Transformer"
	if self.Tripped then txt = txt .. "  [TRIPPED - overheated]"
	elseif not self.Active then txt = txt .. "  [OFF]" end
	txt = txt .. "\nOutput Voltage: " .. (self.Voltage or 0)
	txt = txt .. "\nCapacity: " .. math.Round(self:GridCapacity(), 0) .. " kW   Throughput: " .. math.Round(self.Throughput or 0, 1) .. " kW"
	txt = txt .. "\nTemp: " .. math.Round(self.Heat or 0, 0) .. " C   Condition: " .. math.Round(self:HealthFrac() * 100, 0) .. "%"
	txt = txt .. "\nLinks: " .. #self.GridStations
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

	-- Throughput accumulated by GridPull this tick.
	local tp = self.ThroughputAccum
	self.ThroughputAccum = 0
	self.Throughput = tp

	-- Heat: the conversion loss becomes heat; overload past capacity heats hard.
	local cap   = self:GridCapacity()
	local heatJ = tp * (ACF.TransformerHeatPerKW or 6) * dt
	if cap > 0 and tp > cap then
		heatJ = heatJ + (tp - cap) * (ACF.TransformerHeatPerKW or 6) * (ACF.GridStationOverloadHeatMul or 6) * dt
	end
	self.Heat = HeatLogic.HeatStep(self.Heat, heatJ, self.Mass or 30, 1, ambient, dt)

	-- Overheating slowly cooks its condition.
	if self.Heat > (ACF.TransformerOverheatTemp or 150) and self.ACF and self.ACF.MaxHealth then
		self.ACF.Health = math.max(0, (self.ACF.Health or 0) - self.ACF.MaxHealth * (ACF.TransformerDamagePerSec or 0.03) * dt)
	end

	-- Trip / revive on condition.
	local hf = self:HealthFrac()
	if not self.Tripped and hf <= (ACF.TransformerTripHealth or 0.15) then
		self.Tripped = true
		self:EmitSound("ambient/energy/spark6.wav", 80, 80)
	elseif self.Tripped and hf >= (ACF.TransformerReviveHealth or 0.40) then
		self.Tripped = false
		self:EmitSound("buttons/combine_button1.wav", 70, 100)
	end

	-- Spark when hurting.
	if hf < 0.35 and CurTime() > (self.NextSparkFX or 0) then
		local fx = EffectData()
		fx:SetOrigin(self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z * 0.6)))
		fx:SetMagnitude(1) fx:SetScale(1) fx:SetRadius(8)
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
			energized   = Sustain.GridHasSource(self),
			overCurrent = overCurrent,
		})
	elseif self.FaultArc then
		Sustain.ClearFault(self)
	end

	Sustain.NetworkViz(self, {
		v = self.Voltage, kw = tp, cap = cap, heat = self.Heat,
		live = tp > 0,
		state = self.Tripped and 2 or (overCurrent > 0 and 1 or 0),
	})

	Wire_TriggerOutput(self, "Throughput", math.Round(tp, 2))
	Wire_TriggerOutput(self, "Capacity", math.Round(cap, 1))
	Wire_TriggerOutput(self, "Temperature", math.Round(self.Heat, 1))
	Wire_TriggerOutput(self, "Tripped", self.Tripped and 1 or 0)

	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:OnRemove()
	Sustain.ClearFault(self)
	for _, S in ipairs(self.GridStations) do
		if IsValid(S) and S.GridStations then
			for k = #S.GridStations, 1, -1 do
				if S.GridStations[k] == self then table.remove(S.GridStations, k) end
			end
			if S.NetworkLinks then S:NetworkLinks() end
		end
	end
end

do
	function ENT:PreEntityCopy()
		local nodes = {}
		for _, S in ipairs(self.GridStations) do
			if IsValid(S) then nodes[#nodes + 1] = S:EntIndex() end
		end
		duplicator.StoreEntityModifier(self, "TransformerLink", {
			voltage = self.Voltage,
			nodes   = nodes,
		})
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.TransformerLink then return end
		local info = Ent.EntityMods.TransformerLink
		if info.voltage then self.Voltage = info.voltage end
		for _, idx in ipairs(info.nodes or {}) do
			local S = CreatedEntities[idx]
			if IsValid(S) then self:Link(S) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.TransformerLink = nil
	end
end
