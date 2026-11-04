AddCSLuaFile("shared.lua")
SWEP.Base = "weapon_ace_base"
SWEP.NPCMaxRange = 1000
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Grenades/Mines"

if CLIENT then
	SWEP.PrintName		= "HE Grenade"
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
SWEP.Primary.DefaultClip	= 5
SWEP.Primary.Automatic		= false
SWEP.Primary.Ammo		= "Grenade"

-- NPC throw settings (units are Hammer units, 39.37 per metre)
SWEP.NPCThrowMinRange = 300 --Enemies closer than this are not grenaded
SWEP.NPCThrowMaxRange = 1200 --Enemies farther than this are not grenaded
SWEP.NPCThrowHorizontalSpeed = 600 --Constant horizontal speed of the lob
SWEP.NPCThrowCooldown = 5 --Seconds between NPC throws

SWEP.JustDeployed = true

function SWEP:Deploy()
	if CLIENT then return end

	self.JustDeployed = true --No abusing weapon switching to spam throw grenades
	self:SendWeaponAnim(ACT_VM_DRAW)

	self:DoAmmoStatDisplay()

	return true
end

-- Shared entity setup for player and NPC throws.
local function SpawnGrenadeEntity(owner, pos, ang)
	local ent = ents.Create("ace_grenade")
	ent:SetPos(pos)
	ent:SetAngles(ang)
	ent:Spawn()
	if CPPI then
		ent:CPPISetOwner( Entity(0) )
	end
	ent.DamageOwner = owner -- Done to avoid owners from manipulating the entity, but allowing the damage to be credited by him.

	return ent
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

		local aim = owner:GetAimVector() * 9 + Vector(0,0,0.1)

		local ent = SpawnGrenadeEntity(owner, owner:GetShootPos() + Vector(0, 0, heightoffset), owner:EyeAngles())
		ent:GetPhysicsObject():ApplyForceCenter(aim * power + owner:GetVelocity() * ent:GetPhysicsObject():GetMass())
	end)
end

--- Lobs a grenade at the NPC owner's current enemy on a simple ballistic arc.
-- Does nothing when there is no valid enemy, the enemy is outside the throw band, or the cooldown is running.
-- @realm server
function SWEP:NPCThrowNade()
	local owner = self:GetOwner()

	if CurTime() < (self.NPCNextThrow or 0) then return end

	local enemy = owner:GetEnemy()
	if not IsValid(enemy) then return end

	local start = owner:GetShootPos()
	local toTarget = enemy:WorldSpaceCenter() - start
	local horizontal = Vector(toTarget.x, toTarget.y, 0)
	local dist = horizontal:Length()

	if dist < self.NPCThrowMinRange or dist > self.NPCThrowMaxRange then return end

	-- Fixed horizontal speed; the vertical speed is solved so the grenade lands on the target.
	local flightTime = dist / self.NPCThrowHorizontalSpeed
	local gravity = physenv.GetGravity()
	local vz = (toTarget.z - 0.5 * gravity.z * flightTime * flightTime) / flightTime
	local velocity = horizontal:GetNormalized() * self.NPCThrowHorizontalSpeed + Vector(0, 0, vz)

	self.NPCNextThrow = CurTime() + self.NPCThrowCooldown
	self:SetNextPrimaryFire(CurTime() + self.NPCThrowCooldown)

	self:TakePrimaryAmmo(1)
	self:EmitSound(self.Primary.Sound)

	local ent = SpawnGrenadeEntity(owner, start + Vector(0, 0, -7), velocity:Angle())
	local phys = ent:GetPhysicsObject()
	if IsValid(phys) then
		phys:SetVelocity(velocity)
	end
end

function SWEP:GetCapabilities()
	return CAP_WEAPON_RANGE_ATTACK1
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	if (self:Ammo1() == 0) and (self:Clip1() == 0) then return end

	if self:GetOwner():IsNPC() then
		if SERVER then self:NPCThrowNade() end
		return
	end

	self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
	self:SetNextSecondaryFire(CurTime() + self.Primary.Delay)

	self.JustDeployed = false

	if CLIENT then return end

	self:SendWeaponAnim(ACT_VM_PULLPIN)

	self:ThrowNade(300, -7)  -- Was 5000, now 300 for 0.3kg grenade
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
	if self:GetOwner():IsNPC() then return end --NPCs throw from their reserve directly, no clip refill

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
