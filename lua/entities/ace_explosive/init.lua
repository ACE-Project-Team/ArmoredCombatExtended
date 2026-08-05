AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Scalable = ACE.Scalable

local CUIN_TO_CM3 = 16.387   -- cubic inches -> cm^3
local STEEL_DENS  = 7.9      -- g/cm^3 (casing)

-- Filler / casing masses from a charge volume (cu in). Filler uses the same HE
-- density as shells (scaled by ExplosiveHEMul so a hand charge carries a few kg,
-- not tens). Returns: fillerMass (HE), fragMass (casing, for blast frag),
-- physMass (what the prop actually weighs - much lighter than solid steel, since
-- a charge is mostly filler + thin casing, not a billet).
function ACE_GetExplosiveMasses(volCuIn, fillerFraction)
	local f         = fillerFraction or ACE.ExplosiveFillerFraction or 0.65
	local mul       = ACE.ExplosiveHEMul or 0.12
	local cm3       = volCuIn * CUIN_TO_CM3
	local fillerVol = cm3 * f
	local casingVol = cm3 * (1 - f)

	local fillerMass = fillerVol * ACE.HEDensity / 1000 * mul
	local fragMass   = casingVol * STEEL_DENS / 1000
	local physMass   = fillerMass + fragMass * (ACE.ExplosiveCasingMul or 0.08)

	return fillerMass, fragMass, math.max(physMass, 1)
end

function ENT:Initialize()
	self.Detonated     = false
	self.Legal         = true
	self.SpecialHealth = true   -- use our ACE_Activate for HP
	self.SpecialDamage = true   -- use our ACE_OnDamage (cook-off)
	self.IsExplosive   = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Detonate (Any non-zero value sets it off) [NORMAL]",
	})

	self.Outputs = WireLib.CreateOutputs(self, {
		"Filler Mass (kg of HE) [NORMAL]",
		"Blast Radius (m) [NORMAL]",
		"Entity [ENTITY]",
	})

	Wire_TriggerOutput(self, "Entity", self)
end

function ACE_MakeExplosive(Owner, Pos, Angle, Id, Data1, Data2)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_explosive") then return false end

	local def = ACE.Weapons.Explosives[Id]
	if not def then return false end

	-- Charges carry their own size limits (well under the global crate limit) so a
	-- max-size build is a demolition charge, not a map-clearing nuke.
	local scaleVec = Scalable.ParseScale(Data1, { min = ACE.ScalableMinimumSize or 1, max = def.MaxSize })
	if not scaleVec then return false end

	local Charge = ents.Create("ace_explosive")
	if not IsValid(Charge) then return false end

	Charge:SetAngles(Angle)
	Charge:SetPos(Pos)
	Charge:Spawn()

	local info = Scalable.ApplyShape(Charge, scaleVec, Data2, def)
	if not info then Charge:Remove() return false end

	local fillerMass, fragMass, physMass = ACE_GetExplosiveMasses(info.volume, def.FillerFraction)

	Charge.Id          = Id
	Charge.SizeId      = Data1
	Charge.Shape       = Data2
	Charge.Dimensions  = info.dims
	Charge.FillerMass  = fillerMass
	Charge.FragMass    = fragMass
	Charge.BlastRadius = ACE_CalculateHERadius(fillerMass) / 39.37   -- metres
	Charge.Mass        = physMass
	Charge.DamageOwner = Owner

	Scalable.FinishSpawn(Charge, Owner, "_ace_explosive", def.name or "Explosive Charge")

	Wire_TriggerOutput(Charge, "Filler Mass", math.Round(fillerMass, 2))
	Wire_TriggerOutput(Charge, "Blast Radius", math.Round(Charge.BlastRadius, 1))

	return Charge
end

list.Set("ACFCvars", "ace_explosive", {"id", "data1", "data2"})
duplicator.RegisterEntityClass("ace_explosive", ACE_MakeExplosive, "Pos", "Angle", "Id", "SizeId", "Shape")

function ENT:Detonate()
	if self.Detonated then return end
	if not ACE.RequireEntityLegal(self) then return end
	self.Detonated = true

	local origin = self:WorldSpaceCenter()
	local owner  = self.DamageOwner
	if not IsValid(owner) then owner = self:CPPIGetOwner() end

	-- Identical to how HE rounds deal their blast.
	ACE_HE(origin, Vector(0, 0, 1), self.FillerMass or 0, self.FragMass or 0, owner, self, self)

	local radiusIn = ACE_CalculateHERadius(self.FillerMass or 0)
	local Flash = EffectData()
		Flash:SetOrigin(origin)
		Flash:SetNormal(Vector(0, 0, -1))
		Flash:SetRadius(math.Round(math.max(radiusIn / 39.37, 1), 2))
	util.Effect("ACE_Scaled_Explosion", Flash)

	self:Remove()
end

function ENT:TriggerInput(iname, value)
	if iname == "Detonate" and value ~= 0 then
		self:Detonate()
	end
end

-- ACF health setup, mirrored from the ammo crate (volume-based HP).
function ENT:ACF_Activate(Recalc)
	self.ACF = self.ACF or {}
	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end

	self.ACF.Area   = self.ACF.Area or (phys:GetSurfaceArea() * 6.45)
	self.ACF.Volume = self.ACF.Volume or (phys:GetVolume() * 16.38)

	local Health  = (self.ACF.Volume / ACE.Threshold) / 20
	local Percent = 1
	if Recalc and self.ACF.Health and self.ACF.MaxHealth then
		Percent = self.ACF.Health / self.ACF.MaxHealth
	end

	self.ACF.Health    = Health * Percent
	self.ACF.MaxHealth = Health
	local Armour = (phys:GetMass() * 1000 / self.ACF.Area / 0.78)
	self.ACF.Armour    = Armour * (0.5 + Percent / 2)
	self.ACF.MaxArmour = Armour
	self.ACF.Type      = "Prop"
	self.ACF.Mass      = self.Mass
	self.ACF.Material  = self.ACF.Material or "RHA"
end

-- Cook off when shot. Each hit has a chance to set it off that grows with how
-- hard the hit was and how damaged the charge already is, so you don't have to
-- grind its HP all the way to zero - a couple of solid hits will do it.
function ENT:ACF_OnDamage(Entity, Energy, FrArea, Angle, Inflictor, _, _Type)
	local HitRes = ACE_PropDamage(Entity, Energy, FrArea, Angle, Inflictor)
	if self.Detonated then return HitRes end

	if IsValid(Inflictor) and Inflictor:IsPlayer() then self.DamageOwner = Inflictor end

	local maxHealth  = (self.ACF and self.ACF.MaxHealth) or 1
	local health     = (self.ACF and self.ACF.Health) or maxHealth
	local dmgFrac    = (HitRes.Damage or 0) / math.max(maxHealth, 1)
	local healthFrac = math.Clamp(health / math.max(maxHealth, 1), 0, 1)

	local chance = dmgFrac * (ACE.ExplosiveCookoffMul or 4)
		+ (1 - healthFrac) * (ACE.ExplosiveCookoffLowHP or 0.25)

	if HitRes.Kill or math.random() < chance then
		-- Tiny delay so the killing blow resolves before the blast.
		timer.Simple(0, function() if IsValid(self) then self:Detonate() end end)
	end

	return HitRes
end

function ENT:UpdateOverlayText()
	local txt = "Explosive Charge"
	txt = txt .. "\nFiller: " .. math.Round(self.FillerMass or 0, 2) .. " kg HE"
	txt = txt .. "\nBlast Radius: " .. math.Round(self.BlastRadius or 0, 1) .. " m"
	txt = txt .. "\nBlast Energy: " .. math.Round((self.FillerMass or 0) * (ACE.HEPower or 8000), 0) .. " KJ"
	txt = txt .. "\nMass: " .. math.Round(self.Mass or 0, 1) .. " kg"

	if ACE_GetRoundLethalityLine then
		local round = { Type = "HE", maxPen = 0, FrArea = 0, blastMass = self.FillerMass or 0, guidance = "Dumb" }
		local lethality = ACE_GetRoundLethalityLine(round)
		if lethality then
			txt = txt .. "\nLethality: " .. lethality
		end
	end

	txt = txt .. "\nWire 'Detonate', or shoot it to cook off"
	self:SetOverlayText(txt)
end
