AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

DEFINE_BASECLASS("ace_scalability")

local Sustain = ACE.Sustain

-- Serverside: particle FX can be disabled by server owners (effects are server-driven).
local BURNER_FX = CreateConVar("acf_burner_fx", "1", FCVAR_ARCHIVE,
	"ACE: show fire particle effects on fuel burners (serverside).")

-- Default is the canister flare prop (natural size, stats from its real volume);
-- "scalable" uses the Box/Cylinder mesh at the configured L:W:H.
local BURNER_MODELS = {
	canister = "models/props_c17/canister01a.mdl",
}

function ENT:Initialize()
	self.Tank     = nil    -- the fuel tank we burn from
	self.Active   = false  -- spawns OFF; burns nothing until switched on
	self.BurnRate = 0      -- L/s it burns at full tilt
	self.Burning  = 0      -- L/s actually burned this tick
	self.Lit      = false
	self.Legal    = true
	self.IsScalable = true

	self.Inputs = WireLib.CreateInputs(self, {
		"Active",
	})
	self.Outputs = WireLib.CreateOutputs(self, {
		"Burning (Litres/sec) [NORMAL]",
		"Lit (1 when burning) [NORMAL]",
		"Entity [ENTITY]",
	})
	Wire_TriggerOutput(self, "Entity", self)
end

function MakeACE_Burner(Owner, Pos, Angle, Id, Data1, Data2, Data3)
	if IsValid(Owner) and not Owner:CheckLimit("_ace_burner") then return false end

	local def = ACF.Weapons.Burners[Id]
	if not def then return false end

	local scaleVec = Sustain.ParseScale(Data1)
	if not scaleVec then return false end

	local Burner = ents.Create("ace_burner")
	if not IsValid(Burner) then return false end

	Burner:SetAngles(Angle)
	Burner:SetPos(Pos)
	Burner:Spawn()

	local modelKey  = tostring(Data3 or "canister")
	local propModel = BURNER_MODELS[modelKey]
	local vol

	if propModel then
		Burner:SetModel(propModel)
		Burner:PhysicsInit(SOLID_VPHYSICS)
		Burner:SetMoveType(MOVETYPE_VPHYSICS)
		Burner:SetSolid(SOLID_VPHYSICS)
		local p = Burner:GetPhysicsObject()
		if IsValid(p) then p:Wake() end
		vol = (IsValid(p) and p:GetVolume() or 0) * 16.38
		Burner.IsScalable = false
	else
		local info = Sustain.ApplyShape(Burner, scaleVec, Data2, def)
		if not info then Burner:Remove() return false end
		vol = info.volume
	end
	if vol <= 0 then vol = 1 end

	Burner.Id        = Id
	Burner.SizeId    = Data1
	Burner.Shape     = Data2
	Burner.Model3    = modelKey
	Burner.BurnRate  = vol * (ACF.BurnerRatePerVolume or 0.0006)
	Burner.Mass      = math.max(vol * (ACF.BurnerMassPerVolume or 0.004), 2)
	Burner.ACEPoints = vol * (ACF.BurnerPointsPerVolume or 0.02)

	local phys = Burner:GetPhysicsObject()
	if IsValid(phys) then phys:SetMass(Burner.Mass) end

	Sustain.FinishSpawn(Burner, Owner, "_ace_burner", def.name or "Fuel Burner")

	return Burner
end

list.Set("ACFCvars", "ace_burner", {"id", "data1", "data2", "data3"})
duplicator.RegisterEntityClass("ace_burner", MakeACE_Burner, "Pos", "Angle", "Id", "SizeId", "Shape", "Model3")

ENT.SpawnFunction = ACE.Sustain.ScalableSpawn(MakeACE_Burner, "Burners")

function ENT:Link(Target)
	if not IsValid(Target) then return false, "Invalid target!" end
	if Target:GetClass() ~= "acf_fueltank" then return false, "Link a liquid fuel tank to burn from." end
	if Target.FuelType == "Electric" then return false, "A burner consumes liquid fuel, not electricity!" end
	self.Tank = Target
	self:UpdateOverlayText()
	return true, "Linked fuel tank - it will burn from this."
end

function ENT:Unlink(Target)
	if IsValid(Target) and Target == self.Tank then
		self.Tank = nil
		self:UpdateOverlayText()
		return true, "Unlink successful!"
	end
	return false, "That entity is not linked!"
end

function ENT:TriggerInput(iname, value)
	if iname == "Active" then self.Active = value ~= 0 end
end

-- Light / extinguish the flare, managing FX + sound. FX honour the serverside convar.
function ENT:SetLit(lit)
	lit = lit and true or false
	if lit == (self.Lit or false) then return end
	self.Lit = lit
	self:SetNWBool("AceBurning", lit)

	if lit then
		if BURNER_FX:GetBool() then
			ParticleEffectAttach("fire_medium_01", PATTACH_ABSORIGIN_FOLLOW, self, 0)
		end
		if not self.FireSound then
			self.FireSound = CreateSound(self, "ambient/fire/fire_med_loop1.wav")
		end
		if self.FireSound then self.FireSound:Play() end
	else
		self:StopParticles()
		if self.FireSound then self.FireSound:Stop() end
	end
end

-- Burn players standing in the flame (small radius, only while lit). Player count
-- is tiny, so a squared-distance scan here is cheaper than ents.FindInSphere.
function ENT:BurnNearbyPlayers(dt)
	local pos = self:WorldSpaceCenter()
	local r2  = (ACF.BurnerHazardRadius or 90) ^ 2
	local attacker = self:CPPIGetOwner()
	if not IsValid(attacker) then attacker = self end
	for _, ply in ipairs(player.GetAll()) do
		if not ply:Alive() then continue end
		if ply:WorldSpaceCenter():DistToSqr(pos) > r2 then continue end
		local dmg = DamageInfo()
		dmg:SetDamage((ACF.BurnerDamagePerSec or 14) * dt)
		dmg:SetDamageType(DMG_BURN)
		dmg:SetAttacker(attacker)
		dmg:SetInflictor(self)
		ply:TakeDamageInfo(dmg)
	end
end

function ENT:UpdateOverlayText()
	local txt = "Fuel Burner (flare)"
	if IsValid(self.Tank) then
		txt = txt .. "\nBurning from: " .. (self.Tank.FuelType or "?")
	else
		txt = txt .. "\nNot linked to a tank"
	end
	txt = txt .. "\nRate: " .. math.Round((self.BurnRate or 0) * 60, 2) .. " L/min"
	txt = txt .. (self.Lit and "\nLIT - burning " .. math.Round((self.Burning or 0) * 60, 1) .. " L/min" or "\nNot lit")
	txt = txt .. (self.Active and "" or "\n[OFF]")
	self:SetOverlayText(txt)
end

function ENT:Think()
	local dt = self.LastThink and (CurTime() - self.LastThink) or 0.25
	self.LastThink = CurTime()

	self.Burning = 0
	local tank = self.Tank
	if not IsValid(tank) then self.Tank = nil end

	if self.Active and IsValid(self.Tank) and self.Tank.FuelType ~= "Electric"
		and (self.Tank.Fuel or 0) > 0 then
		local want   = (self.BurnRate or 0) * dt
		local burned = math.min(want, self.Tank.Fuel or 0)
		if burned > 0 then
			self.Tank.Fuel = math.max(0, self.Tank.Fuel - burned)
			if self.Tank.UpdateFuelMass then self.Tank:UpdateFuelMass() end
			self.Burning = burned / dt
		end
	end

	self:SetLit(self.Burning > 0)
	if self.Lit then self:BurnNearbyPlayers(dt) end

	-- Publish the tank link for the ACE Grid Tool overlay.
	Sustain.NetworkAux(self, IsValid(self.Tank) and { { ent = self.Tank, label = "fuel" } } or {})

	Wire_TriggerOutput(self, "Burning", math.Round(self.Burning, 3))
	Wire_TriggerOutput(self, "Lit", self.Lit and 1 or 0)
	self:UpdateOverlayText()
	self:NextThink(CurTime() + 0.25)
	return true
end

function ENT:OnRemove()
	if self.FireSound then self.FireSound:Stop() end
	self:StopParticles()
end

do
	function ENT:PreEntityCopy()
		if IsValid(self.Tank) then
			duplicator.StoreEntityModifier(self, "BurnerLink", { tank = self.Tank:EntIndex() })
		end
	end

	function ENT:PostEntityPaste(_Player, Ent, CreatedEntities)
		if not Ent.EntityMods or not Ent.EntityMods.BurnerLink then return end
		local T = CreatedEntities[Ent.EntityMods.BurnerLink.tank]
		if IsValid(T) and T:GetClass() == "acf_fueltank" then self:Link(T) end
		Ent.EntityMods.BurnerLink = nil
	end
end
