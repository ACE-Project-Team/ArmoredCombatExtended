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

	if ShooterEnt:IsPlayer() then
		self.BulletData.Owner = ShooterEnt
	else
		self.BulletData.Owner = ShooterEnt:CPPIGetOwner() or ShooterEnt:GetOwner() or ShooterEnt
	end

	self.BulletData.Gun = self
	self.BulletData.Crate = self.FakeCrate:EntIndex()

	if self.BeforeFire then
		self:BeforeFire()
	end

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

	ACE.SendNotification(self:GetOwner(), sendInfo, 10)
end

function SWEP:Equip()
	if not self.BulletData then return end

	local owner = self:GetOwner()

	self.BulletData.Filter = {owner}

	local owner = self:GetOwner()
	if not owner:IsPlayer() then
		owner:SetMaxLookDistance( 10000 )
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

	self.NormalPlayerWalkSpeed = owner:GetWalkSpeed()
	self.NormalPlayerRunSpeed = owner:GetRunSpeed()

	owner:SetWalkSpeed( self.NormalPlayerWalkSpeed * self.CarrySpeedMul )
	owner:SetRunSpeed( self.NormalPlayerRunSpeed * self.CarrySpeedMul * 0.8)
	self:SetNextPrimaryFire( CurTime() + self.DeployDelay )
	self:Think()
	self:DoAmmoStatDisplay()

	if self.Zoomed then
		self:SetZoom(false)
	end

	self:SendWeaponAnim(ACT_VM_DRAW)
end
