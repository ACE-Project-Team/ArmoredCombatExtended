-- OIL PUMP (class name "field generator" is historical: it works an oil FIELD,
-- it does not generate power): electricity IN -> crude oil OUT of the ground,
-- only while grounded. The START of the oil chain - its crude goes to an Oil
-- tank or down pipes, then through ace_refinery to become engine fuel.

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain    = ACE.Sustain
local SynthLogic = Sustain.Synth
local HeatLogic  = Sustain.Heat
local PowerLogic = Sustain.Power

local THUMP_SOUND = "ambient/machines/thumper_hit.wav"

function ENT:Initialize()
	self.FuelLink    = {}    -- liquid tanks we fill (direct links)
	self.PipeLinks   = {}    -- pipes/pumps we feed into (oil flows through the network)
	self.Battery     = nil   -- Electric tank powering the pump (direct), OR...
	self.Station     = nil   -- ...a grid node we tap for power
	self.Active      = false -- off until switched on (wire Active, or USE key)
	self.Grounded    = false
	self.FuelRate    = 0
	self.PowerNeed   = 0     -- kW its pump needs to run at full rate (set in Make)
	self.PowerFrac   = 0     -- 0..1 fraction of that need currently met
	self.Voltage     = 0
	self.RatedVoltage = ACF.FieldGenRatedVoltage or 60
	self.Heat        = ACE.AmbientTemp or 20
	self.NextThump   = 0
	self.NextGroundCheck = 0
	self.Legal       = true
	self.IsScalable  = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Fuel Rate (Litres/sec) [NORMAL]",
		"Heat (C) [NORMAL]",
		"Grounded (1 when sitting on the ground) [NORMAL]",
		"Powered (1 when its pump has the electricity to run) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_FieldGenerator(Owner, Pos, Angle, Id, Data1, Data2, Data3)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_field_generator") then return false end

	local def = ACF.Weapons.FieldGenerators[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Gen = ents.Create("ace_field_generator")
	if not IsValid(Gen) then return false end

	Gen:SetAngles(Angle)
	Gen:SetPos(Pos)
	Gen:Spawn()

	-- Stats always come from the chosen box volume so they stay consistent
	-- whether or not the optional thumper model is used.
	local L, W, H = scaleVec.x, scaleVec.y, scaleVec.z
	local boxMD = ACE.ModelData["Box"]
	local vol = boxMD and boxMD.volumefunction(L, W, H) or (L * W * H)

	local useThumper = Data3 == "1"
	if useThumper then
		-- Optional real prop model at its NATURAL size. We deliberately do not
		-- SetModelScale it: rescaling here left the entity with a mismatched/invalid
		-- physics object, so it spawned unusable (no working IO or tool interaction).
		-- Stats still come from the chosen box volume above, so the size config the
		-- player picked is preserved even though the model isn't physically scaled.
		Gen:SetModel(ACF.FieldGenThumperModel or "models/props_combine/combinethumper002.mdl")
		Gen:PhysicsInit(SOLID_VPHYSICS)
		Gen:SetMoveType(MOVETYPE_VPHYSICS)
		Gen:SetSolid(SOLID_VPHYSICS)
		local phys = Gen:GetPhysicsObject()
		if IsValid(phys) then phys:Wake() end
		Gen.IsScalable = false
	else
		local info = Sustain.ApplyShape(Gen, scaleVec, Data2, def)
		if not info then Gen:Remove() return false end
	end

	Gen.Id          = Id
	Gen.SizeId      = Data1
	Gen.Shape       = Data2
	Gen.UseThumper  = useThumper
	Gen.Dimensions  = Vector(L, W, H)
	Gen.LiterPerSec = vol * ACF.FieldGenRate
	Gen.HeatWatts   = vol * ACF.FieldGenHeatDensity
	Gen.PowerNeed   = math.max(vol * (ACF.FieldGenPowerPerVolume or 0.015), 0.1)
	Gen.Mass        = math.max(vol * ACF.FieldGenMassPerVolume, 5)
	Gen.ACEPoints   = vol * ACF.FieldGenPointsPerVolume

	Sustain.FinishSpawn(Gen, Owner, "_ace_field_generator", def.name or "Field Generator")

	return Gen
end

list.Set("ACFCvars", "ace_field_generator", {"id", "data1", "data2", "data3"})
duplicator.RegisterEntityClass("ace_field_generator", MakeACE_FieldGenerator, "Pos", "Angle", "Id", "SizeId", "Shape", "UseThumper")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_FieldGenerator, "FieldGenerators")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	local cls = Target:GetClass()

	-- A pipe or pump: join the fuel network so oil flows to tanks downstream.
	if cls == "ace_fuel_pipe" or cls == "ace_fuel_pump" then
		for _, L in ipairs(self.PipeLinks) do if L == Target then return false, "Already linked to that pipe!" end end
		-- Surface gap (nearest point to nearest point), matching ace_fuel_pipe's own
		-- link rule, so a long scalable pipe links when its END reaches the pump.
		local pa = self:NearestPoint(Target:WorldSpaceCenter())
		local pb = Target:NearestPoint(pa)
		pa = self:NearestPoint(pb)
		local gap = pa:Distance(pb)
		if gap > (ACF.PipeLinkGap or 80) then
			return false, "Too far (" .. math.Round(gap, 0) .. "u gap). Bring a pipe end to the pump or chain another segment."
		end
		table.insert(self.PipeLinks, Target)
		if Target.AddPipeLink then Target:AddPipeLink(self) end
		return true, "Oil pump linked into the fuel network."
	end

	-- A grid node: tap it for the electricity the pump motor needs.
	if cls == "ace_transfer_station" or cls == "ace_transformer" or cls == "ace_power_line" or cls == "ace_capacitor" then
		local dist = self:GetPos():Distance(Target:GetPos())
		if dist > (ACF.GridStationLinkRange or 800) then
			return false, "Too far (" .. math.Round(dist, 0) .. "u). Move the pump closer to the node."
		end
		self.Station = Target
		self:UpdateOverlayText()
		return true, "Pump tapped into the grid for power."
	end

	if cls ~= "acf_fueltank" then return false, "Link a fuel tank, pipe, pump, grid node, or Electric battery." end

	-- An Electric tank powers the pump directly (it makes oil, not electricity, so
	-- it can't OUTPUT to one - but it can be POWERED by one).
	if Target.FuelType == "Electric" then
		self.Battery = Target
		self:UpdateOverlayText()
		return true, "Pump powered directly from that battery."
	end

	for _, T in pairs(self.FuelLink) do if T == Target then return false, "That fuel tank is already linked!" end end
	table.insert(self.FuelLink, Target)
	return true, "Link successful!"
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target == self.Station then self.Station = nil self:UpdateOverlayText() return true, "Unlinked from grid power." end
	if Target == self.Battery then self.Battery = nil self:UpdateOverlayText() return true, "Unlinked from battery." end
	for K, T in pairs(self.FuelLink) do if T == Target then table.remove(self.FuelLink, K) return true, "Unlink successful!" end end
	for K, L in pairs(self.PipeLinks) do
		if L == Target then
			table.remove(self.PipeLinks, K)
			if IsValid(Target) and Target.RemovePipeLink then Target:RemovePipeLink(self) end
			return true, "Unlink successful!"
		end
	end
	return false, "That entity is not linked!"
end

-- Pipe-graph back-link hooks (mirrors ace_fuel_pump).
function ENT:AddPipeLink(other)
	for _, L in ipairs(self.PipeLinks) do if L == other then return end end
	table.insert(self.PipeLinks, other)
end

function ENT:RemovePipeLink(other)
	for k = #self.PipeLinks, 1, -1 do if self.PipeLinks[k] == other then table.remove(self.PipeLinks, k) end end
end

-- Walk the linked pipe network and collect every oil-capable tank reachable from
-- this pump (so oil can flow down a pipe run, not just into directly-linked tanks).
function ENT:NetworkOilTanks()
	local out, seen = {}, {}
	local function visit(node, depth)
		if depth > (ACF.PipeMaxHops or 14) then return end
		for _, L in ipairs(node.PipeLinks or {}) do
			if IsValid(L) and not seen[L] then
				seen[L] = true
				local cls = L:GetClass()
				if cls == "acf_fueltank" then
					if L.AddFuel and L.FuelType ~= "Electric" and (not L.CanReceiveFuel or L:CanReceiveFuel("Oil")) then
						out[#out + 1] = L
					end
				elseif cls == "ace_fuel_pipe" or cls == "ace_fuel_pump" then
					local blocked = cls == "ace_fuel_pipe" and L.Condition and L:Condition() <= 0
					if not blocked then visit(L, depth + 1) end
				end
			end
		end
	end
	visit(self, 0)
	return out
end

-- It only pumps when it's actually resting on the ground/world. Cheap trace
-- straight down, re-checked a few times a second.
function ENT:CheckGrounded()
	local tr = util.TraceLine({
		start  = self:GetPos(),
		endpos = self:GetPos() - Vector(0, 0, (self.Dimensions and self.Dimensions.z or 16) * 0.5 + 12),
		mask   = MASK_SOLID_BRUSHONLY,
		filter = self,
	})
	self.Grounded = tr.Hit and tr.HitWorld or false
	return self.Grounded
end

-- Pumps CRUDE OIL: only deposits into Oil (or still-empty Universal) tanks, so
-- you have to refine it into petrol/diesel before an engine can use it.
function ENT:DepositFuel(liters)
	local placed = 0
	-- Directly-linked tanks first, then any tank reachable through linked pipes.
	for _, Tank in pairs(self.FuelLink) do
		if placed >= liters then break end
		if not IsValid(Tank) or not Tank.AddFuel then continue end
		if Tank.CanReceiveFuel and not Tank:CanReceiveFuel("Oil") then continue end
		placed = placed + (Tank:AddFuel(liters - placed, "Oil") or 0)
	end
	if placed < liters and #self.PipeLinks > 0 then
		for _, Tank in ipairs(self:NetworkOilTanks()) do
			if placed >= liters then break end
			placed = placed + (Tank:AddFuel(liters - placed, "Oil") or 0)
		end
	end
	return placed
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "Fuel Rate", math.Round(self.FuelRate, 5))
	WireLib.TriggerOutput(self, "Heat", math.Round(self.Heat, 1))
	WireLib.TriggerOutput(self, "Grounded", self.Grounded and 1 or 0)
	WireLib.TriggerOutput(self, "Powered", (self.PowerFrac or 0) > 0 and 1 or 0)
end

function ENT:UpdateOverlayText()
	local powerSrc = IsValid(self.Station) and "grid" or (IsValid(self.Battery) and "battery" or "NONE")
	local state
	if not self.Active then state = "OFF"
	elseif not self.Grounded then state = "ON (airborne - not pumping)"
	elseif (self.PowerFrac or 0) <= 0 then state = "ON (NO POWER - not pumping)"
	elseif self.PowerFrac < 0.99 then state = "ON (low power - " .. math.Round(self.PowerFrac * 100, 0) .. "%)"
	else state = "ON" end
	local txt = "Oil Pump (crude)"
	txt = txt .. "\nState: " .. state
	txt = txt .. "\nPower: " .. powerSrc .. "   needs " .. math.Round(self.PowerNeed or 0, 2) .. " kW"
	txt = txt .. "\nPumping: " .. math.Round((self.FuelRate or 0) * 60, 4) .. " L/min oil"
	txt = txt .. "\nHeat: " .. math.Round(self.Heat or 0, 0) .. " C"
	txt = txt .. "\nTanks: " .. #(self.FuelLink or {}) .. "   Pipes: " .. #(self.PipeLinks or {})
	txt = txt .. "\n(wire 'Active' to toggle; link a battery or grid node for power)"
	self:SetOverlayText(txt)
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then self.Active = value ~= 0 end
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or FrameTime()
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	-- Drop deleted output tanks so the count stays correct.
	for k = #self.FuelLink, 1, -1 do
		if not IsValid(self.FuelLink[k]) then table.remove(self.FuelLink, k) end
	end
	for k = #self.PipeLinks, 1, -1 do
		if not IsValid(self.PipeLinks[k]) then table.remove(self.PipeLinks, k) end
	end

	if CurTime() >= self.NextGroundCheck then
		self.NextGroundCheck = CurTime() + 0.5
		self:CheckGrounded()
	end

	self.FuelRate  = 0
	self.PowerFrac = 0
	self.Voltage   = 0

	-- Pull the electricity the pump needs. Without it, the pump can't run; with
	-- partial power it pumps at a reduced rate (full power -> full rate).
	if self.Active and self.Grounded and (self.PowerNeed or 0) > 0 then
		local want = self.PowerNeed * dt / 3600
		local got, volts = 0, 0
		if IsValid(self.Station) then
			got, volts = Sustain.GridPull(self.Station, want, dt)
		elseif IsValid(self.Battery) and self.Battery.DrawEnergy then
			got   = self.Battery:DrawEnergy(want, dt) or 0
			volts = (got > 0) and (ACF.BatteryNominalVoltage or 1) or 0
		end
		local suppliedKW = got / math.max(dt / 3600, 1e-9)
		self.PowerFrac   = math.Clamp(suppliedKW / self.PowerNeed, 0, 1)
		self.Voltage     = volts or 0
	end

	-- Only pump when switched on, grounded, AND its pump is fed.
	if self.Active and self.Grounded and self.PowerFrac > 0 then
		local r = SynthLogic.Field({
			literPerSec = self.LiterPerSec * self.PowerFrac,
			heatWatts   = self.HeatWatts,
			dt          = dt,
		})

		if r.fuelMade > 0 then self:DepositFuel(r.fuelMade) end
		self.FuelRate = self.LiterPerSec * self.PowerFrac

		-- Process heat, plus extra if the pump motor is fed above its rated voltage.
		local breakdown = PowerLogic.Breakdown(self.Voltage or 0, self.RatedVoltage or 1)
		local heatJ     = r.heatAddJ + PowerLogic.OverVoltageHeat(breakdown, self.PowerNeed * self.PowerFrac) * dt
		self.Heat = HeatLogic.HeatStep(self.Heat, heatJ, self.Mass, 0.7, ambient, dt)

		if CurTime() >= self.NextThump then
			self:EmitSound(THUMP_SOUND, 70, 90)
			self.NextThump = CurTime() + 1.2
		end
	else
		self.Heat = HeatLogic.HeatStep(self.Heat, 0, self.Mass, 0.7, ambient, dt)
	end

	-- Publish the auxiliary (power) links so the Grid Tool overlay can draw them.
	Sustain.NetworkAux(self, {
		{ ent = self.Station, label = "power",   into = true },
		{ ent = self.Battery, label = "battery", into = true },
	})
	self:SetNWBool("AceLive", (self.FuelRate or 0) > 0)   -- animates the link pulses in the Grid Tool

	self:UpdateOutputs()
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:OnRemove()
	for _, L in ipairs(self.PipeLinks or {}) do
		if IsValid(L) and L.RemovePipeLink then L:RemovePipeLink(self) end
	end
end

do
	function ENT:PreEntityCopy()
		local fuel, pipes = {}, {}
		for _, T in pairs(self.FuelLink) do if IsValid(T) then table.insert(fuel, T:EntIndex()) end end
		for _, L in pairs(self.PipeLinks) do if IsValid(L) then table.insert(pipes, L:EntIndex()) end end
		duplicator.StoreEntityModifier(self, "FieldGenLinks", {
			fuel    = fuel,
			pipes   = pipes,
			station = IsValid(self.Station) and self.Station:EntIndex() or nil,
			battery = IsValid(self.Battery) and self.Battery:EntIndex() or nil,
		})
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.FieldGenLinks then return end
		local info = Ent.EntityMods.FieldGenLinks
		for _, idx in ipairs(info.fuel or {}) do
			local T = CreatedEntities[idx]
			if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		end
		for _, idx in ipairs(info.pipes or {}) do
			local L = CreatedEntities[idx]
			if IsValid(L) then self:Link(L) end
		end
		if info.station then local S = CreatedEntities[info.station] if IsValid(S) then self:Link(S) end end
		if info.battery then local B = CreatedEntities[info.battery] if IsValid(B) then self:Link(B) end end
		Ent.EntityMods.FieldGenLinks = nil
	end
end
