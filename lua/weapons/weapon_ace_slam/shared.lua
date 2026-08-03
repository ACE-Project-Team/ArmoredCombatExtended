AddCSLuaFile("shared.lua")
SWEP.Base = "weapon_ace_base"

DEFINE_BASECLASS("weapon_ace_base")

if CLIENT then
	SWEP.PrintName		= "Mine-S.L.A.M."
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
SWEP.Purpose		= "Laser Tripmine"
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

function SWEP:SetupDataTables()
	self:NetworkVar("Float", 1, "ExplosionDelay")

	if CLIENT then
		self:NetworkVarNotify("ExplosionDelay", function(_, _, _, delay)
			if LocalPlayer() ~= self:GetOwner() then return end

			notification.AddLegacy("Explosion Delay: " .. delay .. " seconds", NOTIFY_GENERIC, 5)
		end)
	end

	BaseClass.SetupDataTables(self)
end

function SWEP:InitBulletData()
	self.BulletData = {}
	self.BulletData.Id = "75mmHW"
	self.BulletData.Type = "HEAT"
	self.BulletData.Id = 2
	self.BulletData.Caliber = 8.4
	self.BulletData.PropLength = 6 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 20 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 2000 --He Filler or Flechette count
	self.BulletData.Data6 = 30 --HEAT ConeAng or Flechette Spread
	self.BulletData.Data7 = 0
	self.BulletData.Data8 = 0
	self.BulletData.Data9 = 0
	self.BulletData.Data10 = 1 -- Tracer
	self.BulletData.Colour = Color(255, 50, 0)
	--
	self.BulletData.Data13 = 0 --THEAT ConeAng2
	self.BulletData.Data14 = 0 --THEAT HE Allocation
	self.BulletData.Data15 = 0
	self.BulletData.AmmoType = self.BulletData.Type
	self.BulletData.FrArea = 3.1416 * (self.BulletData.Caliber / 2) ^ 2
	self.BulletData.ProjMass = self.BulletData.FrArea * (self.BulletData.ProjLength * 7.9 / 1000)
	self.BulletData.PropMass = self.BulletData.FrArea * (self.BulletData.PropLength * ACE.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.FillerVol = self.BulletData.Data5
	self.BulletData.FillerMass = self.BulletData.FillerVol * ACE.HEDensity / 1000
	self.BulletData.BoomFillerMass = self.BulletData.FillerMass / 130
	local ConeArea = 3.1416 * self.BulletData.Caliber / 2 * ((self.BulletData.Caliber / 2) ^ 2 + self.BulletData.ProjLength ^ 2) ^ 0.5
	local ConeThick = self.BulletData.Caliber / 50
	local ConeVol = ConeArea * ConeThick
	self.BulletData.SlugMass = ConeVol * 7.9 / 1000
	local Rad = math.rad(self.BulletData.Data6 / 2)
	self.BulletData.SlugCaliber = self.BulletData.Caliber - self.BulletData.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
	self.BulletData.SlugMV = (self.BulletData.FillerMass / 2 * ACE.HEPower * math.sin(math.rad(10 + self.BulletData.Data6) / 2) / self.BulletData.SlugMass) ^ ACE.HEATMVScale
	--		print("SlugMV: " .. self.BulletData.SlugMV)
	local SlugFrArea = 3.1416 * (self.BulletData.SlugCaliber / 2) ^ 2
	self.BulletData.SlugPenArea = SlugFrArea ^ ACE.PenAreaMod
	self.BulletData.SlugDragCoef = ((SlugFrArea / 10000) / self.BulletData.SlugMass) * 1000
	self.BulletData.SlugRicochet = 500 --Base ricochet angle (The HEAT slug shouldn't ricochet at all)
	self.BulletData.CasingMass = self.BulletData.ProjMass - self.BulletData.FillerMass - ConeVol * 7.9 / 1000
	self.BulletData.Fragments = math.max(math.floor((self.BulletData.BoomFillerMass / self.BulletData.CasingMass) * ACE.HEFrag), 2)
	self.BulletData.FragMass = self.BulletData.CasingMass / self.BulletData.Fragments
	--		self.BulletData.DragCoef  = 0 --Alternatively manually set it
	self.BulletData.DragCoef = ((self.BulletData.FrArea / 10000) / self.BulletData.ProjMass)
	print(self.BulletData.SlugDragCoef)
	--Don't touch below here
	self.BulletData.MuzzleVel = ACE_MuzzleVelocity(self.BulletData.PropMass, self.BulletData.ProjMass, self.BulletData.Caliber)
	self.BulletData.ShovePower = 0.2
	self.BulletData.KETransfert = 0.3
	self.BulletData.PenArea = self.BulletData.FrArea ^ ACE.PenAreaMod
	self.BulletData.Pos = Vector(0, 0, 0)
	self.BulletData.LimitVel = 800
	self.BulletData.Ricochet = 999
	self.BulletData.Flight = Vector(0, 0, 0)
	self.BulletData.BoomPower = self.BulletData.PropMass + self.BulletData.FillerMass
	--		local SlugEnergy = ACE_Kinetic( self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37 , self.BulletData.SlugMass, 999999 )
	local SlugEnergy = ACE_Kinetic(self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37, self.BulletData.SlugMass, 999999)
	self.BulletData.MaxPen = (SlugEnergy.Penetration / self.BulletData.SlugPenArea) * ACE.KEtoRHA
	--		print("SlugPen: " .. self.BulletData.MaxPen)
	--For Fake Crate
	self.BoomFillerMass = self.BulletData.BoomFillerMass
	self.Type = self.BulletData.Type
	self.BulletData.Tracer = self.BulletData.Data10
	self.Tracer = self.BulletData.Data10
	self.Caliber = self.BulletData.Caliber
	self.ProjMass = self.BulletData.ProjMass
	self.FillerMass = self.BulletData.FillerMass
	self.DragCoef = self.BulletData.DragCoef
	self.Colour = self.BulletData.Colour
	self.DetonatorAngle = 80

	self.BulletData.FuseLength = 0.1
end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end
	if (self:Ammo1() == 0) and (self:Clip1() == 0) then return end
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

	local owner = self:GetOwner()

	if CLIENT then
		local trace = owner:GetEyeTrace()
		local tracepos = trace.HitPos
		local distcheck = (owner:GetShootPos() - tracepos):Length()

		if distcheck < 100 then
			self:EmitSound(Sound(self.Primary.Sound), 100, 100, 1, CHAN_WEAPON )
		end

		return
	end

	self.BulletData.Owner = owner
	self.BulletData.Gun = self

	if not owner:HasGodMode() then

		local trace = owner:GetEyeTrace()
		local traceEnt = trace.Entity
		local hitNormal = trace.HitNormal
		local tracepos = trace.HitPos
		local distcheck = (owner:GetShootPos() - tracepos):Length()

		if distcheck < 100 then
			local ent = ents.Create( "ace_slammine" )

			if ( IsValid( ent ) ) then

				ent:SetPos( tracepos + hitNormal * 2 )
				ent:SetAngles( (owner:GetShootPos() - tracepos):Angle() + Angle(90, 0, 0) )
				--ent:SetAngles(hitNormal:Angle() + Angle(90, 0, 0))
				ent:Spawn()
				ent.Bulletdata = self.BulletData
				owner:AddCleanup( "aceexplosives", ent )

				if CPPI then
					ent:CPPISetOwner( Entity(0) )
				end

				if IsValid(traceEnt) then
					ent:SetParent(traceEnt)
				end

				ent.DamageOwner = owner -- Done to avoid owners from manipulating the entity, but allowing the damage to be credited by him.
				ent.ExplosionDelay = self:GetExplosionDelay()
			end

			self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
			owner:SetAnimation( PLAYER_ATTACK1 )

			if self:Ammo1() > 0 then
				owner:RemoveAmmo( 1, "Grenade")
			else
				self:TakePrimaryAmmo(1)
			end

		end

	end

	self.lastFire = CurTime()
end

function SWEP:SecondaryAttack()
	if SERVER then
		self:SetExplosionDelay((self:GetExplosionDelay() + 0.25) % 1.25)
	end
end

function SWEP:Think()
end

function SWEP:Deploy()
	--self:SendWeaponAnim(ACT_SLAM_TRIPMINE_ATTACH)
end

function SWEP:Reload()
	self:DefaultReload(ACT_VM_RELOAD)
	self:Think()

	return true
end
