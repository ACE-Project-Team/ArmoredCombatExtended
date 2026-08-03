AddCSLuaFile("shared.lua")
SWEP.Base = "weapon_ace_base"

if CLIENT then
	SWEP.PrintName		= "Mine-Anti Personel"
	SWEP.Slot			= 4
	SWEP.SlotPos		= 3
end

SWEP.Spawnable		= true

SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Grenades/Mines"

--Visual
SWEP.ViewModelFlip	= false
SWEP.ViewModel		= "models/weapons/v_slam.mdl"
SWEP.WorldModel		= "models/weapons/w_slam.mdl"
SWEP.ReloadSound	= "Weapon_Pistol.Reload"
SWEP.HoldType		= "rpg"
SWEP.CSMuzzleFlashes	= true


-- Other settings
SWEP.Weight			= 10

-- Weapon info
SWEP.Purpose		= "Achtung Minen!"
SWEP.Instructions	= "Left mouse to drop mine"

-- Primary fire settings
SWEP.Primary.Sound			= "weapons/slam/mine_mode.wav"
SWEP.Primary.NumShots		= 1
SWEP.Primary.Recoil			= 10
SWEP.Primary.RecoilAngle	= 15
SWEP.Primary.Cone			= 0.025
SWEP.Primary.Delay			= 1
SWEP.Primary.ClipSize		= 1
SWEP.Primary.DefaultClip	= 11
SWEP.Primary.Automatic		= 0
SWEP.Primary.Ammo		= "CombineHeavyCannon"

SWEP.ReloadSoundEnabled = 1

SWEP.AimOffset = Vector(0, 0, 0)
SWEP.InaccuracyAccumulation = 0
SWEP.lastFire = CurTime()

SWEP.MaxInaccuracyMult = 5
SWEP.InaccuracyAccumulationRate = 0.3
SWEP.InaccuracyDecayRate = 1

SWEP.IronSights = true
SWEP.IronSightsPos = Vector(-2, -15, 2.98)
SWEP.ZoomPos = Vector(2, -2, 2)
SWEP.IronSightsAng = Angle(0.45, 0, 0)
SWEP.CarrySpeedMul = 0.6 --WalkSpeedMult when carrying the weapon

SWEP.ZoomAccuracyImprovement = 0.5 -- 0.3 means 0.7 the inaccuracy
SWEP.ZoomRecoilImprovement = 0.2 -- 0.3 means 0.7 the recoil movement

SWEP.CrouchAccuracyImprovement = 0.4 -- 0.3 means 0.7 the inaccuracy
SWEP.CrouchRecoilImprovement = 0.2 -- 0.3 means 0.7 the recoil movement

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	if (self:Ammo1() == 0) and (self:Clip1() == 0) then return end
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
	self:EmitSound(Sound(self.Primary.Sound), 100, 100, 1, CHAN_WEAPON )

	if CLIENT then
		return
	end

	local Owner = self:GetOwner()

	self.BulletData.Owner = owner
	self.BulletData.Gun = self

	if not Owner:HasGodMode() then

		local Forward   = Owner:EyeAngles():Forward()
		local Pos       = Owner:GetShootPos() + Forward * 32
		local Angle     = Owner:EyeAngles()

		ACE_CreateMine( "APL", Pos, Angle, Owner )

	end

	self.lastFire = CurTime()

	self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
	Owner:SetAnimation( PLAYER_ATTACK1 )

	if self:Ammo1() > 0 then
		Owner:RemoveAmmo( 1, "Grenade")
	else
		self:TakePrimaryAmmo(1)
	end
end

function SWEP:SecondaryAttack()
end

function SWEP:Think()
end

function SWEP:Reload()

	--if self:Clip1() < self.Primary.ClipSize and self:Ammo1() > 0 and self.ReloadSoundEnabled == 1 then
--	self:EmitSound(Sound(self.ReloadSound))
	--end
	self:DefaultReload(ACT_VM_RELOAD)

--player.GetByID( 1 ):GiveAmmo( 30-self:Clip1(), "AR2", true )
	self:Think()
	return true
end



