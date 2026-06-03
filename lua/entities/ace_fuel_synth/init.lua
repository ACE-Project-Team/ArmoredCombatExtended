AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain    = ACE.Sustain
local SynthLogic = Sustain.Synth
local HeatLogic  = Sustain.Heat
local PowerLogic = Sustain.Power

-- Optional real-prop models (spawned at natural size; stats come from the prop's
-- real volume). "scalable" (or anything unrecognised) uses the Box/Cylinder mesh.
local SYNTH_MODELS = {
	coolingtank = "models/props_wasteland/coolingtank02.mdl",
}

function ENT:Initialize()
	self.BattLink    = {}   -- Electric tanks we draw power from (direct)
	self.Station     = nil  -- ...or a grid node we tap for power
	self.FuelLink    = {}   -- liquid tanks we fill (petrol / diesel / universal)
	self.Active      = false   -- off until switched on (matches the oil pump; no "runs the moment it spawns")
	self.FuelRate    = 0    -- L/s total produced (deposited)
	self.PetrolRate  = 0    -- L/s petrol deposited
	self.DieselRate  = 0    -- L/s diesel deposited
	self.ElecDraw    = 0    -- kW currently drawn
	self.Voltage     = 0    -- delivered voltage of the power it's pulling
	self.RatedVoltage = ACF.SynthRatedVoltage or 80   -- above this its electronics overheat
	self.Efficiency  = ACF.SynthEfficiency or 0.55
	self.ReactorTemp = ACF.SynthReactorTempDefault or 275
	self.PressurePetrol = 0 -- litres of petrol backed up internally (no outlet)
	self.PressureDiesel = 0 -- litres of diesel backed up internally
	self.PressureMax = 1
	self.Heat        = ACE.AmbientTemp or 20   -- reactor temperature (process variable)
	self.ElecHeat    = ACE.AmbientTemp or 20   -- electronics temperature (over-voltage stress)
	self.ElecTripped = false                   -- electronics thermally tripped (off until cooled)
	self.Legal       = true
	self.IsScalable  = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
		"Reactor Temp (" .. (ACF.SynthReactorTempMin or 210) .. "-" .. (ACF.SynthReactorTempMax or 340) .. " C; hot=petrol, cold=diesel) [NORMAL]",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Fuel Rate (Litres/sec total) [NORMAL]",
		"Petrol Rate (Litres/sec) [NORMAL]",
		"Diesel Rate (Litres/sec) [NORMAL]",
		"Elec Draw (kW) [NORMAL]",
		"Pressure (0-1, cooks off at 1) [NORMAL]",
		"Reactor Temp (C) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_FuelSynth(Owner, Pos, Angle, Id, Data1, Data2, Data3)
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

	-- Model: a chosen real prop at natural size (stats from its real volume), or
	-- the scalable Box/Cylinder mesh at the configured L:W:H.
	local modelKey  = tostring(Data3 or "scalable")
	local propModel = SYNTH_MODELS[modelKey]
	local vol, dims

	if propModel then
		Synth:SetModel(propModel)
		Synth:PhysicsInit(SOLID_VPHYSICS)
		Synth:SetMoveType(MOVETYPE_VPHYSICS)
		Synth:SetSolid(SOLID_VPHYSICS)
		local phys = Synth:GetPhysicsObject()
		if IsValid(phys) then phys:Wake() end
		vol  = (IsValid(phys) and phys:GetVolume() or 0) * 16.38   -- cu in
		dims = Synth:OBBMaxs() - Synth:OBBMins()
		Synth.IsScalable = false
	else
		local info = Sustain.ApplyShape(Synth, scaleVec, Data2, def)
		if not info then Synth:Remove() return false end
		vol  = info.volume
		dims = info.dims
	end

	if vol <= 0 then vol = 1 end

	Synth.Id         = Id
	Synth.SizeId     = Data1
	Synth.Shape      = Data2
	Synth.Model3     = modelKey
	Synth.Dimensions = dims
	Synth.MaxRate    = vol * ACF.SynthPowerDensity     -- kW electrical draw
	Synth.Efficiency = ACF.SynthEfficiency or 0.55
	Synth.EnergyPerLiter = ACF.SynthEnergyPerLiter or 9.7
	Synth.Mass       = math.max(vol * ACF.SynthMassPerVolume, 5)
	Synth.ACEPoints  = vol * ACF.SynthPointsPerVolume

	-- Overpressure budget: how many litres of UN-vented product the reactor can
	-- hold before it cooks off. Sized so a fully-blocked plant takes
	-- SynthOverpressureSeconds of full production to reach the limit, so it scales
	-- naturally with the build.
	local fullLPS = (Synth.MaxRate * Synth.Efficiency) / math.max(Synth.EnergyPerLiter, 0.01) / 3600
	Synth.PressureMax = math.max(fullLPS * (ACF.SynthOverpressureSeconds or 30), 1)

	Sustain.FinishSpawn(Synth, Owner, "_ace_fuel_synth", def.name or "ACE Fuel Synthesizer")

	return Synth
end

list.Set("ACFCvars", "ace_fuel_synth", {"id", "data1", "data2", "data3"})
duplicator.RegisterEntityClass("ace_fuel_synth", MakeACE_FuelSynth, "Pos", "Angle", "Id", "SizeId", "Shape", "Model3")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_FuelSynth, "FuelSynths")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	local cls = Target:GetClass()

	-- A grid node: tap it for power (so it can be fed at a stepped voltage and is
	-- part of the unified grid). Pulling above its rated voltage overheats it.
	if cls == "ace_transfer_station" or cls == "ace_transformer" or cls == "ace_power_line" or cls == "ace_capacitor" then
		local dist = self:GetPos():Distance(Target:GetPos())
		if dist > (ACF.GridStationLinkRange or 800) then
			return false, "Too far (" .. math.Round(dist, 0) .. "u). Move the synthesizer closer to the node."
		end
		self.Station = Target
		self:UpdateOverlayText()
		return true, "Tapped into the grid for power."
	end

	if cls ~= "acf_fueltank" then return false, "Link a fuel tank (Electric = power, Petrol/Diesel/Universal = output), or a grid node for power." end

	if Target.FuelType == "Electric" then
		for _, T in pairs(self.BattLink) do if T == Target then return false, "That battery is already linked!" end end
		table.insert(self.BattLink, Target)
		return true, "Linked battery (power source)!"
	else
		for _, T in pairs(self.FuelLink) do if T == Target then return false, "That fuel tank is already linked!" end end
		table.insert(self.FuelLink, Target)
		return true, "Linked output tank! (link a Petrol AND a Diesel tank, or this product backs up.)"
	end
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target == self.Station then self.Station = nil self:UpdateOverlayText() return true, "Unlinked from grid power." end
	for K, T in pairs(self.BattLink) do if T == Target then table.remove(self.BattLink, K) return true, "Unlink successful!" end end
	for K, T in pairs(self.FuelLink) do if T == Target then table.remove(self.FuelLink, K) return true, "Unlink successful!" end end
	return false, "That entity is not linked!"
end

-- Pull up to wantKWh of electricity, grid first (at its delivered voltage) then
-- topping up from any directly-linked batteries. Returns (kWh delivered, voltage).
function ENT:DrawPower(wantKWh, dt)
	local got, volts = 0, 0
	if IsValid(self.Station) then
		got, volts = Sustain.GridPull(self.Station, wantKWh, dt)
	end
	if got < wantKWh then
		for _, Batt in pairs(self.BattLink) do
			if got >= wantKWh then break end
			if not IsValid(Batt) or not Batt.DrawEnergy then continue end
			local b = Batt:DrawEnergy(wantKWh - got, dt) or 0
			got = got + b
			-- A raw battery is low-voltage DC; only counts toward voltage if the grid
			-- isn't already setting it.
			if b > 0 and volts <= 0 then volts = ACF.BatteryNominalVoltage or 1 end
		end
	end
	return got, volts
end

-- Deposit up to `liters` of a specific product into matching linked tanks
-- (same type, or a still-typeless Universal tank). Returns litres accepted.
function ENT:DepositProduct(fuelType, liters)
	if liters <= 0 then return 0 end
	local placed = 0
	for _, Tank in pairs(self.FuelLink) do
		if placed >= liters then break end
		if not IsValid(Tank) or not Tank.AddFuel then continue end
		if not (Tank.CanReceiveFuel and Tank:CanReceiveFuel(fuelType)) then continue end
		placed = placed + (Tank:AddFuel(liters - placed, fuelType) or 0)
	end
	return placed
end

function ENT:PressureFrac()
	local total = (self.PressurePetrol or 0) + (self.PressureDiesel or 0)
	return (self.PressureMax > 0) and math.Clamp(total / self.PressureMax, 0, 1) or 0
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "Fuel Rate", math.Round(self.FuelRate, 4))
	WireLib.TriggerOutput(self, "Petrol Rate", math.Round(self.PetrolRate, 4))
	WireLib.TriggerOutput(self, "Diesel Rate", math.Round(self.DieselRate, 4))
	WireLib.TriggerOutput(self, "Elec Draw", math.Round(self.ElecDraw, 2))
	WireLib.TriggerOutput(self, "Pressure", math.Round(self:PressureFrac(), 3))
	WireLib.TriggerOutput(self, "Reactor Temp", math.Round(self.Heat, 1))
end

function ENT:UpdateOverlayText()
	local pf = self:PressureFrac()
	local txt = "Fuel Synthesizer (crude-free petrol + diesel)"
	txt = txt .. "\nReactor: " .. math.Round(self.Heat or 0, 0) .. " C (set " .. math.Round(self.ReactorTemp or 0, 0) .. ")"
	txt = txt .. "\nPetrol: " .. math.Round((self.PetrolRate or 0) * 60, 2) .. "   Diesel: " .. math.Round((self.DieselRate or 0) * 60, 2) .. " L/min"
	txt = txt .. "\nDraw: " .. math.Round(self.ElecDraw or 0, 1) .. " / " .. math.Round(self.MaxRate or 0, 1) .. " kW"
		.. "  @ " .. math.Round(self.Voltage or 0, 0) .. " V (rated " .. math.Round(self.RatedVoltage or 0, 0) .. ")"
	txt = txt .. "\nPressure: " .. math.Round(pf * 100, 0) .. "%"
	if self.ElecTripped then txt = txt .. "  !! ELECTRONICS COOKED (over-voltage) - cooling down"
	elseif pf >= 0.85 then txt = txt .. "  !! VENT A PRODUCT - ABOUT TO COOK OFF !!"
	elseif (self.Voltage or 0) > (self.RatedVoltage or 0) then txt = txt .. "  !! OVER-VOLTAGE - electronics overheating"
	elseif pf >= 0.4 then txt = txt .. "  (backing up - add an outlet tank)" end
	local powerSrc = IsValid(self.Station) and "grid" or (#(self.BattLink or {}) > 0 and "battery" or "NONE")
	txt = txt .. "\nPower: " .. powerSrc .. "   Output tanks: " .. #(self.FuelLink or {})
	self:SetOverlayText(txt)
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then
		self.Active = value ~= 0
	elseif iname == "Reactor Temp" then
		self.ReactorTemp = math.Clamp(value or (ACF.SynthReactorTempDefault or 275),
			ACF.SynthReactorTempMin or 210, ACF.SynthReactorTempMax or 340)
	end
end

-- Cook off: vent the held product as an ACF explosion (same path the fuel tanks
-- use for cookoff). Guarded by the ACF_FuelExplode hook + an Exploding flag.
function ENT:CookOff()
	if self.Exploding then return end
	if hook.Run("ACF_FuelExplode", self) == false then return end
	self.Exploding = true
	self:EmitSound("ambient/fire/gascan_ignite1.wav", 100, 100)
	if ACF_ScaledExplosion then
		ACF_ScaledExplosion(self, true)
	else
		self:Remove()
	end
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or FrameTime()
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20
	local tMin = ACF.SynthReactorTempMin or 210
	local tMax = ACF.SynthReactorTempMax or 340

	-- Drop deleted batteries / output tanks so the overlay counts stay honest.
	for k = #self.BattLink, 1, -1 do
		if not IsValid(self.BattLink[k]) then table.remove(self.BattLink, k) end
	end
	for k = #self.FuelLink, 1, -1 do
		if not IsValid(self.FuelLink[k]) then table.remove(self.FuelLink, k) end
	end

	self.FuelRate, self.PetrolRate, self.DieselRate, self.ElecDraw = 0, 0, 0, 0
	self.Voltage = 0
	local running   = false
	local elecHeatJ = 0

	if self.Active and not self.Exploding and not self.ElecTripped then
		local setpoint = math.Clamp(self.ReactorTemp or (ACF.SynthReactorTempDefault or 275), tMin, tMax)

		-- Backpressure throttles production: the more product is backed up, the
		-- less the plant can draw/make (down to a floor), so a blocked outlet
		-- visibly bogs it before it cooks off.
		local pFrac = self:PressureFrac()
		local pressureMult = Lerp(pFrac, 1, ACF.SynthPressureEffFloor or 0.1)

		local want         = self.MaxRate * dt / 3600
		local drawn, volts = self:DrawPower(want * pressureMult, dt)
		self.Voltage       = volts or 0

		-- Over-voltage stresses the electronics: feeding it above its rated voltage
		-- heats a separate "electronics" temperature (NOT the reactor), which trips
		-- it offline if sustained. Step the supply down with a transformer.
		local drawnKW   = drawn / math.max(dt / 3600, 1e-9)
		local breakdown = PowerLogic.Breakdown(self.Voltage, self.RatedVoltage or 1)
		elecHeatJ = PowerLogic.OverVoltageHeat(breakdown, drawnKW > 0 and drawnKW or self.MaxRate) * dt

		local r = SynthLogic.Tick({
			elecAvailableKWh = drawn,
			maxRateKW        = self.MaxRate,
			efficiency       = self.Efficiency,
			energyPerLiter   = self.EnergyPerLiter,
			dt               = dt,
		})

		-- Split the made fuel into petrol + diesel by reactor temperature.
		local petrolFrac, dieselFrac = SynthLogic.ProductSplit(setpoint, tMin, tMax)
		self.PressurePetrol = (self.PressurePetrol or 0) + r.fuelMade * petrolFrac
		self.PressureDiesel = (self.PressureDiesel or 0) + r.fuelMade * dieselFrac

		-- Vent what we can into matching tanks; whatever can't leave stays as pressure.
		local petrolOut = self:DepositProduct("Petrol", self.PressurePetrol)
		self.PressurePetrol = math.max(self.PressurePetrol - petrolOut, 0)
		local dieselOut = self:DepositProduct("Diesel", self.PressureDiesel)
		self.PressureDiesel = math.max(self.PressureDiesel - dieselOut, 0)

		self.PetrolRate = (dt > 0) and (petrolOut / dt) or 0
		self.DieselRate = (dt > 0) and (dieselOut / dt) or 0
		self.FuelRate   = self.PetrolRate + self.DieselRate
		self.ElecDraw   = (dt > 0) and (drawn / (dt / 3600)) or 0
		running = drawn > 0

		-- Reactor is temperature-controlled: while running it's held near its
		-- setpoint (realistic FT operating temps, 210-340 C); idle it coasts to ambient.
		local target = running and setpoint or ambient
		self.Heat = self.Heat + (target - self.Heat) * math.Clamp(dt / 8, 0, 1)

		-- Overpressure cook-off.
		if self:PressureFrac() >= 1 then self:CookOff() end
	else
		self.Heat = self.Heat + (ambient - self.Heat) * math.Clamp(dt / 8, 0, 1)
	end

	-- Electronics temperature: rises with over-voltage heat, bleeds to ambient
	-- otherwise. Sustained over-voltage trips the plant offline until it cools.
	self.ElecHeat = HeatLogic.HeatStep(self.ElecHeat, elecHeatJ, self.Mass or 5, 1, ambient, dt)
	if not self.ElecTripped and self.ElecHeat > (ACF.SynthElecTripTemp or 160) then
		self.ElecTripped = true
		self:EmitSound("ambient/energy/spark6.wav", 80, 80)
	elseif self.ElecTripped and self.ElecHeat <= ambient + 15 then
		self.ElecTripped = false
	end

	-- Publish links so the ACE Grid Tool can draw the power + output tanks.
	local aux = {}
	if IsValid(self.Station) then aux[#aux + 1] = { ent = self.Station, label = "power" } end
	for _, B in pairs(self.BattLink) do if IsValid(B) then aux[#aux + 1] = { ent = B, label = "battery" } end end
	for _, T in pairs(self.FuelLink) do if IsValid(T) then aux[#aux + 1] = { ent = T, label = (T.FuelType or "out") } end end
	Sustain.NetworkAux(self, aux)

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
		duplicator.StoreEntityModifier(self, "SynthLinks", {
			batt    = batt,
			fuel    = fuel,
			station = IsValid(self.Station) and self.Station:EntIndex() or nil,
		})
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
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
		if info.station then local S = CreatedEntities[info.station] if IsValid(S) then self:Link(S) end end
		Ent.EntityMods.SynthLinks = nil
	end
end
