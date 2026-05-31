AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain    = ACE.Sustain
local SynthLogic = Sustain.Synth
local HeatLogic  = Sustain.Heat

function ENT:Initialize()
	self.BattLink    = {}   -- Electric tanks we draw power from
	self.FuelLink    = {}   -- liquid tanks we fill
	self.Active      = true
	self.FuelRate    = 0    -- L/s currently produced
	self.ElecDraw    = 0    -- kW currently drawn
	self.Efficiency  = ACF.SynthEfficiency or 0.55
	self.Heat        = ACE.AmbientTemp or 20
	self.Legal       = true
	self.IsScalable  = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Fuel Rate (Litres/sec) [NORMAL]",
		"Elec Draw (kW) [NORMAL]",
		"Heat (C) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_FuelSynth(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_fuel_synth") then return false end

	local def = ACF.Weapons.FuelSynths[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Synth = ents.Create("ace_fuel_synth")
	if not IsValid(Synth) then return false end

	Synth:SetAngles(Angle)
	Synth:SetPos(Pos)
	Synth:Spawn()

	local info = Sustain.ApplyShape(Synth, scaleVec, Data2, def)
	if not info then Synth:Remove() return false end

	local vol = info.volume
	Synth.Id         = Id
	Synth.SizeId     = Data1
	Synth.Shape      = Data2
	Synth.Dimensions = info.dims
	Synth.MaxRate    = vol * ACF.SynthPowerDensity     -- kW electrical draw
	Synth.Efficiency = ACF.SynthEfficiency or 0.55
	Synth.EnergyPerLiter = ACF.SynthEnergyPerLiter or 9.7
	Synth.Mass       = math.max(vol * ACF.SynthMassPerVolume, 5)
	Synth.ACEPoints  = vol * ACF.SynthPointsPerVolume

	Sustain.FinishSpawn(Synth, Owner, "_ace_fuel_synth", def.name or "ACE Fuel Synthesizer")

	return Synth
end

list.Set("ACFCvars", "ace_fuel_synth", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_fuel_synth", MakeACE_FuelSynth, "Pos", "Angle", "Id", "SizeId", "Shape")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_FuelSynth, "FuelSynths")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "acf_fueltank" then return false, "Can only link fuel tanks (Electric = power, liquid = output)!" end

	if Target.FuelType == "Electric" then
		for _, T in pairs(self.BattLink) do if T == Target then return false, "That battery is already linked!" end end
		table.insert(self.BattLink, Target)
		return true, "Linked battery (power source)!"
	else
		for _, T in pairs(self.FuelLink) do if T == Target then return false, "That fuel tank is already linked!" end end
		table.insert(self.FuelLink, Target)
		return true, "Linked fuel tank (output)!"
	end
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	for K, T in pairs(self.BattLink) do if T == Target then table.remove(self.BattLink, K) return true, "Unlink successful!" end end
	for K, T in pairs(self.FuelLink) do if T == Target then table.remove(self.FuelLink, K) return true, "Unlink successful!" end end
	return false, "That entity is not linked!"
end

-- Pull up to wantKWh from linked batteries; returns kWh actually delivered.
function ENT:DrawFromBatteries(wantKWh, dt)
	local got = 0
	for _, Batt in pairs(self.BattLink) do
		if got >= wantKWh then break end
		if not IsValid(Batt) or not Batt.DrawEnergy then continue end
		got = got + (Batt:DrawEnergy(wantKWh - got, dt) or 0)
	end
	return got
end

-- Deposit litres into linked liquid tanks; returns litres accepted.
function ENT:DepositFuel(liters)
	local placed = 0
	for _, Tank in pairs(self.FuelLink) do
		if placed >= liters then break end
		if not IsValid(Tank) or not Tank.AddFuel then continue end
		placed = placed + (Tank:AddFuel(liters - placed) or 0)
	end
	return placed
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "Fuel Rate", math.Round(self.FuelRate, 4))
	WireLib.TriggerOutput(self, "Elec Draw", math.Round(self.ElecDraw, 2))
	WireLib.TriggerOutput(self, "Heat", math.Round(self.Heat, 1))
end

function ENT:UpdateOverlayText()
	local txt = "Fuel Synthesizer"
	txt = txt .. "\nProducing: " .. math.Round((self.FuelRate or 0) * 60, 3) .. " L/min"
	txt = txt .. "\nDraw: " .. math.Round(self.ElecDraw or 0, 2) .. " kW"
	txt = txt .. "\nMax Draw: " .. math.Round(self.MaxRate or 0, 2) .. " kW"
	txt = txt .. "\nHeat: " .. math.Round(self.Heat or 0, 0) .. " C"
	txt = txt .. "\nBatteries: " .. #(self.BattLink or {}) .. "   Tanks: " .. #(self.FuelLink or {})
	self:SetOverlayText(txt)
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then self.Active = value ~= 0 end
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or FrameTime()
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	-- Drop deleted batteries / output tanks so the overlay counts stay honest.
	for k = #self.BattLink, 1, -1 do
		if not IsValid(self.BattLink[k]) then table.remove(self.BattLink, k) end
	end
	for k = #self.FuelLink, 1, -1 do
		if not IsValid(self.FuelLink[k]) then table.remove(self.FuelLink, k) end
	end

	self.FuelRate = 0
	self.ElecDraw = 0

	if self.Active then
		local want = self.MaxRate * dt / 3600         -- kWh we'd like this step
		local drawn = self:DrawFromBatteries(want, dt)

		local r = SynthLogic.Tick({
			elecAvailableKWh = drawn,
			maxRateKW        = self.MaxRate,
			efficiency       = self.Efficiency,
			energyPerLiter   = self.EnergyPerLiter,
			dt               = dt,
		})

		if r.fuelMade > 0 then self:DepositFuel(r.fuelMade) end

		self.ElecDraw = (dt > 0) and (drawn / (dt / 3600)) or 0
		self.FuelRate = (dt > 0) and (r.fuelMade / dt) or 0
		self.Heat = HeatLogic.HeatStep(self.Heat, r.heatAddJ, self.Mass, 0.8, ambient, dt)
	else
		self.Heat = HeatLogic.HeatStep(self.Heat, 0, self.Mass, 0.8, ambient, dt)
	end

	self:UpdateOutputs()
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

do
	function ENT:PreEntityCopy()
		local batt, fuel = {}, {}
		for _, T in pairs(self.BattLink) do if IsValid(T) then table.insert(batt, T:EntIndex()) end end
		for _, T in pairs(self.FuelLink) do if IsValid(T) then table.insert(fuel, T:EntIndex()) end end
		if #batt > 0 or #fuel > 0 then
			duplicator.StoreEntityModifier(self, "SynthLinks", { batt = batt, fuel = fuel })
		end
	end

	function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.SynthLinks then return end
		local info = Ent.EntityMods.SynthLinks
		for _, idx in ipairs(info.batt or {}) do
			local T = CreatedEntities[idx]
			if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		end
		for _, idx in ipairs(info.fuel or {}) do
			local T = CreatedEntities[idx]
			if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		end
		Ent.EntityMods.SynthLinks = nil
	end
end
