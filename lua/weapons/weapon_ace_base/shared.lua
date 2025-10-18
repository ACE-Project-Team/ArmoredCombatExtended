SWEP.PrintName = "ACE Base Weapon"
SWEP.Category = "ACE - Special"
SWEP.Purpose = "The base code upon which other ACE weapons are built."
SWEP.Author = "\n Cheezus, Kemgus, and RDC"
SWEP.Spawnable = false
SWEP.Slot = 2 --Which inventory column the weapon appears in
SWEP.SlotPos = 1 --Priority in which the weapon appears, 1 tries to put it at the top


--Main settings--
SWEP.FireRate = 10 --Rounds per second

SWEP.Primary.ClipSize = 30
SWEP.Primary.DefaultClip = 120
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "SMG1"
SWEP.Primary.Sound = "ace_weapons/sweps/multi_sound/ak47_multi.mp3"
SWEP.Primary.LightScale = 200 --Muzzleflash light radius
SWEP.Primary.BulletCount = 1 --Number of bullets to fire each shot, used for shotguns

SWEP.Secondary.Ammo		= "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

SWEP.ReloadSound = "Weapon_Pistol.Reload" --Sound other players hear when you reload - this is NOT your first-person sound
										--Most models have a built-in first-person reload sound

SWEP.ReticuleSize = 25
SWEP.ZoomFOV = 60
SWEP.HasScope = false --True if the weapon has a sniper-style scope


--Recoil (crosshair movement) settings--
--"Heat" is a number that represents how long you've been firing, affecting how quickly your crosshair moves upwards
SWEP.HeatReductionRate = 150 --Heat loss per second when not firing
SWEP.HeatPerShot = 5 --Heat generated per shot
SWEP.HeatMax = 30 --Maximum heat - determines max rate at which recoil is applied to eye angles
				--Also determines point at which random spread is at its highest intensity
				--HeatMax divided by HeatPerShot gives you how many shots until you reach MaxSpread

SWEP.AngularRecoil = 1	--Amount of angular recoil

--How much the recoil is biased to one side proportional to vertical recoil
--Positive numbers bias to the right, negative to the left
SWEP.RecoilSideBias = 0.1

SWEP.ZoomRecoilBonus = 0.5 --Reduce recoil by this amount when zoomed or scoped
SWEP.CrouchRecoilBonus = 0.5 --Reduce recoil by this amount when crouching
SWEP.ViewPunchAmount = 0 --Degrees to punch the view upwards each shot - does not actually move crosshair, just a visual effect


--Spread (aimcone) settings--
SWEP.BaseSpread = 0.3 --First-shot random spread, in degrees
SWEP.MaxSpread = 3 --Maximum added random spread from heat value, in degrees
					--If HeatMax is 0 this will be ignored and only BaseSpread will be taken into account (AT4 for example)
SWEP.MovementSpread = 1.5 --Increase aimcone to this many degrees when sprinting at full speed
SWEP.UnscopedSpread = 0.5 --Spread, in degrees, when unscoped with a scoped weapon


--Model settings--
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/v_rif_ak47.mdl"
SWEP.WorldModel = "models/weapons/w_rif_ak47.mdl"
SWEP.HoldType = "ar2"
SWEP.DeployDelay = 1 --Time before you can fire after deploying the weapon
SWEP.CSMuzzleFlashes = true



SWEP.CarrySpeedMul			= 1 --WalkSpeedMult when carrying the weapon

SWEP.NormalPlayerWalkSpeed	= 200 --Default walk and sprint speed in case all else fails
SWEP.NormalPlayerRunSpeed	= 400

SWEP.NPCMinBurst = 100000 --Min bullets to fire per burst
SWEP.NPCMaxBurst = 100000 --Max bullets to fire per burst


function SWEP:GetNPCBurstSettings()
	return math.min(self.NPCMinBurst,self.Primary.ClipSize * 0.5), math.min(self.NPCMaxBurst,self.Primary.ClipSize * 0.5),0
end

function SWEP:GetNPCRestTimes()
	local SecondDelay = 1 / self.FireRate
	return SecondDelay,SecondDelay
end

SWEP.SwayScale = 0.5
SWEP.BobScale = 1.5


AddCSLuaFile("cl_ace_spawnmenu.lua")
include("cl_ace_spawnmenu.lua")

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 0, "ZoomState")
	self:NetworkVar("Int", 0, "RandomSeed")

	if SERVER then
		self:NetworkVarNotify("ZoomState", function(_, _, lastZoom, zoom)
			if zoom == lastZoom then return end

			local owner = self:GetOwner()

			if not IsValid(owner) then return end

			owner:SetCanZoom(not zoom) --Block HL2 suit zoom

			timer.Simple(0, function() --If player is in a vehicle you need to delay by 1 tick because ???
				owner:SetFOV(zoom and self.ZoomFOV or 0, 0.25)
			end)

			if self.HasScope then
				owner:EmitSound("weapons/awp/zoom.wav")
			else
				owner:EmitSound("items/pickup_quiet_03.wav")
			end
		end)
	end
end

function SWEP:InitBulletData()
	self.BulletData = {}

	self.BulletData.Id = "7.62mmMG"
	self.BulletData.Type = "AP"
	self.BulletData.Id = 1
	self.BulletData.Caliber = 0.762
	self.BulletData.PropLength = 8.5 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 2.25 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 0  --He Filler or Flechette count
	self.BulletData.Data6 = 0 --HEAT ConeAng or Flechette Spread
	self.BulletData.Data7 = 0
	self.BulletData.Data8 = 0
	self.BulletData.Data9 = 0
	self.BulletData.Data10 = 1 -- Tracer
	self.BulletData.Colour = Color(0, 255, 0)

	self.BulletData.Data13 = 0 --THEAT ConeAng2
	self.BulletData.Data14 = 0 --THEAT HE Allocation
	self.BulletData.Data15 = 0

	self.BulletData.AmmoType = self.BulletData.Type
	self.BulletData.FrArea = 3.1416 * (self.BulletData.Caliber / 2) ^ 2
	self.BulletData.ProjMass = self.BulletData.FrArea * (self.BulletData.ProjLength * 7.9 / 1000)
	self.BulletData.PropMass = self.BulletData.FrArea * (self.BulletData.PropLength * ACF.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.DragCoef = 0.01

	--Don't touch below here
	self.BulletData.MuzzleVel = ACF_MuzzleVelocity(self.BulletData.PropMass, self.BulletData.ProjMass, self.BulletData.Caliber)
	self.BulletData.ShovePower = 0.2
	self.BulletData.KETransfert = 0.3
	self.BulletData.PenArea = self.BulletData.FrArea ^ ACF.PenAreaMod * 1.1
	self.BulletData.Pos = Vector(0, 0, 0)
	self.BulletData.LimitVel = 800
	self.BulletData.Ricochet = 60
	self.BulletData.Flight = Vector(0, 0, 0)
	self.BulletData.BoomPower = self.BulletData.PropMass

	--For Fake Crate
	self.Type = self.BulletData.Type
	self.BulletData.Tracer = self.BulletData.Data10
	self.Tracer = self.BulletData.Tracer
	self.Caliber = self.BulletData.Caliber
	self.ProjMass = self.BulletData.ProjMass
	self.FillerMass = self.BulletData.Data5
	self.DragCoef = self.BulletData.DragCoef
	self.Colour = self.BulletData.Colour
end

local VECTOR = FindMetaTable("Vector")

--Code taken from here
--https://github.com/thegrb93/StarfallEx/blob/master/lua/starfall/libs_sh/vectors.lua#L420-L436
function VECTOR:RotateAroundAxis(axis, degrees, radians)
	if degrees then
		radians = math.rad(degrees)
	end

	local ca, sa = math.cos(radians), math.sin(radians)
	local x, y, z, x2, y2, z2 = axis[1], axis[2], axis[3], self[1], self[2], self[3]
	local length = (x * x + y * y + z * z) ^ 0.5
	x, y, z = x / length, y / length, z / length

	return Vector( (ca + (x ^ 2) * (1-ca)) * x2 + (x * y * (1-ca) - z * sa) * y2 + (x * z * (1-ca) + y * sa) * z2,
			(y * x * (1-ca) + z * sa) * x2 + (ca + (y ^ 2) * (1-ca)) * y2 + (y * z * (1-ca) - x * sa) * z2,
			(z * x * (1-ca) - y * sa) * x2 + (z * y * (1-ca) + x * sa) * y2 + (ca + (z ^ 2) * (1-ca)) * z2 )
end

--Need unique names for the shared random number generators
local rand1 = SWEP.PrintName .. "_recoil1"
local rand2 = SWEP.PrintName .. "_recoil2"

--Returns an X and Y position randomly placed within a circle, values range from -1 to 1
function SWEP:GetSharedRandomSpread()
	local seed = self:GetRandomSeed()
	self:SetRandomSeed(seed + 1)

	local r = math.sqrt(util.SharedRandom(rand1, 0, 1, seed))
	local theta = util.SharedRandom(rand2, 0, 1, seed + self.Primary.ClipSize) * 2 * math.pi
	local x = r * math.cos(theta)
	local y = r * math.sin(theta)

	return x, y
end

SWEP.Heat = 0

function SWEP:GetShootDir()
	local owner = self:GetOwner()
	--Inaccuracy based on player speed

	local shootDir = vector_origin

	if owner:IsPlayer() then

	local spreadX, spreadY = self:GetSharedRandomSpread()
	local degrees = math.Clamp((self.Heat / self.HeatMax) ^ 2 * self.MaxSpread + self.BaseSpread, self.BaseSpread, self.BaseSpread + self.MaxSpread)

	degrees = degrees + math.min(owner:GetVelocity():Length() / self.NormalPlayerRunSpeed, 1) * self.MovementSpread

	if not self:GetZoomState() then
		degrees = degrees + self.UnscopedSpread * (owner:Crouching() and self.CrouchRecoilBonus or 1)
	end

	spreadX = spreadX * degrees * ACF.SWEPInaccuracyMul
	spreadY = spreadY * degrees * ACF.SWEPInaccuracyMul

	shootDir = owner:GetAimVector()
	local sideAxis = shootDir:Cross(Vector(0, 0, 1)):GetNormalized()
	local upAxis = shootDir:Cross(sideAxis):GetNormalized()
	shootDir = shootDir:RotateAroundAxis(upAxis, spreadX)
	shootDir = shootDir:RotateAroundAxis(sideAxis, spreadY)

	else

		local Prof = 5 - owner:GetCurrentWeaponProficiency() --Inaccuracy multiplier based on NPC proficiency

		local spreadX, spreadY = self:GetSharedRandomSpread()
		local degrees = math.Clamp((self.Heat / self.HeatMax) ^ 2 * self.MaxSpread + self.BaseSpread, self.BaseSpread, self.BaseSpread + self.MaxSpread)
		degrees = degrees + math.min(owner:GetVelocity():Length() / self.NormalPlayerRunSpeed, 1) * self.MovementSpread

		degrees = (degrees + 0.5) * Prof

		spreadX = spreadX * degrees * ACF.SWEPInaccuracyMul
		spreadY = spreadY * degrees * ACF.SWEPInaccuracyMul

		local Enemy = owner:GetEnemy()
		local EnemyPos = Enemy:WorldSpaceCenter()
		local NPCPos = owner:GetShootPos()
		local DifPos = EnemyPos - NPCPos

		local TravelTime = DifPos:Length() / self.BulletData.MuzzleVel / 39.37 + engine.TickInterval()

		shootDir = (DifPos + Enemy:GetVelocity() * TravelTime):GetNormalized()
		local sideAxis = shootDir:Cross(Vector(0, 0, 1)):GetNormalized()
		local upAxis = shootDir:Cross(sideAxis):GetNormalized()
		shootDir = shootDir:RotateAroundAxis(upAxis, spreadX)
		shootDir = shootDir:RotateAroundAxis(sideAxis, spreadY)
	end

	return shootDir
end

function SWEP:Shoot()
	local owner = self:GetOwner()

	if SERVER then
		self.BulletData.Filter = {self:GetOwner()} -- / 200000
		if owner:IsPlayer() then
			owner:LagCompensation( true )
		end
		self:ACEFireBullet(owner:GetShootPos(), self:GetShootDir())
		if owner:IsPlayer() then
			owner:LagCompensation( false )
		end
	end
end

SWEP.LastFired = 0
SWEP.Reloading = false
SWEP.NextReload = 0

function SWEP:OnPrimaryAttack()
end

-- Used as a workaround to CallOnClient function, since it didnt work properly in some aspects for singleplayer, like having a desync of 1 clip per shot.
function SWEP:DoSPClientEffects()

	local MainSound = self.Primary.Sound
	local sounds = ACE.GSounds.GunFire[MainSound]

	if next(sounds) then
		self:EmitSound(sounds.main.Package[math.random(#sounds.main.Package)])
	else
		self:EmitSound(MainSound)
	end

	ACF_RenderLight(self:EntIndex(), self.Primary.LightScale, Color(255, 128, 48), self:GetPos())

end

function SWEP:PrimaryAttack()

	if not self:CanPrimaryAttack() then return end

	self:OnPrimaryAttack()

	if self.ShotgunReload then
		self.Reloading = false
	end
	local owner = self:GetOwner()

	if IsFirstTimePredicted() or game.SinglePlayer() then

		for _ = 1, self.Primary.BulletCount do
			self:Shoot()
		end


		if game.SinglePlayer() then
			if owner:IsPlayer() then
				ACE_NetworkSPEffects( self, self.BulletData.PropMass) -- singleplayer, this whole function is not called clientside, so we need to network the client here
			else
				ACE_NetworkMPEffects(owner, self, self.BulletData.PropMass)
			end
		else
			--Client is called here. So lets go as usual.
			local sounds = ACE.GSounds.GunFire[self.Primary.Sound]
			if next(sounds) then
				if SERVER then
					ACE_NetworkMPEffects(owner, self, self.BulletData.PropMass)
				else
					self:EmitSound(sounds.main.Package[math.random(#sounds.main.Package)])
				end
			elseif not next(sounds) and CLIENT then
				self:EmitSound(self.Primary.Sound)
			end

			if CLIENT then
				ACF_RenderLight(self:EntIndex(), self.Primary.LightScale, Color(255, 128, 48), self:GetPos())
			end
		end


		if owner:IsPlayer() then
			owner:ViewPunch(Angle(-self.ViewPunchAmount, 0, 0))
		end

		self.Heat = math.min(self.Heat + self.HeatPerShot, self.HeatMax)

	end

	if SERVER then
		self:TakePrimaryAmmo(1)
	end
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	self:SetNextPrimaryFire(CurTime() + math.Round(1 / self.FireRate, 2))

	self.LastFired = CurTime()


	if self.Primary.ClipSize == 1 and self:Clip1() == 0 and (owner:IsPlayer() and self:Ammo1() > 0) then

		self:Reload()
		return false
	end
end

function SWEP:OnSecondaryAttack()
end

function SWEP:SecondaryAttack()
	self:OnSecondaryAttack()

	if SERVER and not self.Reloading then
		local ZS = not self:GetZoomState()
		self:SetZoomState(ZS)
		self:SetOwnerZoomSpeed(ZS)
	end
end

function SWEP:Holster()
	if SERVER then
		self:SetZoomState(false)
		self:SetOwnerZoomSpeed(false)
		local owner = self:GetOwner()
		if IsValid(owner) and owner:IsPlayer() then
			self:GetOwner():SetWalkSpeed(self.NormalPlayerWalkSpeed)
			self:GetOwner():SetRunSpeed(self.NormalPlayerRunSpeed)
		end
	end

	if self.ShotgunReload then
		self.Reloading = false
	end

	return true
end

if CLIENT then
	function SWEP:AdjustMouseSensitivity()
		if self:GetZoomState() then
			local cvar = self.HasScope and GetConVar("acf_sens_scopes") or GetConVar("acf_sens_irons")

			return cvar:GetFloat()
		end
	end
end

local lastRecoilTime = SysTime()
local delta = engine.TickInterval()

function SWEP:HandleRecoil()
	local delay = self.HeatReductionDelay or (1 / self.FireRate + delta)

	if CurTime() - self.LastFired > delay then
		self.Heat = math.max(self.Heat - (self.HeatReductionRate * delta), 0)
	end

	if game.SinglePlayer() and SERVER or CLIENT then
		local owner = self:GetOwner()

		local zoomBonus = self:GetZoomState() and self.ZoomRecoilBonus or 1
		local crouchBonus = owner:Crouching() and self.CrouchRecoilBonus or 1
		local totalBonus = zoomBonus * crouchBonus

		local eyeAngles = owner:EyeAngles()
		eyeAngles.p = eyeAngles.p - delta * self.AngularRecoil * self.Heat / self.HeatMax * totalBonus
		eyeAngles.y = eyeAngles.y - delta * self.AngularRecoil * self.Heat / self.HeatMax * self.RecoilSideBias * totalBonus
		owner:SetEyeAngles(eyeAngles)
	end

	delta = self.JustReloaded and 0 or (SysTime() - lastRecoilTime)
	lastRecoilTime = SysTime()

	self.JustReloaded = false
end

function SWEP:OnThink()
end

function SWEP:Think()
	if CLIENT and not self.m_bInitialized then
		self:Initialize()
	end

	if self.ShotgunReload and CurTime() > self.NextReload and self.Reloading then
		if self:Clip1() < self.Primary.ClipSize and self:Ammo1() > 0 then
			self:EmitSound(Sound(self.ReloadSound))
			self:SendWeaponAnim(ACT_VM_RELOAD)
			self:SetClip1(self:Clip1() + 1)
			self:GetOwner():RemoveAmmo(1, self:GetPrimaryAmmoType())

			self.NextReload = CurTime() + 0.5
		elseif (self:Clip1() == self.Primary.ClipSize or self:Ammo1() == 0) and self.Reloading then
			self:SendWeaponAnim(ACT_SHOTGUN_RELOAD_FINISH)

			self.Reloading = false
		end
	end


	self:HandleRecoil()
	self:OnThink()
end

function SWEP:OnReload()
end

SWEP.JustReloaded = false

function SWEP:Reload()
	local nextFire = util.IsValidModel( self.ViewModel ) and self:GetNextPrimaryFire() or (CurTime() + 4)

	if self:Clip1() == self.Primary.ClipSize then return end

	local owner = self:GetOwner()

	if owner:IsPlayer() and self:Ammo1() == 0 then return end

	self:OnReload()

	if self.ShotgunReload then
		if CurTime() > self.NextReload and not self.Reloading and self:Clip1() < self.Primary.ClipSize and self:Ammo1() > 0 then
			self:SendWeaponAnim(ACT_SHOTGUN_RELOAD_START)
			self.Reloading = true
			self.NextReload = CurTime() + 0.5
		end
	else
		self:DefaultReload(ACT_VM_RELOAD)
	end

	self.Heat = 0

	if SERVER then
		self:SetZoomState(false)
		self:SetOwnerZoomSpeed(false)

		if self.ReloadSound then
			self:EmitSound(self.ReloadSound)
		end
	end

	self.JustReloaded = true

	self:SetNextPrimaryFire(nextFire) -- Stop reloads from resetting the fire delay
end

function SWEP:Deploy()

	self.Heat = 0

	self:SendWeaponAnim(ACT_VM_DRAW)
	self:SetNextPrimaryFire(CurTime() + self.DeployDelay)


	local owner = self:GetOwner()
	if not owner:IsPlayer() then
		owner:SetMaxLookDistance( 10000 )
	end
end



function SWEP:SetOwnerZoomSpeed(setSpeed)
	if CLIENT then return end

	local owner = self:GetOwner()

	if IsValid(owner) and owner:IsPlayer() then
		if setSpeed then
			owner:SetWalkSpeed(math.min(self.NormalPlayerWalkSpeed * 0.5 * self.CarrySpeedMul, self.NormalPlayerWalkSpeed))
			owner:SetRunSpeed(math.min(self.NormalPlayerRunSpeed * 0.5 * self.CarrySpeedMul, self.NormalPlayerRunSpeed))
		elseif self.NormalPlayerWalkSpeed and self.NormalPlayerRunSpeed then
			owner:SetWalkSpeed(math.min(self.NormalPlayerWalkSpeed * self.CarrySpeedMul, self.NormalPlayerWalkSpeed))
			owner:SetRunSpeed(math.min(self.NormalPlayerRunSpeed * self.CarrySpeedMul, self.NormalPlayerRunSpeed))
		end
	end
end
