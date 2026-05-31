AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain    = ACE.Sustain
local SolarLogic = Sustain.Solar
local HeatLogic  = Sustain.Heat

local INCH_TO_M = 0.0254

function ENT:Initialize()
	self.FuelLink    = {}
	self.Active      = false   -- off until wired/toggled on (Active input -> 1)
	self.MaxPower    = 0
	self.OutputPower = 0
	self.AreaSqM     = 0
	self.Efficiency  = ACF.SolarEfficiency or 0.2
	self.Heat        = ACE.AmbientTemp or 20
	self.EnergyAccum = 0
	self.Legal       = true
	self.IsScalable  = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Output Power (Electrical power, kW) [NORMAL]",
		"Efficiency (0-1) [NORMAL]",
		"Panel Area (m^2) [NORMAL]",
		"Sun Angle (0-1, cosine of incidence) [NORMAL]",
		"Panel Temp (C) [NORMAL]",
		"Heat (C) [NORMAL]",
		"Shadowed (1 when sun is blocked) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
	Wire_TriggerOutput(self, "Efficiency", self.Efficiency)
end

function MakeACE_SolarPanel(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_solarpanel") then return false end

	local def = ACF.Weapons.SolarPanels[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Panel = ents.Create("ace_solarpanel")
	if not IsValid(Panel) then return false end

	Panel:SetAngles(Angle)
	Panel:SetPos(Pos)
	Panel:Spawn()

	local info = Sustain.ApplyShape(Panel, scaleVec, Data2, def)
	if not info then Panel:Remove() return false end

	local areaSqM = info.area * INCH_TO_M * INCH_TO_M
	Panel.Id         = Id
	Panel.SizeId     = Data1
	Panel.Shape      = Data2
	Panel.Dimensions = info.dims
	Panel.AreaSqM    = areaSqM
	Panel.Efficiency = ACF.SolarEfficiency or 0.2
	Panel.MaxPower   = areaSqM * ACF.SolarIrradiance * ACF.SolarEfficiency
	Panel.Mass       = math.max(areaSqM * ACF.SolarMassPerArea, 1)
	Panel.ACEPoints  = areaSqM * ACF.SolarPointsPerArea

	Sustain.FinishSpawn(Panel, Owner, "_ace_solarpanel", def.name or "ACE Solar Panel")

	return Panel
end

list.Set("ACFCvars", "ace_solarpanel", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_solarpanel", MakeACE_SolarPanel, "Pos", "Angle", "Id", "SizeId", "Shape")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_SolarPanel, "SolarPanels")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end

	if Target:GetClass() == "acf_fueltank" then
		if Target.FuelType ~= "Electric" then return false, "Solar panels can only charge Electric batteries!" end
		for _, Tank in pairs(self.FuelLink) do
			if Tank == Target then return false, "That battery is already linked!" end
		end
		table.insert(self.FuelLink, Target)
		return true, "Link successful!"
	end

	return false, "Can only link Electric batteries!"
end

function ENT:Unlink(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	for Key, Tank in pairs(self.FuelLink) do
		if Tank == Target then table.remove(self.FuelLink, Key) return true, "Unlink successful!" end
	end
	return false, "That entity is not linked!"
end

-- Direction pointing toward the sun (unit vector).
--
-- Prefers the map's REAL sun, read SERVER-SIDE from the env_sun entity and
-- cached in ACE.SunDir (see sh_sustain - never trusts clients). If the map has
-- no env_sun (or the env_sun option is off) we fall back to the convar sun
-- (acf_solar_sun_pitch/yaw) so panels still work on any map.
function ENT:GetSunDirection()
	if (GetConVar("acf_solar_use_envsun"):GetInt() or 0) ~= 0 and ACE.SunLastSync then
		local dir = ACE.SunDir
		if isvector(dir) and dir:LengthSqr() > 0.01 then
			return dir:GetNormalized()
		end
	end

	-- Convar sun: elevation above the horizon + compass yaw.
	local elev = GetConVar("acf_solar_sun_pitch"):GetFloat()
	local yaw  = GetConVar("acf_solar_sun_yaw"):GetFloat()
	return Angle(-elev, yaw, 0):Forward()
end

-- Overall map-brightness factor (0..1). A dark/night map produces less power.
-- Disabled by acf_solar_use_maplight 0; floored so a dim map never hits zero.
function ENT:GetMapLight()
	if (GetConVar("acf_solar_use_maplight"):GetInt() or 0) == 0 then return 1 end
	return math.max(ACE.MapBrightness or 1, ACF.SolarMapLightFloor or 0.3)
end

-- Refresh the (relatively expensive) sun direction + sky trace and cache it.
-- Called infrequently so dozens of panels stay cheap.
function ENT:RefreshSun()
	local toSun = self:GetSunDirection()

	local extent = self.Dimensions and math.max(self.Dimensions.x, self.Dimensions.y, self.Dimensions.z) or 8
	local startPos = self:GetPos() + toSun * (extent * 0.5 + 4)
	local trace = util.TraceLine({
		start  = startPos,
		endpos = startPos + toSun * 16384,
		mask   = MASK_SOLID,
		filter = self,
	})

	-- "Clear" means nothing solid is between the panel and the sky: either the
	-- trace reached a sky surface, or it hit nothing at all. (Only checking
	-- HitSky was too strict - on many maps an unobstructed trace simply runs
	-- out of length without ever touching a sky brush, which wrongly read as
	-- shadowed.)
	self.SunCache = {
		toSun    = toSun,
		startPos = startPos,
		hitPos   = trace.HitPos,
		clear    = (trace.HitSky == true) or (trace.Hit ~= true),
		angle    = math.max(0, self:GetUp():GetNormalized():Dot(toSun)),
	}
	return self.SunCache
end

function ENT:DistributeCharge(dt)
	if self.EnergyAccum <= 0 then return end
	for _, Tank in pairs(self.FuelLink) do
		if self.EnergyAccum <= 0 then break end
		if not IsValid(Tank) or not Tank.ChargeBattery then continue end
		local accepted = Tank:ChargeBattery(self.EnergyAccum, dt)
		self.EnergyAccum = math.max(self.EnergyAccum - (accepted or 0), 0)
	end
	self.EnergyAccum = 0
end

function ENT:UpdateOutputs()
	WireLib.TriggerOutput(self, "Output Power", math.Round(self.OutputPower, 3))
	WireLib.TriggerOutput(self, "Efficiency", self.Efficiency)
	WireLib.TriggerOutput(self, "Panel Area", math.Round(self.AreaSqM, 2))
	WireLib.TriggerOutput(self, "Sun Angle", math.Round(self.SunAngle or 0, 3))
	WireLib.TriggerOutput(self, "Panel Temp", math.Round(self.Heat, 1))
	WireLib.TriggerOutput(self, "Heat", math.Round(self.Heat, 1))
	WireLib.TriggerOutput(self, "Shadowed", self.Shadowed or 0)
end

function ENT:UpdateOverlayText()
	local txt = "Solar Panel"
	txt = txt .. "\nActive: " .. (self.Active and "ON" or "OFF (wire Active to 1)")
	txt = txt .. "\nOutput: " .. math.Round(self.OutputPower or 0, 3) .. " kW"
	txt = txt .. "\nMax: " .. math.Round(self.MaxPower or 0, 3) .. " kW"
	txt = txt .. "\nArea: " .. math.Round(self.AreaSqM or 0, 2) .. " m^2"
	txt = txt .. "\nSun Angle: " .. math.Round((self.SunAngle or 0) * 100, 0) .. "%"
	txt = txt .. "\nPanel Temp: " .. math.Round(self.Heat or 0, 0) .. " C"
	txt = txt .. "\nSky Clear: " .. ((self.Shadowed or 0) > 0 and "NO" or "YES")
	txt = txt .. "\nBatteries: " .. #(self.FuelLink or {})
	self:SetOverlayText(txt)
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then
		self.Active = value ~= 0
	end
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or FrameTime()
	self.LastThink = CurTime()
	local ambient = ACE.AmbientTemp or 20

	if not self.Active then
		self.OutputPower = 0
		self.Heat = HeatLogic.HeatStep(self.Heat, 0, self.Mass, 0.6, ambient, dt)
		self:UpdateOutputs()
		self:UpdateOverlayText()
		self:NextThink(CurTime() + 1)
		return true
	end

	-- The sun direction and sky trace only change slowly, so refresh and cache
	-- them at a low rate. This is the only expensive bit; keeping it infrequent
	-- means many panels (10+ players' worth) stay cheap.
	if not self.SunCache or CurTime() >= (self.NextSunRefresh or 0) then
		self:RefreshSun()
		self.NextSunRefresh = CurTime() + 1.5 + math.Rand(0, 0.5)  -- jitter so they don't all trace the same frame
	end

	local cache = self.SunCache
	self.SunAngle = cache.angle
	self.Shadowed = cache.clear and 0 or 1

	local r = SolarLogic.Output({
		maxPower  = self.MaxPower,
		sun       = cache.clear and 1 or 0,
		angle     = cache.angle,
		mapLight  = self:GetMapLight(),
		panelTemp = self.Heat,
		dt        = dt,
	})

	self.OutputPower = r.power
	self.Efficiency  = (ACF.SolarEfficiency or 0.2) * r.derate
	self.EnergyAccum = self.EnergyAccum + r.energyKWh

	-- Debug overlay (needs developer 1 on the client to render).
	local dbg = GetConVar("acf_solar_debug")
	if dbg and dbg:GetBool() then
		local life = 0.6
		local pos  = self:GetPos()
		debugoverlay.Line(cache.startPos, cache.hitPos, life, cache.clear and Color(80, 220, 80) or Color(220, 80, 80), true)
		debugoverlay.Cross(cache.hitPos, 6, life, cache.clear and Color(80, 220, 80) or Color(220, 80, 80), true)
		debugoverlay.Line(pos, pos + self:GetUp() * 28, life, Color(60, 220, 220), true)
		debugoverlay.Text(pos + self:GetUp() * 30, "FACE / UP", life)
		debugoverlay.Line(pos, pos + self:GetForward() * 28, life, Color(240, 220, 60), true)
		debugoverlay.Text(pos + self:GetForward() * 30, "FORWARD", life)
		debugoverlay.Text(pos, string.format("Sun angle %.0f%%  Clear: %s  Out: %.3f kW  Temp: %.0fC",
			cache.angle * 100, cache.clear and "YES" or "NO", self.OutputPower, self.Heat), life)
	end

	-- Sitting in still air a panel holds its heat (low dissipation), so it can
	-- bake and lose a little output - the temperature derate then matters.
	self.Heat = HeatLogic.HeatStep(self.Heat, r.heatAddJ, self.Mass, 0.6, ambient, dt)

	self:DistributeCharge(dt)

	self:UpdateOutputs()
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.5)
	return true
end

do
	function ENT:PreEntityCopy()
		local entids = {}
		for _, Tank in pairs(self.FuelLink) do
			if IsValid(Tank) then table.insert(entids, Tank:EntIndex()) end
		end
		if #entids > 0 then
			duplicator.StoreEntityModifier(self, "SolarFuelLink", { entities = entids })
		end
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.SolarFuelLink then return end
		local info = Ent.EntityMods.SolarFuelLink
		if info.entities then
			for _, idx in ipairs(info.entities) do
				local Tank = CreatedEntities[idx]
				if IsValid(Tank) and Tank:GetClass() == "acf_fueltank" then self:Link(Tank) end
			end
		end
		Ent.EntityMods.SolarFuelLink = nil
	end
end
