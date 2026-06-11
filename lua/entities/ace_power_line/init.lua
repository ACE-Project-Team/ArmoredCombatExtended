AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain    = ACE.Sustain
local HeatLogic  = Sustain.Heat
local PowerLogic = Sustain.Power

local MAX_LINKS = 6   -- shares GL1..GLN networking with stations/transformers

local GRID_NODES = {
	ace_transfer_station = true,
	ace_transformer      = true,
	ace_power_line       = true,
	ace_capacitor        = true,
}

function ENT:Initialize()
	self.GridStations    = {}          -- linked grid neighbours
	self.Voltage         = 0           -- line voltage it is CARRYING (path-based, from the solve)
	self._liveVoltage    = 0           -- carried voltage when live but idle (cached, throttled)
	self.Throughput      = 0
	self.ThroughputAccum = 0
	self.Heat            = ACE.AmbientTemp or 20
	self.Tripped         = false       -- "broken": stops carrying until torch-repaired
	self.Live            = false
	self.Legal           = true
	self.SpecialHealth   = true
	self.IsScalable      = true
	self.NextLiveCheck   = 0
	self.Resistivity     = ACF.PowerLineResistivity or 1.25

	-- A power line is always a live conductor (no Active input); breakers / damage
	-- are the only things that take it out of service.
	self.Outputs = WireLib.CreateOutputs(self, {
		"Live (1 when carrying power from a source) [NORMAL]",
		"Carrying (V) [NORMAL]",
		"Throughput (kW) [NORMAL]",
		"Capacity (kW) [NORMAL]",
		"Temperature (C) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_PowerLine(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_power_line") then return false end

	local def = ACF.Weapons.PowerLines[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Line = ents.Create("ace_power_line")
	if not IsValid(Line) then return false end

	Line:SetAngles(Angle)
	Line:SetPos(Pos)
	Line:Spawn()

	local info = Sustain.ApplyShape(Line, scaleVec, Data2, def)
	if not info then Line:Remove() return false end

	-- Cross-section = the two SHORTER dims (the conductor's gauge / diameter);
	-- length = the longest dim. Wider gauge carries more current; a longer or
	-- thinner run is more resistive. Robust to whichever axis the player made long.
	local d = info.dims
	local s1, s2, s3 = d.x, d.y, d.z
	if s1 > s2 then s1, s2 = s2, s1 end
	if s2 > s3 then s2, s3 = s3, s2 end
	if s1 > s2 then s1, s2 = s2, s1 end
	Line.XArea  = math.max(s1 * s2, 1)   -- cross-section (two shorter dims)
	Line.Length = math.max(s3, 1)        -- conductor length (longest dim)
	Line.Id          = Id
	Line.SizeId      = Data1
	Line.Shape       = Data2
	Line.Resistivity = ACF.PowerLineResistivity or 1.25
	Line.Ampacity    = Line.XArea * (ACF.PowerLineAmpacityPerArea or 0.06)
	Line.ConductorEff = 1   -- recomputed each Think from resistance / temp / carried voltage
	Line.Mass        = math.max(info.volume * (ACF.PowerLineMassPerVolume or 0.004), 2)
	Line.ACEPoints   = info.volume * (ACF.PowerLinePointsPerVolume or 0.02)

	local phys = Line:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(Line.Mass) end
	Line:ACF_Activate()

	Line:SetColor(Color(45, 45, 50))   -- dark cable by default (recolour with the colour tool)
	Sustain.FinishSpawn(Line, Owner, "_ace_power_line", def.name or "Power Line")
	return Line
end

list.Set("ACFCvars", "ace_power_line", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_power_line", MakeACE_PowerLine, "Pos", "Angle", "Id", "SizeId", "Shape")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_PowerLine, "PowerLines")

------------------------------------------------------------------
-- Grid graph linking (undirected; shares GL1..GLN with stations).
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
	if not GRID_NODES[Target:GetClass()] then
		return false, "Link a grid node (Transfer Station, Transformer, or another Power Line)."
	end
	if Target == self then return false, "Can't link to itself!" end
	for _, S in ipairs(self.GridStations) do
		if S == Target then return false, "Already linked to that node!" end
	end
	if #self.GridStations >= (ACF.PowerLineMaxLinks or MAX_LINKS) then
		return false, "This line already has the maximum number of links!"
	end
	local dist = self:GetPos():Distance(Target:GetPos())
	if dist > (ACF.PowerLineLinkRange or 1000) then
		return false, "Too far (" .. math.Round(dist, 0) .. "u). Chain another line segment between them."
	end

	table.insert(self.GridStations, Target)
	if Target.GridStations then table.insert(Target.GridStations, self) end
	self:NetworkLinks()
	if Target.NetworkLinks then Target:NetworkLinks() end
	self:UpdateOverlayText()
	if Target.UpdateOverlayText then Target:UpdateOverlayText() end
	return true, "Conductor linked into the grid."
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
-- Grid role interface. A power line is a CONDUCTOR: it carries power with no
-- DC<->AC conversion, only resistive/line loss. Never a source/sink/relay.
------------------------------------------------------------------
function ENT:Offline()       return self.Tripped or self.BreakerOpen end
function ENT:IsConductor()   return not self:Offline() end
function ENT:IsSource()      return false end
function ENT:IsSink()        return false end
function ENT:IsRelay()       return false end
function ENT:GridHasEnergy() return false end
function ENT:GridCapacity()  return PowerLogic.Capacity(self.Ampacity or 0, math.max(self.Voltage or 0, 1)) end

-- Carries power if it can reach an energised source through the grid.
function ENT:Energized() return not self:Offline() and Sustain.GridHasSource(self) end

------------------------------------------------------------------
-- ACF health (condition) - torch-repairable.
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

function ENT:UpdateOverlayText()
	local txt = "Power Line (conductor)"
	if self.Tripped then txt = txt .. "  [BROKEN]"
	elseif self.Shorted then txt = txt .. "  [SHORT CIRCUIT!]" end
	if self.Shorted then
		txt = txt .. "\n!! Massively overloaded (current far above ampacity) - trip a breaker / cut the link"
	end
	txt = txt .. "\n" .. (self.Live and "LIVE" or "no power") .. "   Carrying: " .. math.Round(self.Voltage or 0, 0) .. " V"
	txt = txt .. "\nCapacity: " .. math.Round(self:GridCapacity(), 0) .. " kW   Throughput: " .. math.Round(self.Throughput or 0, 1) .. " kW"
	-- Line loss is I^2*R: it's 0 with no current and grows with the power carried,
	-- so an idle line reads 0% even though it has resistance. Show the live loss and
	-- say so, so "0%" on an unused line isn't mistaken for a bug.
	local live = self.Live and (self.Throughput or 0) > 0.01
	txt = txt .. "\nLine loss: " .. math.Round((1 - (self.ConductorEff or 1)) * 100, 1) .. "%"
		.. (live and " (at this load)" or " (idle - rises with load)")
	txt = txt .. "\nTemp: " .. math.Round(self.Heat or 0, 0) .. " C   Condition: " .. math.Round(self:HealthFrac() * 100, 0) .. "%   Links: " .. #self.GridStations
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

	-- Snap links dragged past the link range (like ACF drivetrain links).
	Sustain.PruneStretchedLinks(self, self.GridStations, ACF.PowerLineLinkRange or 1000, "power line link")

	-- Path-based carried voltage. The grid solve stamps `_carryV` on this conductor
	-- when power flows through it (the source/transformer voltage on its segment);
	-- if it's live but idle, fall back to the cached path voltage. No peer-to-peer
	-- propagation, so it can't oscillate or "bridge mismatched potentials".
	self.Voltage   = self._carryV or self._liveVoltage or 0
	self._carryV   = nil

	-- Throughput accumulated by GridPull this tick.
	local tp = self.ThroughputAccum
	self.ThroughputAccum = 0
	self.Throughput = tp

	-- Resistive heat; overload past capacity heats hard.
	local cap   = self:GridCapacity()
	local heatJ = tp * (ACF.PowerLineHeatPerKW or 4) * dt
	if cap > 0 and tp > cap then
		heatJ = heatJ + (tp - cap) * (ACF.PowerLineHeatPerKW or 4) * (ACF.GridStationOverloadHeatMul or 6) * dt
	end

	-- Short circuit: a conductor carrying current far above its ampacity draws a
	-- runaway fault current that heats it almost instantly and should trip any
	-- breaker in the path. (Voltage is path-based now, so there is no longer a
	-- "bridging mismatched potentials" short - only genuine over-current.)
	local shortCond, faultKW, shortHeat = Sustain.Fault.Short({
		energized  = (self.Voltage or 0) > 0 and self.Live,
		capacityKW = cap,
		currentKW  = tp,
	})
	-- Inverse-time protection (like a real relay): a pure over-current is
	-- time-delayed so the line rides through inrush/transients instead of melting
	-- on a one-tick spike.
	local shorted
	if shortCond then
		self.ShortSince = self.ShortSince or CurTime()
		shorted = (CurTime() - self.ShortSince) >= (ACF.PowerLineShortHold or 0.4)
	else
		self.ShortSince = nil
		shorted = false
	end
	self.Shorted    = shorted
	self.ShortFault = faultKW
	if shorted then
		heatJ = heatJ + shortHeat * dt
		-- Trip a breaker anywhere in this conductor's chain (it's the protection).
		Sustain.TripChainBreakers(self)
		if CurTime() >= (self.NextShortFX or 0) then
			self.NextShortFX = CurTime() + 0.25
			self:EmitSound("ambient/energy/spark6.wav", 90, 70)
		end
	end

	-- The line loss isn't free: the power bled off as resistive loss is dissipated
	-- IN the conductor as heat. ConductorEff is last tick's loss fraction, so a
	-- heavily loaded low-voltage run (high loss) actually warms - the cue to step
	-- the voltage up. (gross = net / (1 - loss); the loss = gross - net.)
	local lossFrac = 1 - (self.ConductorEff or 1)
	if lossFrac > 0.001 and tp > 0 then
		local lossKW = tp * lossFrac / math.max(1 - lossFrac, 0.1)
		heatJ = heatJ + lossKW * (ACF.PowerLineHeatPerKW or 4) * dt
	end

	self.Heat = HeatLogic.HeatStep(self.Heat, heatJ, self.Mass or 5, 1, ambient, dt)

	-- Resistive loss for THIS hop: R = rho * length / cross-section, rising with
	-- temperature; loss falls with carried voltage^2 (so low-voltage runs bleed
	-- power - step up with a transformer). The grid traversal reads ConductorEff.
	self.Resistance   = PowerLogic.Resistance(self.Length or 1, self.XArea or 1, self.Resistivity or ACF.PowerLineResistivity or 1.25, self.Heat)
	-- Loss scales with the power carried (last tick's throughput), so a loaded
	-- line loses/heats more than an idle one.
	self.ConductorEff = 1 - PowerLogic.ResistiveLoss(self.Resistance, math.max(self.Voltage or 1, 1), self.Throughput or 0)

	-- Overheating cooks condition; a wire "breaks" (stops carrying) at low health.
	if self.Heat > (ACF.PowerLineOverheatTemp or 130) and self.ACF and self.ACF.MaxHealth then
		self.ACF.Health = math.max(0, (self.ACF.Health or 0) - self.ACF.MaxHealth * (ACF.PowerLineDamagePerSec or 0.03) * dt)
	end
	local hf = self:HealthFrac()
	if not self.Tripped and hf <= (ACF.PowerLineTripHealth or 0.10) then
		self.Tripped = true
		self:EmitSound("ambient/energy/spark6.wav", 80, 80)
	elseif self.Tripped and hf >= (ACF.PowerLineReviveHealth or 0.40) then
		self.Tripped = false
	end

	-- Live status + cached path voltage (throttled - the solve walks the graph).
	-- One query gives both whether a source is reachable and the voltage it puts on
	-- this conductor, so an idle-but-connected line still displays its voltage.
	if CurTime() >= self.NextLiveCheck then
		self.NextLiveCheck = CurTime() + 0.5
		self._liveVoltage = self:Offline() and 0 or Sustain.GridVoltage(self)
		self.Live = self._liveVoltage > 0
		self:SetNWBool("Live", self.Live)
	end

	-- Fault hazard: a broken-but-live wire or an overloaded one arcs. Only walk
	-- the grid when actually broken/overloaded (rare) - reuse the Live check.
	local overCurrent = (cap > 0) and math.max(tp - cap, 0) or 0
	if self.Tripped or overCurrent > 0 or self.Shorted then
		Sustain.UpdateFault(self, {
			voltage     = self.Voltage or 0,
			currentKW   = self.Shorted and (self.ShortFault or tp) or tp,
			broken      = self.Tripped,
			energized   = self.Tripped and Sustain.GridHasSource(self) or self.Live,
			-- A short is a severe over-current; feed the fault current so it both
			-- counts as a hazard and makes a nastier arc.
			overCurrent = self.Shorted and math.max((self.ShortFault or 0) - cap, overCurrent) or overCurrent,
		})
	elseif self.FaultArc then
		Sustain.ClearFault(self)
	end

	Sustain.NetworkViz(self, {
		v = self.Voltage, kw = tp, cap = cap, heat = self.Heat,
		live = self.Live,
		state = self.Tripped and 2 or ((overCurrent > 0 or self.Shorted) and 1 or 0),
	})

	Wire_TriggerOutput(self, "Live", self.Live and 1 or 0)
	Wire_TriggerOutput(self, "Carrying", math.Round(self.Voltage, 1))
	Wire_TriggerOutput(self, "Throughput", math.Round(tp, 2))
	Wire_TriggerOutput(self, "Capacity", math.Round(cap, 1))
	Wire_TriggerOutput(self, "Temperature", math.Round(self.Heat, 1))

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
		duplicator.StoreEntityModifier(self, "PowerLineLink", { nodes = nodes })
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.PowerLineLink then return end
		for _, idx in ipairs(Ent.EntityMods.PowerLineLink.nodes or {}) do
			local S = CreatedEntities[idx]
			if IsValid(S) then self:Link(S) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.PowerLineLink = nil
	end
end
