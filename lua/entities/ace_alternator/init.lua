AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain   = ACE.Sustain
local AltLogic  = Sustain.Alternator
local HeatLogic = Sustain.Heat

-- Classes whose physics object we can read as a spinning shaft.
local SHAFT_CLASSES = {
	prop_physics = true,
	acf_gearbox  = true,
	tire         = true,
}

function ENT:Initialize()
	self.PropLink   = {}     -- spinning shafts we brake / read rpm from
	self.FuelLink   = {}     -- linked Electric tanks (batteries) to charge
	self.Active     = true
	self.Load       = 0
	self.RPM        = 0
	self.OutputPower = 0
	self.Efficiency = ACF.AlternatorEfficiency or 0.85
	self.Heat       = ACE.AmbientTemp or 20
	self.EnergyAccum = 0
	self.Legal      = true
	self.IsScalable = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
		"Load (0-1, fraction of max braking torque) [NORMAL]",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"RPM (Current shaft RPM) [NORMAL]",
		"Output Power (Electrical power, kW) [NORMAL]",
		"Efficiency (0-1) [NORMAL]",
		"Heat (Temperature, C) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
	Wire_TriggerOutput(self, "Efficiency", self.Efficiency)
end

function MakeACE_Alternator(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_alternator") then return false end

	local def = ACF.Weapons.Alternators[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Alt = ents.Create("ace_alternator")
	if not IsValid(Alt) then return false end

	Alt:SetAngles(Angle)
	Alt:SetPos(Pos)
	Alt:Spawn()

	local info = Sustain.ApplyShape(Alt, scaleVec, Data2, def)
	if not info then Alt:Remove() return false end

	local vol = info.volume
	Alt.Id          = Id
	Alt.SizeId      = Data1
	Alt.Shape       = Data2
	Alt.Dimensions  = info.dims
	Alt.Efficiency  = ACF.AlternatorEfficiency or 0.85
	Alt.MaxPower    = vol * ACF.AlternatorPowerDensity
	-- A bigger alternator has more windings/flux: it can convert more power AND
	-- resist the shaft harder. Brake strength scales with rated output, around
	-- 1.0 for a default-size unit.
	Alt.BrakeScale  = math.Clamp(Alt.MaxPower / (ACF.AlternatorRefPower or 32), 0.3, 4)
	Alt.RatedRPM    = ACF.AlternatorRatedRPM or 3000
	Alt.Mass        = math.max(vol * ACF.AlternatorMassPerVolume, 5)
	Alt.ACEPoints   = vol * ACF.AlternatorPointsPerVolume

	Sustain.FinishSpawn(Alt, Owner, "_ace_alternator", def.name or "ACE Alternator")

	return Alt
end

list.Set("ACFCvars", "ace_alternator", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_alternator", MakeACE_Alternator, "Pos", "Angle", "Id", "SizeId", "Shape")

-- Sandbox spawnmenu: spawns a default-sized one (ACF tool menu for custom sizes).
ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_Alternator, "Alternators")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end

	if Target:GetClass() == "acf_fueltank" then
		if Target.FuelType ~= "Electric" then return false, "Alternators can only charge Electric batteries!" end
		for _, Tank in pairs(self.FuelLink) do
			if Tank == Target then return false, "That battery is already linked!" end
		end
		table.insert(self.FuelLink, Target)
		return true, "Link successful!"
	end

	if SHAFT_CLASSES[Target:GetClass()] then
		for _, Link in pairs(self.PropLink) do
			if Link.Ent == Target then return false, "That shaft is already linked!" end
		end

		local Phys = Target:GetPhysicsObject()
		if not IsValid(Phys) then return false, "Target has no physics!" end

		-- Store the shaft axis in the target's local space (so it tracks rotation)
		-- and the inertia about that axis (used by the velocity-proportional brake).
		local Axis = Phys:WorldToLocalVector(self:GetForward())
		local Inertia = (Axis * Phys:GetInertia()):Length()
		table.insert(self.PropLink, { Ent = Target, Axis = Axis, Inertia = Inertia, Vel = 0 })
		return true, "Link successful!"
	end

	return false, "Can only link Electric batteries or a spinning shaft (prop/gearbox/wheel)!"
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end

	for Key, Tank in pairs(self.FuelLink) do
		if Tank == Target then table.remove(self.FuelLink, Key) return true, "Unlink successful!" end
	end
	for Key, Link in pairs(self.PropLink) do
		if Link.Ent == Target then table.remove(self.PropLink, Key) return true, "Unlink successful!" end
	end
	return false, "That entity is not linked!"
end

-- Returns the highest spin rate (rpm) among linked shafts. We use the magnitude
-- of the whole angular-velocity vector rather than a projection onto a stored
-- axis, so the reading is correct no matter how the alternator is oriented
-- relative to the thing it's bolted to (rpm = deg/s / 6).
function ENT:ReadShaftRPM()
	local rpm = 0
	for _, Link in pairs(self.PropLink) do
		local Ent = Link.Ent
		if not IsValid(Ent) then continue end
		local Phys = Ent:GetPhysicsObject()
		if not IsValid(Phys) then continue end

		local speed = Phys:GetAngleVelocity():Length()   -- deg/s, axis-agnostic
		Link.Vel = speed
		rpm = math.max(rpm, speed / 6)
	end
	return rpm
end

-- Brake each linked shaft - exactly like a gearbox brake: oppose whatever the
-- prop is actually doing. We shed a load-proportional fraction of its *current*
-- angular-velocity vector each tick (clamped so it can never reverse), which is
-- a pure brake: it only ever slows the spin, on whatever axis the spin is on,
-- so it can't tumble the prop or read zero when mounted sideways.
-- hasLoad: only resist the shaft when there's somewhere for the power to go (a
-- valid linked battery). With the battery removed the alternator is an open
-- circuit, so it free-wheels - which is both realistic and stops the "drag
-- persists after I delete the battery" bug.
function ENT:ApplyBraking(dt, hasLoad)
	-- Smooth the commanded load so a step input ramps in over ~0.2 s instead of
	-- slamming the shaft (the old per-tick chunk removal fought the engine and
	-- produced a visible oscillation / "wave" in the drag).
	local target = (hasLoad and self.Load) or 0
	local smoothRate = math.Clamp(dt / 0.2, 0, 1)
	self.SmoothLoad = (self.SmoothLoad or 0) + (target - (self.SmoothLoad or 0)) * smoothRate
	if self.SmoothLoad <= 0.001 then return end

	local coeff = (ACF.AlternatorBrakeCoeff or 8) * (self.BrakeScale or 1)
	-- Exponential (viscous) decay: fraction removed = 1 - e^(-k·dt). This is the
	-- exact integral of a velocity-proportional drag over the timestep, so it is
	-- framerate-INDEPENDENT and monotonic (never overshoots / reverses), which is
	-- what kills the wobble - high or low FPS, the same shaft speed sheds the same
	-- drag instead of a dt-sized chunk that jitters.
	local frac = 1 - math.exp(-self.SmoothLoad * coeff * dt)

	for _, Link in pairs(self.PropLink) do
		local Ent = Link.Ent
		if not IsValid(Ent) then continue end
		local Phys = Ent:GetPhysicsObject()
		if not IsValid(Phys) then continue end

		local angVel = Phys:GetAngleVelocity()          -- deg/s, world
		if angVel:LengthSqr() < 0.0001 then continue end

		Phys:AddAngleVelocity(-angVel * frac)           -- pure brake, never reverses
	end
end

-- Drop invalid links (deleted batteries / shafts) so counts and behaviour stay
-- correct. Returns the number of still-valid linked batteries.
function ENT:PruneLinks()
	for k = #self.FuelLink, 1, -1 do
		if not IsValid(self.FuelLink[k]) then table.remove(self.FuelLink, k) end
	end
	for k = #self.PropLink, 1, -1 do
		if not IsValid(self.PropLink[k].Ent) then table.remove(self.PropLink, k) end
	end
	return #self.FuelLink
end

-- Push accumulated electrical energy into linked batteries.
function ENT:DistributeCharge(dt)
	if self.EnergyAccum <= 0 then return end
	for _, Tank in pairs(self.FuelLink) do
		if self.EnergyAccum <= 0 then break end
		if not IsValid(Tank) or not Tank.ChargeBattery then continue end
		local accepted = Tank:ChargeBattery(self.EnergyAccum, dt)
		self.EnergyAccum = math.max(self.EnergyAccum - (accepted or 0), 0)
	end
	-- Anything that didn't fit this tick is dropped (no infinite buffer).
	self.EnergyAccum = 0
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "RPM", math.Round(self.RPM, 0))
	WireLib.TriggerOutput(self, "Output Power", math.Round(self.OutputPower, 2))
	WireLib.TriggerOutput(self, "Efficiency", self.Efficiency)
	WireLib.TriggerOutput(self, "Heat", math.Round(self.Heat, 1))
end

function ENT:UpdateOverlayText()
	local txt = "Alternator"
	txt = txt .. "\nRPM: " .. math.Round(self.RPM or 0, 0)
	txt = txt .. "\nOutput: " .. math.Round(self.OutputPower or 0, 2) .. " kW"
	txt = txt .. "\nMax: " .. math.Round(self.MaxPower or 0, 2) .. " kW @ " .. math.Round(self.RatedRPM or 0, 0) .. " RPM"
	txt = txt .. "\nLoad: " .. math.Round((self.Load or 0) * 100, 0) .. "%"
	txt = txt .. "\nHeat: " .. math.Round(self.Heat or 0, 0) .. " C"
	txt = txt .. "\nShafts: " .. #(self.PropLink or {}) .. "   Batteries: " .. #(self.FuelLink or {})
	self:SetOverlayText(txt)
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then
		self.Active = value ~= 0
	elseif iname == "Load" then
		self.Load = math.Clamp(value, 0, 1)
	end
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or FrameTime()
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	local hasLoad = self:PruneLinks() > 0   -- valid linked batteries remaining

	if not self.Active then
		self.RPM = 0
		self.OutputPower = 0
		self.Heat = HeatLogic.HeatStep(self.Heat, 0, self.Mass, 1, ambient, dt)
		self:UpdateOutputs()
		self:UpdateOverlayText()
		self:NextThink(CurTime() + 0.5)
		return true
	end

	local rpm = self:ReadShaftRPM()
	self.RPM = rpm

	local r = AltLogic.Tick({
		rpm        = rpm,
		load       = self.Load,
		maxPower   = self.MaxPower,
		ratedRPM   = self.RatedRPM,
		efficiency = self.Efficiency,
		dt         = dt,
	})

	-- No battery to charge = open circuit: no power produced, no shaft drag.
	if not hasLoad then
		r.outputPower = 0
		r.energyKWh   = 0
		r.heatAddJ    = 0
	end

	self:ApplyBraking(dt, hasLoad)

	self.OutputPower = r.outputPower
	self.EnergyAccum = self.EnergyAccum + r.energyKWh
	self.Heat = HeatLogic.HeatStep(self.Heat, r.heatAddJ, self.Mass, 1, ambient, dt)

	self:DistributeCharge(dt)

	self:UpdateOutputs()
	self:UpdateOverlayText()
	self:NextThink(CurTime())
	return true
end

do
	function ENT:PreEntityCopy()
		local entids = {}
		for _, Tank in pairs(self.FuelLink) do
			if IsValid(Tank) then table.insert(entids, Tank:EntIndex()) end
		end
		if #entids > 0 then
			duplicator.StoreEntityModifier(self, "AltFuelLink", { entities = entids })
		end
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.AltFuelLink then return end
		local info = Ent.EntityMods.AltFuelLink
		if info.entities then
			for _, idx in ipairs(info.entities) do
				local Tank = CreatedEntities[idx]
				if IsValid(Tank) and Tank:GetClass() == "acf_fueltank" then self:Link(Tank) end
			end
		end
		Ent.EntityMods.AltFuelLink = nil
	end
end
