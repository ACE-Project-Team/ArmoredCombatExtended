SWEP.PrintName = "XM25"
SWEP.Base = "weapon_ace_base"
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Special"
SWEP.Purpose = "Lob HE behind cover"
SWEP.Instructions	= "Left click to shoot. Right click while sprinting to scope, Right click to lase"
SWEP.Spawnable = true
SWEP.Slot = 3 --Which inventory column the weapon appears in
SWEP.SlotPos = 1 --Priority in which the weapon appears, 1 tries to put it at the top


--Main settings--
SWEP.FireRate = 3 --Rounds per second

SWEP.Primary.ClipSize = 5
SWEP.Primary.DefaultClip = 40
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "SMG1_Grenade"
SWEP.Primary.Sound = "ace_weapons/sweps/multi_sound/scout_multi.mp3"
SWEP.Primary.LightScale = 500 --Muzzleflash light radius
SWEP.Primary.BulletCount = 1 --Number of bullets to fire each shot, used for shotguns

SWEP.ReloadSound = "weapons/ar2/npc_ar2_reload.wav" --Sound other players hear when you reload - this is NOT your first-person sound
										--Most models have a built-in first-person reload sound

SWEP.ZoomFOV = 35
SWEP.HasScope = true --True if the weapon has a sniper-style scope


--Recoil (crosshair movement) settings--
--"Heat" is a number that represents how long you've been firing, affecting how quickly your crosshair moves upwards
SWEP.HeatReductionRate = 12 --Heat loss per second when not firing
SWEP.HeatReductionDelay = 0
SWEP.HeatPerShot = 8 --Heat generated per shot
SWEP.HeatMax = 8 --Maximum heat - determines max rate at which recoil is applied to eye angles
				--Also determines point at which random spread is at its highest intensity
				--HeatMax divided by HeatPerShot gives you how many shots until you reach MaxSpread

SWEP.RecoilSideBias = 0.3 --How much the recoil is biased to one side proportional to vertical recoil
						--Positive numbers bias to the right, negative to the left

SWEP.ZoomRecoilBonus = 0.45 --Reduce recoil by this amount when zoomed or scoped
SWEP.CrouchRecoilBonus = 0.5 --Reduce recoil by this amount when crouching
SWEP.ViewPunchAmount = 2 --Degrees to punch the view upwards each shot - does not actually move crosshair, just a visual effect


--Spread (aimcone) settings--
SWEP.BaseSpread = 0 --First-shot random spread, in degrees
SWEP.MaxSpread = 4 --Maximum added random spread from heat value, in degrees
					--If HeatMax is 0 this will be ignored and only BaseSpread will be taken into account (AT4 for example)
SWEP.MovementSpread = 2 --Increase aimcone to this many degrees when sprinting at full speed
SWEP.UnscopedSpread = 0.75 --Spread, in degrees, when unscoped with a scoped weapon


--Model settings--
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/v_xm25.mdl"
SWEP.WorldModel = "models/weapons/w_xm25.mdl"
SWEP.HoldType = "ar2"
SWEP.DeployDelay = 4 --Time before you can fire after deploying the weapon
SWEP.CSMuzzleFlashes = true

SWEP.FuseDelay = 0

SWEP.CarrySpeedMul			= 0.6

DEFINE_BASECLASS("weapon_ace_base")

function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVar("Float", 0, "FuseDelay")
	self:NetworkVar("Float", 1, "Distance")
	self:NetworkVar("Float", 2, "Px")
--	self:NetworkVar("Float", 3, "Py") --Unused Var
	self:NetworkVar("Float", 3, "Pg")
end

function SWEP:OnPrimaryAttack()
	self.BulletData.Owner = self:GetOwner()
	self.BulletData.Gun = self
	self.BulletData.FuseLength = self.FuseDelay

end

function SWEP:SecondaryAttack()
	local owner = self:GetOwner()

	if owner:IsSprinting() then
		self:OnSecondaryAttack()

		if SERVER and not self.Reloading then
			local ZS = not self:GetZoomState()
			self:SetZoomState(ZS)
			self:SetOwnerZoomSpeed(ZS)
			owner:EmitSound("npc/turret_floor/click1.wav",75,75)
		end

	else

			if CLIENT then return end

		--self:EmitSound("acf_extra/airfx/satellite_target.wav",35,35)
		owner:EmitSound("npc/turret_floor/ping.wav",100,21)

			local RangeTrace = util.QuickTrace(owner:GetShootPos(), owner:GetAimVector() * 50000, {owner})

			if RangeTrace.Hit then
				local difpos = RangeTrace.HitPos - owner:GetShootPos()
				local XM25dist = difpos:Length() / 39.37
				local Xdist = ( difpos * Vector(1,1,0) ):Length() / 39.37
	--			local Ydist = ( (owner:GetShootPos().z) - RangeTrace.HitPos.z ) / 39.37 --unused
				local time = (XM25dist + 2.5) / 184.871

				self.FuseDelay = time > 0.07 and time or 0
				self:SetFuseDelay(self.FuseDelay)
				self:SetDistance(XM25dist)
				self:SetPx(Xdist)
	--			self:SetPy(Ydist) --unused
				self:SetPg(GetConVar("sv_gravity"):GetInt() * -1)
			end

			ACE.SendNotification(owner, "Fuse Delay: " .. (self.FuseDelay > 0 and (math.Round(self.FuseDelay * 184.871) .. " m") or "None"), 2)
			return

	end
end

function SWEP:InitBulletData()
	self.BulletData = {}
	---------------------------------------
	self.BulletData.Id = "25mmGL"
	self.BulletData.Type = "HEAT"
	self.BulletData.Id = 2
	self.BulletData.Caliber = 2.5 --2.5 for 25mm
	self.BulletData.PropLength = 45 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 560 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 200 --He Filler or Flechette count
	self.BulletData.Data6 = 30 --HEAT ConeAng or Flechette Spread
	self.BulletData.Data7 = 0
	self.BulletData.Data8 = 0
	self.BulletData.Data9 = 0
	self.BulletData.Data10 = 1 -- Tracer
	self.BulletData.Colour = Color(200, 180, 180)
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
	self.BulletData.BoomFillerMass = self.BulletData.FillerMass / 1
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
	self.BulletData.SlugRicochet = 999 --Base ricochet angle (The HEAT slug shouldn't ricochet at all)
	self.BulletData.CasingMass = self.BulletData.ProjMass - self.BulletData.FillerMass - ConeVol * 7.9 / 1000
	self.BulletData.Fragments = math.max(math.floor((self.BulletData.BoomFillerMass / self.BulletData.CasingMass) * ACE.HEFrag), 2)
	self.BulletData.FragMass = self.BulletData.CasingMass / self.BulletData.Fragments
	--		self.BulletData.DragCoef  = 0 --Alternatively manually set it
	self.BulletData.DragCoef = 0
	--		print(self.BulletData.SlugDragCoef)
	--Don't touch below here
	self.BulletData.MuzzleVel = ACE.MuzzleVelocity(self.BulletData.PropMass, self.BulletData.ProjMass, self.BulletData.Caliber)
	self.BulletData.ShovePower = 0.25
	self.BulletData.KETransfert = 0.1
	self.BulletData.PenArea = self.BulletData.FrArea ^ ACE.PenAreaMod
	self.BulletData.Pos = Vector(0, 0, 0)
	self.BulletData.LimitVel = 800
	self.BulletData.Ricochet = 999
	self.BulletData.Flight = Vector(0, 0, 0)
	self.BulletData.BoomPower = self.BulletData.PropMass + self.BulletData.FillerMass
	--		local SlugEnergy = ACE_Kinetic( self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37 , self.BulletData.SlugMass, 999999 )
	local SlugEnergy = ACE.Kinetic(self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37, self.BulletData.SlugMass, 999999)
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
	self.DetonatorAngle = 85
end
