SWEP.PrintName = "Flare Gun"
SWEP.Base = "weapon_ace_base"
SWEP.Spawnable = true
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Special"

SWEP.Slot = 1
SWEP.SlotPos = 1

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_pistol.mdl"
SWEP.HoldType = "pistol"
SWEP.ViewModelFlip = false

SWEP.FireRate = 0.5

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 16
SWEP.Primary.Ammo = "pistol"
SWEP.Primary.Sound = "weapons/flaregun/fire.wav"
SWEP.Primary.Automatic = false

SWEP.ReloadSound = "Weapon_Pistol.Reload"

SWEP.HasScope = false
SWEP.ZoomFOV = 60

function SWEP:PrimaryAttack()
	if self:Clip1() == 0 and self:Ammo1() > 0 then
		self:Reload()

		return
	end

	if not self:CanPrimaryAttack() then return end

	if IsFirstTimePredicted() or game.SinglePlayer() then
		self:GetOwner():ViewPunch(Angle(-1, 0, 0))
	end

	if SERVER then
		local ent = ents.Create( "ace_flare" )
		local owner = self:GetOwner()
		local function increaseDrag(e, drag)
			if not e or not e:IsValid() then return end

			if drag < 300 then
				e:GetPhysicsObject():SetDragCoefficient(drag)
				timer.Simple(0.1, function()
					increaseDrag(e, drag * 1.15)
				end)
			end
		end

		if ( IsValid( ent ) ) then

			ent:SetPos( owner:GetShootPos() )
			ent:SetAngles( owner:GetAimVector():Angle() )
			ent.Life = 1.5 / (0.4 * ACE.Missile.FlareBurnMultiplier)
			ent:Spawn()
			ent:SetOwner( Gun )
			ent:SetColor( Color( 0, 0, 1, 1 ) ) --Blue set to 1 for flare, set to 2 for chaff
			increaseDrag(ent, 10)

			if CPPI then
				ent:CPPISetOwner(owner)
			end

			local phys = ent:GetPhysicsObject()
			phys:SetVelocity( owner:GetAimVector() * 13000 )
			ent.Heat = 150

		end

		self:TakePrimaryAmmo(1)
	end

	self:EmitSound(self.Primary.Sound)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

	self:SetNextPrimaryFire(CurTime() + math.Round(1 / self.FireRate, 2))

	if self:Clip1() == 0 and self:Ammo1() > 0 then
		self:Reload()
	end
end

function SWEP:SecondaryAttack()
	return
end
