AddCSLuaFile("shared.lua")
SWEP.Base = "weapon_ace_base"
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Grenades/Mines"

if CLIENT then
	SWEP.PrintName		= "Frag Grenade"
	SWEP.Slot			= 4
	SWEP.SlotPos		= 3
end

SWEP.Spawnable		= true

--Visual
SWEP.ViewModelFlip	= true
SWEP.ViewModel		= "models/weapons/v_eq_fraggrenade.mdl"
SWEP.WorldModel		= "models/weapons/w_eq_fraggrenade.mdl"
SWEP.ReloadSound	= "weapons/knife/knife_deploy1.wav"
SWEP.HoldType		= "grenade"


-- Other settings
SWEP.Weight			= 10

-- Weapon info
SWEP.Purpose		= "BAD NADE!"
SWEP.Instructions	= "Left mouse to throw grenade"

-- Primary fire settings
SWEP.Primary.Sound			= "weapons/slam/throw.wav"
SWEP.Primary.NumShots		= 1
SWEP.Primary.Delay			= 2
SWEP.Primary.ClipSize		= 1
SWEP.Primary.DefaultClip	= 20
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo		= "Grenade"

SWEP.JustDeployed = true

function SWEP:Deploy()
	if CLIENT then return end

	self.JustDeployed = true --No abusing weapon switching to spam throw grenades
	self:SendWeaponAnim(ACT_VM_DRAW)

	self:DoAmmoStatDisplay()

	return true
end

function SWEP:ThrowNade(power, heightoffset)
	local owner = self:GetOwner()

	timer.Simple(1, function()

		timer.Simple(0.5, function()
			local wep = owner:GetActiveWeapon()
			if owner:Alive() and wep:GetClass() ~= "weapon_ace_grenade" or not owner:Alive() or wep:Clip1() == 0 then return end
			if wep.JustDeployed then return end

			wep:SendWeaponAnim(ACT_VM_DRAW)
		end)

		local wep = owner:GetActiveWeapon()
		if owner:Alive() and wep:GetClass() ~= "weapon_ace_grenade" then return end
		if wep.JustDeployed then return end

		if owner:Alive() then
			wep:EmitSound(Sound(wep.Primary.Sound), 100, 100, 1, CHAN_WEAPON)
			if wep:Ammo1() > 0 then
				owner:RemoveAmmo(1, "Grenade")
			else
				wep:TakePrimaryAmmo(1)
			end

			owner:SetAnimation( PLAYER_ATTACK1 )
		else
			power = 0
		end

		local aim = owner:GetAimVector() + Vector(0,0,0.1)

		local ent = ents.Create("ace_grenade")
		ent:SetPos(owner:GetShootPos() + Vector(0, 0, heightoffset))
		ent:SetAngles(owner:EyeAngles())
		ent:Spawn()
		ent:GetPhysicsObject():ApplyForceCenter(aim * power + owner:GetVelocity() * ent:GetPhysicsObject():GetMass())
		if CPPI then
			ent:CPPISetOwner( Entity(0) )
		end
		ent.DamageOwner = owner -- Done to avoid owners from manipulating the entity, but allowing the damage to be credited by him.
	end)
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	if (self:Ammo1() == 0) and (self:Clip1() == 0) then return end
	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

	self.JustDeployed = false

	if CLIENT then return end

	self:SendWeaponAnim(ACT_VM_PULLPIN)

	self:ThrowNade(400, -7)  -- Was 5000, now 400 for 0.4kg grenade
end


function SWEP:SecondaryAttack()
	if not self:CanPrimaryAttack() then return end
	if (self:Ammo1() == 0) and (self:Clip1() == 0) then return end
	self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

	if CLIENT then
		return
	end

	self.JustDeployed = false

	self:SendWeaponAnim( ACT_VM_PULLPIN )
	self:GetOwner():SetAnimation( ACT_HANDGRENADE_THROW1 )

	local owner = self:GetOwner()

	self:SendWeaponAnim( ACT_VM_PULLPIN  )
	owner:SetAnimation( PLAYER_ATTACK1 )

	self:ThrowNade(80, -10)  -- Was 1000, now 80 for underhand toss
end

function SWEP:Think()
	if self:Ammo1() > 0 and self:Clip1() == 0 then
		self:SetClip1(1)
		self:GetOwner():RemoveAmmo(1, "Grenade")
		self:SendWeaponAnim(ACT_VM_DRAW)
	end
end

function SWEP:Reload()
end

function SWEP:ShouldDrawViewModel()
	if self:Ammo1() == 0 and self:Clip1() == 0 then
		return false
	end

	return true
end
