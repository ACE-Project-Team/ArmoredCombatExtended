AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = false

function SWEP:UpdateFakeCrate()
	if not IsValid(self.FakeCrate) then
		self.FakeCrate = ents.Create("acf_fakecrate2")
	end

	self.FakeCrate:RegisterTo(self)
	self.BulletData["Crate"] = self.FakeCrate:EntIndex()
end

function SWEP:ACEFireBullet(Position, Direction)
	if not GetConVar("ace_gunfire"):GetBool() then return end

	self.BulletData.Pos = Position
	self.BulletData.Flight = Direction * self.BulletData.MuzzleVel * 39.37

	local ShooterEnt = self:GetParent()

	if ShooterEnt:IsPlayer() or ShooterEnt:IsNPC() then
		self.BulletData.Owner = ShooterEnt
	else
		self.BulletData.Owner = ShooterEnt:CPPIGetOwner() or ShooterEnt:GetOwner() or ShooterEnt
	end

	self.BulletData.Gun = self
	self.BulletData.Crate = self.FakeCrate:EntIndex()

	if self.BeforeFire then
		self:BeforeFire()
	end

	--- Fires when an ACE SWEP shoots, before the bullet is created.
	-- @tparam Weapon wep The ACE SWEP that fired.
	-- @tparam Entity owner The player or NPC holding the weapon.
	-- @tparam table bulletData The bullet data. Pos is the start position and Flight the velocity vector.
	-- @realm server
	hook.Run("ACE_SWEPFired", self, ShooterEnt, self.BulletData)

	ACE.CreateBullet(self.BulletData)
end

local nosplode = {
	AP = true,
	APC = true,
	APCBC = true,
	APDS = true,
	APDSS = true,
	HVAP = true,
	HP = true,
	FLR = true,
	HEAT = true,
	THEAT = true
}

local nopen = {
	HE = true,
	SM = true,
	FLR = true,
	HEAT = true,
	THEAT = true
}

local heat = {
	HEAT = true
}

local heatt = {
	THEAT = true
}

function SWEP:DoAmmoStatDisplay()
	if not self.BulletData then return end

	local bdata = self.BulletData
	local roundType = bdata.Type

	if bdata.Tracer and bdata.Tracer > 0 then
		roundType = roundType .. "-T"
	end

	local sendInfo = string.format("%smm %s ammo: %im/s speed", tostring(bdata.Caliber * 10), roundType, self.ThrowVel or bdata.MuzzleVel)

	if not nopen[bdata.Type] then
		local Energy = ACE.Kinetic(bdata.MuzzleVel * 39.37, bdata.ProjMass, bdata.LimitVel)
		local MaxPen = (Energy.Penetration / bdata.PenArea) * ACE.KEtoRHA
		sendInfo = sendInfo .. string.format(", %.1fmm pen", MaxPen)
	end

	if not nosplode[bdata.Type] then
		sendInfo = sendInfo .. string.format(", %.1fm blast", bdata.FillerMass ^ 0.33 * 8)
	end

	if heat[bdata.Type] then
		sendInfo = sendInfo .. string.format(", %.1fm blast", bdata.BoomFillerMass ^ 0.33 * 8)
		local Energy = ACE.Kinetic(bdata.SlugMV * 39.37, bdata.SlugMass, 999999)
		local MaxPen = (Energy.Penetration / bdata.SlugPenArea) * ACE.KEtoRHA
		sendInfo = sendInfo .. string.format(", %.1fmm pen", MaxPen)
	end

	if heatt[bdata.Type] then
		sendInfo = sendInfo .. string.format(", %.1fm blast", bdata.BoomFillerMass ^ 0.33 * 8)

		local Energy = ACE.Kinetic(bdata.SlugMV * 39.37, bdata.SlugMass, 999999)
		local MaxPen = (Energy.Penetration / bdata.SlugPenArea) * ACE.KEtoRHA
		sendInfo = sendInfo .. string.format(", (1)%.1fmm pen", MaxPen)

		Energy = ACE.Kinetic(bdata.SlugMV2 * 39.37, bdata.SlugMass2, 999999)
		MaxPen = (Energy.Penetration / bdata.SlugPenArea2) * ACE.KEtoRHA
		sendInfo = sendInfo .. string.format(", (2)%.1fmm pen", MaxPen)
	end

	local Owner = self:GetOwner()
	if IsValid(Owner) and Owner:IsPlayer() then ACE.SendNotification(Owner, sendInfo, 10) end
end

function SWEP:Equip()
	if not self.BulletData then return end

	local owner = self:GetOwner()

	self.BulletData.Filter = {owner}

	local owner = self:GetOwner()
	if not owner:IsPlayer() then
		owner:SetMaxLookDistance( self.NPCLookDistance or 10000 )
		-- The engine stops an NPC firing past this weapon field, which defaults far
		-- shorter than ACE weapons reach.
		self:SetSaveValue( "m_fMaxRange1", self.NPCMaxRange or 4000 )
	end
end

function SWEP:OnRemove()
	if not IsValid(self.FakeCrate) then return end
	local crate = self.FakeCrate
	local owner = self:GetOwner()

	timer.Simple(15, function()
		if IsValid(crate) then
			crate:Remove()
		end
	end)

	if IsValid(owner) and owner:IsPlayer() then
		owner:SetWalkSpeed( self.NormalPlayerWalkSpeed)
		owner:SetRunSpeed( self.NormalPlayerRunSpeed)
	end

end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)

	self:InitBulletData()
	self:UpdateFakeCrate()

	self.NPCMinBurst = math.min(self.NPCMinBurst,self.Primary.ClipSize)
	self.NPCMaxBurst = math.min(self.NPCMaxBurst,self.Primary.ClipSize)

end

function SWEP:Deploy()
	local owner = self:GetOwner()

	if owner:IsPlayer() then
		self.NormalPlayerWalkSpeed = owner:GetWalkSpeed()
		self.NormalPlayerRunSpeed = owner:GetRunSpeed()

		owner:SetWalkSpeed( self.NormalPlayerWalkSpeed * self.CarrySpeedMul )
		owner:SetRunSpeed( self.NormalPlayerRunSpeed * self.CarrySpeedMul * 0.8)
	end
	self:SetNextPrimaryFire( CurTime() + self.DeployDelay )
	self:Think()
	self:DoAmmoStatDisplay()

	if self.Zoomed then
		self:SetZoom(false)
	end

	self:SendWeaponAnim(ACT_VM_DRAW)
end
