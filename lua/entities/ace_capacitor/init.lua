AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain   = ACE.Sustain
local HeatLogic = Sustain.Heat
local Battery   = Sustain.Battery

local MAX_LINKS = 6

local GRID_NODES = {
	ace_transfer_station = true,
	ace_transformer      = true,
	ace_power_line       = true,
	ace_capacitor        = true,
}

function ENT:Initialize()
	self.GridStations    = {}
	self.Voltage         = 0           -- carried line voltage (from neighbours)
	self.Charge          = 0           -- kWh stored
	self.Capacity        = 0.001       -- kWh (tiny; set from size at spawn)
	self.MaxRate         = 1           -- kW charge/discharge cap (high; set at spawn)
	self.Throughput      = 0
	self.ThroughputAccum = 0
	self.PendingHeatJ    = 0
	self.Heat            = ACE.AmbientTemp or 20
	self.Tripped         = false
	self.Active          = true
	self.Legal           = true
	self.SpecialHealth   = true
	self.IsScalable      = true
	self.GridSourceEff   = ACF.CapacitorEff or 0.97   -- discharge eff (grid grosses up by it)

	self.Inputs = WireLib.CreateInputs(self, { "Active" })
	self.Outputs = WireLib.CreateOutputs(self, {
		"Charge (kWh) [NORMAL]",
		"Throughput (kW) [NORMAL]",
		"Capacity (kW power cap) [NORMAL]",
		"Temperature (C) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

-- Optional prop models the player can pick instead of a plain scalable box.
-- Index 0 (or nil) = scalable box; the rest are spawned at natural size.
local CAP_MODELS = {
	["1"] = "models/props_c17/utilitypolemount01a.mdl",
	["2"] = "models/props_c17/utilityconnecter006b.mdl",
}

function MakeACE_Capacitor(Owner, Pos, Angle, Id, Data1, Data2, Data3)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_capacitor") then return false end

	local def = ACF.Weapons.Capacitors[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Cap = ents.Create("ace_capacitor")
	if not IsValid(Cap) then return false end

	Cap:SetAngles(Angle)
	Cap:SetPos(Pos)
	Cap:Spawn()

	-- Stats always come from the chosen box volume so they stay consistent
	-- whether or not the optional prop model is used.
	local L, W, H = scaleVec.x, scaleVec.y, scaleVec.z
	local boxMD   = ACE.ModelData["Box"]
	local vol     = boxMD and boxMD.volumefunction(L, W, H) or (L * W * H)

	local modelPath = CAP_MODELS[tostring(Data3 or "0")]
	if modelPath then
		-- Real prop at natural size (no SetModelScale - rescaling breaks physics).
		Cap:SetModel(modelPath)
		Cap:PhysicsInit(SOLID_VPHYSICS)
		Cap:SetMoveType(MOVETYPE_VPHYSICS)
		Cap:SetSolid(SOLID_VPHYSICS)
		local p = Cap:GetPhysicsObject()
		if IsValid(p) then p:Wake() end
		Cap.IsScalable = false
	else
		local info = Sustain.ApplyShape(Cap, scaleVec, Data2, def)
		if not info then Cap:Remove() return false end
		vol = info.volume
	end

	Cap.Id        = Id
	Cap.SizeId    = Data1
	Cap.Shape     = Data2
	Cap.ModelSel  = Data3 or "0"
	Cap.Capacity  = math.max(vol * (ACF.CapacitorEnergyPerVolume or 0.000015), 0.0005)
	Cap.MaxRate   = math.max(vol * (ACF.CapacitorRatePerVolume or 0.02), 1)
	Cap.Charge    = 0
	Cap.Mass      = math.max(vol * (ACF.CapacitorMassPerVolume or 0.006), 3)
	Cap.ACEPoints = vol * (ACF.CapacitorPointsPerVolume or 0.04)

	local phys = Cap:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(Cap.Mass) end
	Cap:ACF_Activate()

	Cap:SetColor(Color(70, 80, 120))   -- dark blue by default
	Sustain.FinishSpawn(Cap, Owner, "_ace_capacitor", def.name or "Capacitor")
	return Cap
end

list.Set("ACFCvars", "ace_capacitor", {"id", "data1", "data2", "data3"})
duplicator.RegisterEntityClass("ace_capacitor", MakeACE_Capacitor, "Pos", "Angle", "Id", "SizeId", "Shape", "ModelSel")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_Capacitor, "Capacitors")

------------------------------------------------------------------
-- Internal store (reuses the battery logic: rate cap + round-trip loss + heat,
-- but no wear and no CV taper - a capacitor charges/discharges fast and fully).
------------------------------------------------------------------
function ENT:Step(requestKWh, dt)
	local s = {
		baseCapacity  = self.Capacity, capacity = self.Capacity, charge = self.Charge,
		health = 1, cycleCount = 0, throughput = 0, maxChargeRate = self.MaxRate,
	}
	local r = Battery.Step(s, requestKWh, dt, {
		chargeEff = ACF.CapacitorEff or 0.97, degradePerCycle = 0,
		cvThreshold = 1,
		-- A capacitor's tiny capacity gives an enormous "C-rate", so use a small
		-- per-C heat term and a low clamp - capacitors run cool by design.
		heatPerC2 = 0.02, maxHeatW = 4000,
	})
	self.Charge = s.charge
	self.PendingHeatJ = (self.PendingHeatJ or 0) + (r.heatAddJ or 0)
	return r
end

------------------------------------------------------------------
-- Grid role: a source while it holds charge; it tops itself up from the grid.
------------------------------------------------------------------
function ENT:Offline()       return self.Tripped or self.BreakerOpen or not self.Active end
function ENT:IsSource()      return not self:Offline() and (self.Charge or 0) > 0 end
function ENT:IsSink()        return false end
function ENT:IsRelay()       return false end
function ENT:IsConductor()   return false end
function ENT:GridHasEnergy() return (self.Charge or 0) > 0 end
function ENT:GridCapacity()  return self.MaxRate or 0 end
-- A buffer, not a primary source: the grid serves loads from real generation/
-- storage first and only taps the capacitor for the spike they can't meet.
function ENT:GridSourcePriority() return ACF.GridBufferPriority or 1 end

function ENT:DrawEnergy(wantKWh, dt)
	if self:Offline() or wantKWh <= 0 or (self.Charge or 0) <= 0 then return 0 end
	local r = self:Step(-wantKWh, dt)
	return r.delivered or 0
end

------------------------------------------------------------------
-- Linking (shared GL graph with stations/transformers/wires).
------------------------------------------------------------------
function ENT:NetworkLinks()
	local n = 0
	for _, S in ipairs(self.GridStations) do
		if IsValid(S) and n < MAX_LINKS then n = n + 1 self:SetNWEntity("GL" .. n, S) end
	end
	self:SetNWInt("GLN", n)
end

local LEAF_DEVICES = {
	ace_power_consumer  = true,
	ace_power_collector = true,
}

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if LEAF_DEVICES[Target:GetClass()] and Target.Link then return Target:Link(self) end
	if not GRID_NODES[Target:GetClass()] then return false, "Link a grid node (station, transformer, power line, or capacitor)." end
	if Target == self then return false, "Can't link to itself!" end
	for _, S in ipairs(self.GridStations) do if S == Target then return false, "Already linked to that node!" end end
	if #self.GridStations >= MAX_LINKS then return false, "Maximum links reached!" end
	local dist = self:GetPos():Distance(Target:GetPos())
	if dist > (ACF.GridStationLinkRange or 5000) then
		return false, "Too far (" .. math.Round(dist, 0) .. "u)."
	end
	table.insert(self.GridStations, Target)
	if Target.GridStations then table.insert(Target.GridStations, self) end
	self:NetworkLinks()
	if Target.NetworkLinks then Target:NetworkLinks() end
	self:UpdateOverlayText()
	if Target.UpdateOverlayText then Target:UpdateOverlayText() end
	return true, "Capacitor linked into the grid."
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
		self:NetworkLinks() if Target.NetworkLinks then Target:NetworkLinks() end
		self:UpdateOverlayText() if Target.UpdateOverlayText then Target:UpdateOverlayText() end
		return true, "Unlinked."
	end
	return false, "That entity is not linked!"
end

------------------------------------------------------------------
-- ACF health (torch-repairable).
------------------------------------------------------------------
function ENT:ACF_Activate(Recalc)
	self.ACF = self.ACF or {}
	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end
	self.ACF.Area   = self.ACF.Area or (phys:GetSurfaceArea() * 6.45)
	self.ACF.Volume = self.ACF.Volume or (phys:GetVolume() * 16.38)
	local Health  = math.max((self.ACF.Volume / ACF.Threshold) / 20, 30)
	local Percent = 1
	if Recalc and self.ACF.Health and self.ACF.MaxHealth then Percent = self.ACF.Health / self.ACF.MaxHealth end
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
	if iname == "Active" then self.Active = value ~= 0 self:UpdateOverlayText() end
end

function ENT:UpdateOverlayText()
	local txt = "Capacitor (fast grid buffer)"
	if self.Tripped then txt = txt .. "  [BROKEN]" elseif not self.Active then txt = txt .. "  [OFF]" end
	txt = txt .. "\nCharge: " .. ACE.FormatEnergy(self.Charge or 0) .. " / " .. ACE.FormatEnergy(self.Capacity or 0)
	txt = txt .. "\nPower cap: " .. math.Round(self.MaxRate or 0, 0) .. " kW   Throughput: " .. math.Round(self.Throughput or 0, 1) .. " kW"
	txt = txt .. "\nTemp: " .. math.Round(self.Heat or 0, 0) .. " C   Condition: " .. math.Round(self:HealthFrac() * 100, 0) .. "%   Links: " .. #self.GridStations
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	local changed = false
	for k = #self.GridStations, 1, -1 do
		if not IsValid(self.GridStations[k]) then table.remove(self.GridStations, k) changed = true end
	end
	if changed then self:NetworkLinks() end

	-- Snap links dragged past the link range (like ACF drivetrain links).
	Sustain.PruneStretchedLinks(self, self.GridStations, ACF.GridStationLinkRange or 1500, "grid link")

	-- Carried line voltage = highest among neighbours.
	local v = 0
	for _, S in ipairs(self.GridStations) do if IsValid(S) and (S.Voltage or 0) > v then v = S.Voltage end end
	self.Voltage = v

	-- Recharge from the grid (ignoring our own store). It DISCHARGES at the full
	-- MaxRate to cover a spike, but REFILLS only at a gentle "trickle" fraction of it
	-- - sipping from spare capacity so topping itself up never spikes the line (a real
	-- super-capacitor smooths the battery's current, it doesn't add a peak). It's also
	-- the lowest-priority demander on the grid, so real loads are always served first.
	if not self:Offline() and (self.Charge or 0) < (self.Capacity or 0) then
		local room     = self.Capacity - self.Charge
		local rechRate = self.MaxRate * (ACF.CapacitorRechargeMul or 0.2)
		local want     = math.min(room, rechRate * dt / 3600)
		if want > 0 then
			local got = Sustain.GridPull(self, want, dt, true)   -- true = don't draw from self
			if got > 0 then self:Step(got, dt) end
		end
	end

	-- Throughput this tick (accumulated as source / refill node by GridPull).
	local tp = self.ThroughputAccum
	self.ThroughputAccum = 0
	self.Throughput = tp

	-- Heat: buffered conversion loss + a little resistive throughput heat.
	local heatJ = (self.PendingHeatJ or 0) + tp * (ACF.CapacitorHeatPerKW or 3) * dt
	self.PendingHeatJ = 0
	self.Heat = HeatLogic.HeatStep(self.Heat, heatJ, self.Mass or 5, 1, ambient, dt)

	-- Overheat -> condition damage -> trip (reuse station thresholds).
	if self.Heat > (ACF.GridStationOverheatTemp or 140) and self.ACF and self.ACF.MaxHealth then
		self.ACF.Health = math.max(0, (self.ACF.Health or 0) - self.ACF.MaxHealth * (ACF.GridStationDamagePerSec or 0.03) * dt)
	end
	local hf = self:HealthFrac()
	if not self.Tripped and hf <= (ACF.GridStationTripHealth or 0.15) then self.Tripped = true
	elseif self.Tripped and hf >= (ACF.GridStationReviveHealth or 0.40) then self.Tripped = false end

	-- Fault hazard when broken & still on a live grid, or overloaded.
	local overCurrent = (self.MaxRate > 0) and math.max(tp - self.MaxRate, 0) or 0
	if self.Tripped or overCurrent > 0 then
		Sustain.UpdateFault(self, {
			voltage = self.Voltage or 0, currentKW = tp, broken = self.Tripped,
			energized = Sustain.GridHasSource(self) or (self.Charge or 0) > 0, overCurrent = overCurrent,
		})
	elseif self.FaultArc then
		Sustain.ClearFault(self)
	end

	Sustain.NetworkViz(self, {
		v = self.Voltage, kw = tp, cap = self.MaxRate, heat = self.Heat,
		live = (self.Charge or 0) > 0,
		state = self.Tripped and 2 or (overCurrent > 0 and 1 or 0),
	})

	Wire_TriggerOutput(self, "Charge", math.Round(self.Charge or 0, 4))
	Wire_TriggerOutput(self, "Throughput", math.Round(tp, 2))
	Wire_TriggerOutput(self, "Capacity", math.Round(self.MaxRate or 0, 0))
	Wire_TriggerOutput(self, "Temperature", math.Round(self.Heat, 1))

	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.1)
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
		for _, S in ipairs(self.GridStations) do if IsValid(S) then nodes[#nodes + 1] = S:EntIndex() end end
		duplicator.StoreEntityModifier(self, "CapacitorLink", { nodes = nodes })
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.CapacitorLink then return end
		for _, idx in ipairs(Ent.EntityMods.CapacitorLink.nodes or {}) do
			local S = CreatedEntities[idx]
			if IsValid(S) then self:Link(S) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.CapacitorLink = nil
	end
end
