AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("base_wire_entity")

function ENT:Initialize()
	self.Detonated     = false
	self.Legal         = true
	self.SpecialHealth = true
	self.SpecialDamage = true
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

-- Generic spawn used by every prebuilt variant. The variant's class supplies
-- the model + filler fraction through its ENT table (read off the created
-- entity), and we read the model's REAL physics volume at its natural size -
-- no model scaling on these props.
function ACE.MakePrebuiltExplosive(Owner, class, Pos, Angle)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_explosive") then return false end

	local stored = scripted_ents.GetStored(class)
	local def    = stored and stored.t or {}

	local Charge = ents.Create(class)
	if not IsValid(Charge) then return false end

	Charge:SetAngles(Angle)
	Charge:SetPos(Pos)
	Charge:SetModel(Charge.ChargeModel or def.ChargeModel or "models/props_junk/propanecanister001a.mdl")
	Charge:PhysicsInit(SOLID_VPHYSICS)
	Charge:SetMoveType(MOVETYPE_VPHYSICS)
	Charge:SetSolid(SOLID_VPHYSICS)
	Charge:Spawn()

	local phys    = Charge:GetPhysicsObject()
	local volCuIn = (IsValid(phys) and phys:GetVolume()) or 1000   -- model's true volume
	local fillerMass, fragMass, physMass = ACE.GetExplosiveMasses(volCuIn, Charge.FillerFraction or def.FillerFraction)

	Charge.FillerMass  = fillerMass
	Charge.FragMass    = fragMass
	Charge.BlastRadius = ACE.CalculateHERadius(fillerMass) / 39.37
	Charge.Mass        = physMass
	Charge.DamageOwner = Owner

	if IsValid(phys) then
		phys:SetMass(physMass)
		phys:EnableMotion(true)
	end

	Charge:CPPISetOwner(Owner)
	Charge:SetNWString("WireName", Charge.ChargeName or def.ChargeName or "Explosive")
	Charge:UpdateOverlayText()

	if IsValid(Owner) then
		Owner:AddCount("_ace_explosive", Charge)
		Owner:AddCleanup("acfmenu", Charge)
	end

	Wire_TriggerOutput(Charge, "Filler Mass", math.Round(fillerMass, 2))
	Wire_TriggerOutput(Charge, "Blast Radius", math.Round(Charge.BlastRadius, 1))

	return Charge
end

-- Shared by every variant's SpawnFunction (sandbox Q-menu). GMod passes the
-- concrete class name as the third argument, which is exactly the variant we
-- want to spawn.
function ENT:SpawnFunction(ply, tr, ClassName)
	if not tr or not tr.Hit then return end
	local class = ClassName or self.ClassName or "ace_bomb_satchel"
	local pos = tr.HitPos + tr.HitNormal * 16
	local ang = Angle(0, IsValid(ply) and ply:EyeAngles().yaw or 0, 0)
	return ACE.MakePrebuiltExplosive(ply, class, pos, ang)
end

function ENT:Detonate()
	if self.Detonated then return end
	self.Detonated = true

	local origin = self:WorldSpaceCenter()
	local owner  = self.DamageOwner
	if not IsValid(owner) then owner = self:CPPIGetOwner() end

	ACE.HE(origin, Vector(0, 0, 1), self.FillerMass or 0, self.FragMass or 0, owner, self, self)

	local radiusIn = ACE.CalculateHERadius(self.FillerMass or 0)
	local Flash = EffectData()
		Flash:SetOrigin(origin)
		Flash:SetNormal(Vector(0, 0, -1))
		Flash:SetRadius(math.Round(math.max(radiusIn / 39.37, 1), 2))
	util.Effect("ACF_Scaled_Explosion", Flash)

	self:Remove()
end

function ENT:TriggerInput(iname, value)
	if iname == "Detonate" and value ~= 0 then
		self:Detonate()
	end
end

function ENT:ACF_Activate(Recalc)
	self.ACF = self.ACF or {}
	local phys = self:GetPhysicsObject()
	if not IsValid(phys) then return end

	self.ACF.Area   = self.ACF.Area or (phys:GetSurfaceArea() * 6.45)
	self.ACF.Volume = self.ACF.Volume or (phys:GetVolume() * 16.38)

	local Health  = (self.ACF.Volume / ACF.Threshold) / 20
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

function ENT:ACF_OnDamage(Entity, Energy, FrArea, Angle, Inflictor, _, _Type)
	local HitRes = ACE.PropDamage(Entity, Energy, FrArea, Angle, Inflictor)
	if self.Detonated then return HitRes end

	if IsValid(Inflictor) and Inflictor:IsPlayer() then self.DamageOwner = Inflictor end

	local maxHealth  = (self.ACF and self.ACF.MaxHealth) or 1
	local health     = (self.ACF and self.ACF.Health) or maxHealth
	local dmgFrac    = (HitRes.Damage or 0) / math.max(maxHealth, 1)
	local healthFrac = math.Clamp(health / math.max(maxHealth, 1), 0, 1)

	local chance = dmgFrac * (ACF.ExplosiveCookoffMul or 4)
		+ (1 - healthFrac) * (ACF.ExplosiveCookoffLowHP or 0.25)

	if HitRes.Kill or math.random() < chance then
		timer.Simple(0, function() if IsValid(self) then self:Detonate() end end)
	end

	return HitRes
end

function ENT:UpdateOverlayText()
	local txt = self.ChargeName or "Explosive"
	txt = txt .. "\nFiller: " .. math.Round(self.FillerMass or 0, 2) .. " kg HE"
	txt = txt .. "\nBlast Radius: " .. math.Round(self.BlastRadius or 0, 1) .. " m"
	txt = txt .. "\nBlast Energy: " .. math.Round((self.FillerMass or 0) * (ACF.HEPower or 8000), 0) .. " KJ"
	txt = txt .. "\nMass: " .. math.Round(self.Mass or 0, 1) .. " kg"

	if ACE.GetRoundLethalityLine then
		local round = { Type = "HE", maxPen = 0, FrArea = 0, blastMass = self.FillerMass or 0, guidance = "Dumb" }
		local lethality = ACE.GetRoundLethalityLine(round)
		if lethality then
			txt = txt .. "\nLethality: " .. lethality
		end
	end

	txt = txt .. "\nWire 'Detonate', or shoot it to cook off"
	self:SetOverlayText(txt)
end
