-- REFINERY: crude oil + electricity IN -> petrol OR diesel OUT (one product,
-- picked by the output tank's type). The middle of the oil chain: oil pump
-- (ace_field_generator) -> refinery -> engine fuel. For fuel WITHOUT crude,
-- that's ace_fuel_synth's job instead.

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

local Sustain   = ACE.Sustain
local HeatLogic = Sustain.Heat

local REFINERY_MODEL = "models/props_c17/furnitureboiler001a.mdl"

function ENT:Initialize()
	self.OilTank    = nil    -- crude input
	self.Battery    = nil    -- electricity
	self.OutTank    = nil    -- petrol/diesel output
	self.Active     = true
	self.Refining   = 0      -- L/s product
	self.OilDraw    = 0
	self.ElecDraw   = 0
	self.Heat       = ACE.AmbientTemp or 20
	self.Legal      = true

	self:SetModel(REFINERY_MODEL)
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then phys:Wake() end

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Refining (Litres/sec of product) [NORMAL]",
		"Oil Draw (L/s) [NORMAL]",
		"Elec Draw (kW) [NORMAL]",
		"Heat (C) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_Refinery(Owner, Pos, Angle, _Id)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_refinery") then return false end
	local ent = ents.Create("ace_refinery")
	if not IsValid(ent) then return false end
	ent:SetAngles(Angle)
	ent:SetPos(Pos)
	ent:Spawn()
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then phys:EnableMotion(true) end
	ent:CPPISetOwner(Owner)
	ent:SetNWString("WireName", "Refinery")
	ent:UpdateOverlayText()
	if IsValid(Owner) then
		Owner:AddCount("_ace_refinery", ent)
		Owner:AddCleanup("acfmenu", ent)
	end
	return ent
end

list.Set("ACFCvars", "ace_refinery", {"id"})
duplicator.RegisterEntityClass("ace_refinery", MakeACE_Refinery, "Pos", "Angle", "Id")

function ENT:SpawnFunction(ply, tr)
	if not tr or not tr.Hit then return end
	return MakeACE_Refinery(ply, tr.HitPos + tr.HitNormal * 16, Angle(0, IsValid(ply) and ply:EyeAngles().yaw or 0, 0), "Refinery")
end

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "acf_fueltank" then return false, "Link an Oil tank (input), a battery (power), and a Petrol/Diesel tank (output)." end

	local t = Target.FuelType
	if t == "Oil" then
		self.OilTank = Target
		return true, "Linked crude oil input."
	elseif t == "Electric" then
		self.Battery = Target
		return true, "Linked power."
	elseif t == "Petrol" or t == "Diesel" or (Target.IsUniversal and t == "Universal") then
		self.OutTank = Target
		return true, "Linked product output (" .. (t == "Universal" and "will make Petrol" or t) .. ")."
	end
	return false, "That tank type can't be used here (need Oil / Electric / Petrol / Diesel)."
end

function ENT:Unlink(Target)
	if IsValid(Target) then
		if Target == self.OilTank then self.OilTank = nil return true, "Unlinked oil." end
		if Target == self.Battery then self.Battery = nil return true, "Unlinked power." end
		if Target == self.OutTank then self.OutTank = nil return true, "Unlinked output." end
	end
	return false, "That entity is not linked!"
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then self.Active = value ~= 0 end
end

function ENT:UpdateOverlayText()
	local txt = "Refinery (crude -> fuel)"
	txt = txt .. "\nOil in: " .. (IsValid(self.OilTank) and "linked" or "MISSING")
	txt = txt .. "   Power: " .. (IsValid(self.Battery) and "linked" or "MISSING")
	txt = txt .. "   Out: " .. (IsValid(self.OutTank) and (self.OutTank.FuelType or "?") or "MISSING")
	txt = txt .. "\nProducing: " .. math.Round((self.Refining or 0) * 60, 3) .. " L/min"
	txt = txt .. "\nHeat: " .. math.Round(self.Heat or 0, 0) .. " C"
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	self.Refining, self.OilDraw, self.ElecDraw = 0, 0, 0
	local running = false

	-- The crude source must be switched on (Active), the same rule the battery
	-- draw enforces: you can't pull from a tank that isn't linked in as active.
	if self.Active and IsValid(self.OilTank) and self.OilTank.Active
		and IsValid(self.Battery) and IsValid(self.OutTank)
		and (self.OilTank.Fuel or 0) > 0 then

		local oilPerL = ACF.RefineryOilPerLiter or 1.25
		local engPerL = ACF.RefineryEnergyPerLiter or 0.4
		local outType = (self.OutTank.FuelType == "Diesel") and "Diesel" or "Petrol"

		-- Output limited by rate, available oil, and output-tank room.
		local maxOut = (ACF.RefineryRate or 0.06) * dt
		maxOut = math.min(maxOut, (self.OilTank.Fuel or 0) / oilPerL, math.max(self.OutTank.Capacity - self.OutTank.Fuel, 0))

		if maxOut > 0 then
			-- ...then scaled by how much power we actually get.
			local energyNeed = maxOut * engPerL
			local drawn = self.Battery.DrawEnergy and self.Battery:DrawEnergy(energyNeed, dt) or 0
			local out = (energyNeed > 0) and (maxOut * (drawn / energyNeed)) or 0

			if out > 0 then
				self.OilTank.Fuel = math.max(0, self.OilTank.Fuel - out * oilPerL)
				if self.OilTank.UpdateFuelMass then self.OilTank:UpdateFuelMass() end
				self.OutTank:AddFuel(out, outType)

				self.Refining = out / dt
				self.OilDraw  = (out * oilPerL) / dt
				self.ElecDraw = drawn / math.max(dt / 3600, 1e-9)
				running = true
			end
		end
	end

	-- Heat tracks the electrical work going through the refinery (refining is an
	-- energy-intensive, hot process), so it self-regulates with load and actually
	-- climbs to a meaningful temperature - the old flat 500 W against a 200 kg
	-- thermal mass barely moved the needle.
	local heatW = running and (self.ElecDraw * 1000 * (ACF.RefineryHeatFrac or 1)) or 0
	self.Heat = HeatLogic.HeatStep(self.Heat, heatW * dt, ACF.RefineryThermalMass or 60, 0.8, ambient, dt)

	WireLib.TriggerOutput(self, "Refining", math.Round(self.Refining, 4))
	WireLib.TriggerOutput(self, "Oil Draw", math.Round(self.OilDraw, 4))
	WireLib.TriggerOutput(self, "Elec Draw", math.Round(self.ElecDraw, 2))
	WireLib.TriggerOutput(self, "Heat", math.Round(self.Heat, 1))

	-- Publish the tank links so the Conduit overlay can draw the whole crude->fuel
	-- chain (these aren't part of the pipe graph, so the tool can't see them otherwise).
	Sustain.NetworkAux(self, {
		{ ent = self.OilTank, label = "oil",   into = true },
		{ ent = self.Battery, label = "power", into = true },
		{ ent = self.OutTank, label = "out"   },
	})
	self:SetNWBool("AceLive", (self.Refining or 0) > 0)   -- animates the link pulses in the Grid Tool

	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

do
	function ENT:PreEntityCopy()
		duplicator.StoreEntityModifier(self, "RefineryLinks", {
			oil = IsValid(self.OilTank) and self.OilTank:EntIndex() or nil,
			batt = IsValid(self.Battery) and self.Battery:EntIndex() or nil,
			out = IsValid(self.OutTank) and self.OutTank:EntIndex() or nil,
		})
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.RefineryLinks then return end
		local info = Ent.EntityMods.RefineryLinks
		-- Keyed lookup, NOT ipairs over {oil, batt, out}: any missing link there
		-- left a nil hole that cut the array short and dropped the links after it.
		for _, key in ipairs({ "oil", "batt", "out" }) do
			local T = info[key] and CreatedEntities[info[key]]
			if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		end
		self:UpdateOverlayText()
		Ent.EntityMods.RefineryLinks = nil
	end
end
