AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain   = ACE.Sustain
local PipeLogic = Sustain.Pipe

local MAX_LINKS = 6

function ENT:Initialize()
	self.PipeLinks  = {}     -- connected tanks / pipes / pumps (the fuel graph)
	self.FlowRate   = 0
	self.ThroughFlowAccum = 0  -- flow other pipes routed through us since our last think
	self.BoreArea   = 100
	self.FlowCap    = PipeLogic.Bore(100).flowCap
	self.Legal      = true
	self.IsScalable = true
	self.SpecialHealth = true   -- ACF health = pipe condition (torch repairs it)

	self.Outputs = WireLib.CreateOutputs(self, {
		"Flow Rate [NORMAL]",
		"Condition (0-1) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

-- Bore cross-section from the model dims: the two smaller dimensions form the
-- bore; the largest is the length. Wider bore = more flow, less friction.
function ENT:ComputeBore()
	local d = self.Dimensions or Vector(10, 10, 10)
	local a, b, c = d.x, d.y, d.z
	-- sort ascending
	if a > b then a, b = b, a end
	if b > c then b, c = c, b end
	if a > b then a, b = b, a end
	self.BoreArea = math.max(a * b, 1)   -- two smaller dims
	self.FlowCap  = PipeLogic.Bore(self.BoreArea).flowCap
end

function MakeACE_FuelPipe(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_fuel_pipe") then return false end

	local def = ACF.Weapons.FuelPipes[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Pipe = ents.Create("ace_fuel_pipe")
	if not IsValid(Pipe) then return false end

	Pipe:SetAngles(Angle)
	Pipe:SetPos(Pos)
	Pipe:Spawn()

	local info = Sustain.ApplyShape(Pipe, scaleVec, Data2, def)
	if not info then Pipe:Remove() return false end

	Pipe:SetColor(Color(90, 110, 120))
	Pipe.Id         = Id
	Pipe.SizeId     = Data1
	Pipe.Shape      = Data2
	Pipe.Dimensions = info.dims
	Pipe.Mass       = math.max(info.volume * 0.004, 2)
	Pipe.ACEPoints  = 0
	Pipe:ComputeBore()

	Pipe:SetColor(Color(70, 60, 45))   -- dark pipe by default
	Sustain.FinishSpawn(Pipe, Owner, "_ace_fuel_pipe", def.name or "Fuel Pipe")

	Pipe:ACF_Activate()
	return Pipe
end

list.Set("ACFCvars", "ace_fuel_pipe", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_fuel_pipe", MakeACE_FuelPipe, "Pos", "Angle", "Id", "SizeId", "Shape")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_FuelPipe, "FuelPipes")

------------------------------------------------------------------
-- Linking: a pipe connects to fuel tanks, other pipes, and pumps.
------------------------------------------------------------------
local function CanLinkPipe(ent)
	if not IsValid(ent) then return false end
	local c = ent:GetClass()
	return c == "acf_fueltank" or c == "ace_fuel_pipe" or c == "ace_fuel_pump"
		or c == "ace_oil_pump"
end

function ENT:NetworkLinks()
	local n = 0
	for _, L in ipairs(self.PipeLinks) do
		if IsValid(L) and n < MAX_LINKS then
			n = n + 1
			self:SetNWEntity("PL" .. n, L)
		end
	end
	self:SetNWInt("PLN", n)
end

function ENT:Link(Target)
	if not CanLinkPipe(Target) then return false, "Link a Fuel Tank, another Pipe, or a Pump." end
	if Target == self then return false, "Can't link a pipe to itself!" end
	for _, L in ipairs(self.PipeLinks) do
		if L == Target then return false, "Already linked to that!" end
	end
	if #self.PipeLinks >= (ACF.PipeMaxLinks or MAX_LINKS) then
		return false, "This pipe already has the maximum number of links!"
	end
	-- Measure the SURFACE gap (nearest point to nearest point), not center-to-
	-- center, so two long scalable pipes link when their ENDS are close even though
	-- their centers are far apart. A couple of NearestPoint passes converge on it;
	-- linking is rare, so the cost is irrelevant.
	local pa = self:NearestPoint(Target:WorldSpaceCenter())
	local pb = Target:NearestPoint(pa)
	pa = self:NearestPoint(pb)
	local gap = pa:Distance(pb)
	if gap > (ACF.PipeLinkGap or 80) then
		return false, "Too far (" .. math.Round(gap, 0) .. "u gap). Move the pipe ends closer or chain another segment."
	end

	table.insert(self.PipeLinks, Target)
	self:NetworkLinks()
	-- Mirror the link on the other pipe/pump so the graph is undirected.
	if Target.PipeLinks and Target.AddPipeLink then Target:AddPipeLink(self) end
	self:UpdateOverlayText()
	return true, "Linked into the fuel network."
end

-- Add a back-link from a neighbour (no range re-check; the forward link did it).
function ENT:AddPipeLink(other)
	for _, L in ipairs(self.PipeLinks) do if L == other then return end end
	table.insert(self.PipeLinks, other)
	self:NetworkLinks()
end

function ENT:Unlink(Target)
	local removed = false
	for k = #self.PipeLinks, 1, -1 do
		if self.PipeLinks[k] == Target then table.remove(self.PipeLinks, k) removed = true end
	end
	if removed then
		if IsValid(Target) and Target.RemovePipeLink then Target:RemovePipeLink(self) end
		self:NetworkLinks()
		self:UpdateOverlayText()
		return true, "Unlinked."
	end
	return false, "That entity is not linked!"
end

function ENT:RemovePipeLink(other)
	for k = #self.PipeLinks, 1, -1 do
		if self.PipeLinks[k] == other then table.remove(self.PipeLinks, k) end
	end
	self:NetworkLinks()
end

-- ACF health setup so the condition is repairable with the ACE torch.
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

function ENT:Condition()
	if not self.ACF or not self.ACF.MaxHealth or self.ACF.MaxHealth <= 0 then return 1 end
	return math.Clamp((self.ACF.Health or 0) / self.ACF.MaxHealth, 0, 1)
end

function ENT:Wear(dt)
	if self.ACF and self.ACF.MaxHealth then
		local lost = self.ACF.MaxHealth * (ACF.PipeDecayPerSec or 0) * dt
		self.ACF.Health = math.max(0, (self.ACF.Health or 0) - lost)
	end
end

-- Linked tanks that should receive fuel (liquid, not a supplier, with room).
function ENT:ReceiverTanks()
	local out = {}
	for _, L in ipairs(self.PipeLinks) do
		if IsValid(L) and L:GetClass() == "acf_fueltank" and L.FuelType ~= "Electric"
			and not L.SupplyFuel and (L.Capacity or 0) - (L.Fuel or 0) > 0 then
			out[#out + 1] = L
		end
	end
	return out
end

function ENT:UpdateOverlayText()
	local cond = self:Condition()
	local txt = "Fuel Pipe"
	txt = txt .. "\nLinks: " .. #self.PipeLinks .. "   Bore flow: " .. math.Round(self.FlowCap or 0, 2) .. " L/s"
	txt = txt .. "\nCondition: " .. math.Round(cond * 100, 0) .. "%"
	if cond <= 0 then txt = txt .. " (BROKEN - repair with torch)"
	elseif cond < PipeLogic.LeakBelow then txt = txt .. " (LEAKING)" end
	txt = txt .. "\nFlow: " .. math.Round(self.FlowRate or 0, 2) .. " L/s"
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.3
	self.LastThink = CurTime()
	self.FlowRate = 0

	-- Drop dead links.
	local changed = false
	for k = #self.PipeLinks, 1, -1 do
		if not IsValid(self.PipeLinks[k]) then table.remove(self.PipeLinks, k) changed = true end
	end
	if changed then self:NetworkLinks() end

	local cond  = self:Condition()
	local state = PipeLogic.State(cond)

	-- Failure FX + burnt look, reset on repair.
	if state.broken and not self.WasBroken then
		local fx = EffectData() fx:SetOrigin(self:GetPos()) fx:SetScale(2) fx:SetMagnitude(2) fx:SetRadius(10)
		util.Effect("watersplash", fx)
		self:EmitSound("ambient/water/water_spray" .. math.random(1, 2) .. ".wav", 75, 95)
		self:SetMaterial("models/props_wasteland/metal_tram001a")
		self.WasBroken = true
	elseif not state.broken and self.WasBroken then
		self:SetMaterial("")
		self.WasBroken = false
	end

	-- Drive transfer for each receiver tank attached to THIS pipe, pulling a
	-- supply through the pipe graph (pumps extend range).
	if not state.broken then
		for _, recv in ipairs(self:ReceiverTanks()) do
			local res = Sustain.PipeFindSupply(self, recv)
			if res and IsValid(res.supply) then
				local supply = res.supply
				-- Worst leak / flow-throttle along the path.
				local flowMult, leak = 1, 0
				for _, p in ipairs(res.pipes or {}) do
					if IsValid(p) and p.Condition then
						local st = PipeLogic.State(p:Condition())
						flowMult = math.min(flowMult, st.flowMult)
						leak     = math.max(leak, st.leakFrac)
					end
				end

				local loss = math.Clamp((ACF.FuelLinkLoss or 0.04) + leak, 0, 0.95)
				local cap  = (res.flowCap or self.FlowCap) * flowMult
				local room = recv.Capacity - recv.Fuel
				local amount = math.min(cap * dt, supply.Fuel, room / math.max(1 - loss, 0.05))

				if amount > 0 then
					supply.Fuel = supply.Fuel - amount
					if supply.UpdateFuelMass then supply:UpdateFuelMass() end
					recv:AddFuel(amount * (1 - loss), supply.FuelType)
					local thisFlow = amount / dt
					self.FlowRate = self.FlowRate + thisFlow

					for _, p in ipairs(res.pipes or {}) do
						if IsValid(p) and p.Wear then p:Wear(dt) end
						-- Show the same flow on every pipe carrying this transfer,
						-- not just the receiver-end one (read & reset in their Think).
						if IsValid(p) and p ~= self and p:GetClass() == "ace_fuel_pipe" then
							p.ThroughFlowAccum = (p.ThroughFlowAccum or 0) + thisFlow
						end
					end

					if leak > 0 and CurTime() > (self.NextLeakFX or 0) then
						local fx = EffectData() fx:SetOrigin(self:GetPos()) fx:SetScale(0.5) fx:SetMagnitude(1)
						util.Effect("watersplash", fx)
						self.NextLeakFX = CurTime() + 0.6
					end
				end
			end
		end
	end

	-- Fold in flow that neighbouring pipes routed through us (so a mid-line pipe
	-- reads the line's throughput, not 0), then reset for the next cycle.
	self.FlowRate = math.max(self.FlowRate, self.ThroughFlowAccum or 0)
	self.ThroughFlowAccum = 0

	WireLib.TriggerOutput(self, "Flow Rate", math.Round(self.FlowRate, 3))
	WireLib.TriggerOutput(self, "Condition", math.Round(cond, 3))
	self:SetNWFloat("Condition", cond)
	self:SetNWFloat("AceFlow", self.FlowRate or 0)
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.3)
	return true
end

function ENT:OnRemove()
	for _, L in ipairs(self.PipeLinks) do
		if IsValid(L) and L.RemovePipeLink then L:RemovePipeLink(self) end
	end
end

do
	function ENT:PreEntityCopy()
		local ids = {}
		for _, L in ipairs(self.PipeLinks) do
			if IsValid(L) then ids[#ids + 1] = L:EntIndex() end
		end
		if #ids > 0 then duplicator.StoreEntityModifier(self, "FuelPipeLinks", { links = ids }) end
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.FuelPipeLinks then return end
		for _, idx in ipairs(Ent.EntityMods.FuelPipeLinks.links or {}) do
			local L = CreatedEntities[idx]
			if IsValid(L) then self:Link(L) end
		end
		Ent.EntityMods.FuelPipeLinks = nil
	end
end
