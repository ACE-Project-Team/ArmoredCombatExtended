SWEP.PrintName = "80mm Portable Mortar"
SWEP.Base = "weapon_ace_base"
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Special"
SWEP.Purpose = "Lob HE behind cover"
SWEP.Instructions	= "Right click to deploy, left click to shoot. Movement keys while deployed to range. Shift to increase increments. Reload to change shell."
SWEP.Spawnable = true
SWEP.Slot = 3 --Which inventory column the weapon appears in
SWEP.SlotPos = 1 --Priority in which the weapon appears, 1 tries to put it at the top


--Main settings--
SWEP.FireRate = 0.65 --Rounds per second
--SWEP.FireRate = 5 --Rounds per second

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 16 --Add Ammo Regen
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "CombineCannon"
SWEP.Primary.Sound = "ace_weapons/sweps/multi_sound/at4p_multi.mp3"
SWEP.Primary.LightScale = 200 --Muzzleflash light radius
SWEP.Primary.BulletCount = 1 --Number of bullets to fire each shot, used for shotguns

SWEP.ReloadSound = "" --Sound other players hear when you reload - this is NOT your first-person sound
										--Most models have a built-in first-person reload sound

SWEP.ZoomFOV = 45
SWEP.HasScope = true --True if the weapon has a sniper-style scope


--Recoil (crosshair movement) settings--
--"Heat" is a number that represents how long you've been firing, affecting how quickly your crosshair moves upwards
SWEP.HeatReductionRate = 0 --Heat loss per second when not firing
SWEP.HeatReductionDelay = 0
SWEP.HeatPerShot = 0 --Heat generated per shot
SWEP.HeatMax = 0 --Maximum heat - determines max rate at which recoil is applied to eye angles
				--Also determines point at which random spread is at its highest intensity
				--HeatMax divided by HeatPerShot gives you how many shots until you reach MaxSpread

SWEP.AngularRecoil = 0	--Amount of angular recoil

--How much the recoil is biased to one side proportional to vertical recoil
--Positive numbers bias to the right, negative to the left
SWEP.RecoilSideBias = 0

SWEP.ZoomRecoilBonus = 1 --Reduce recoil by this amount when zoomed or scoped
SWEP.CrouchRecoilBonus = 1 --Reduce recoil by this amount when crouching
SWEP.ViewPunchAmount = 8 --Degrees to punch the view upwards each shot - does not actually move crosshair, just a visual effect


--Spread (aimcone) settings--
SWEP.BaseSpread = 4 --First-shot random spread, in degrees
SWEP.MaxSpread = 4 --Maximum added random spread from heat value, in degrees
					--If HeatMax is 0 this will be ignored and only BaseSpread will be taken into account (AT4 for example)
SWEP.MovementSpread = 0 --Increase aimcone to this many degrees when sprinting at full speed
SWEP.UnscopedSpread = 0 --Spread, in degrees, when unscoped with a scoped weapon


--Model settings--
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/mortar/mortartube.mdl"
SWEP.WorldModel = "models/weapons/mortar/mortartube.mdl"
SWEP.HoldType = "normal"

-- Adjust these variables to move the viewmodel's position
SWEP.IronSightsPos = Vector( 5.2, -5, -4 )
SWEP.IronSightsAng = Vector( 0, 0, 0 )

SWEP.DeployDelay = 4 --Time before you can fire after deploying the weapon
SWEP.CSMuzzleFlashes = true

SWEP.FuseDelay = 0

SWEP.CarrySpeedMul			= 0.75

SWEP.LastThink = 0
SWEP.RangeTick = 0
SWEP.TargetDistance = 0
SWEP.CurrentReplenishTicks = 0
SWEP.RoundType = 0 --0 for He, 1 for smoke


DEFINE_BASECLASS("weapon_ace_base")



if CLIENT then
	local TubeModel = ClientsideModel("models/weapons/mortar/mortartube.mdl")
	local BaseModel = ClientsideModel("models/weapons/mortar/mortarbottom.mdl")
	local BipodModel = ClientsideModel("models/weapons/mortar/mortar_bipod.mdl")

	-- Settings...
	TubeModel:SetSkin(1)
	TubeModel:SetNoDraw(true)

	BaseModel:SetSkin(1)
	BaseModel:SetNoDraw(true)

	BipodModel:SetSkin(1)
	BipodModel:SetNoDraw(true)

	function SWEP:DrawWorldModel()
		local _Owner = self:GetOwner()

		if IsValid(_Owner) then


			local offsetVecTube = Vector(0, 0, 0)
			local offsetAngTube = Angle(0, 0, 0)

			local offsetVecBase = Vector(0, 0, 0)
			local offsetAngBase = Angle(0, 0, 0)

			local offsetVecBipod = Vector(0, 0, 0)
			local offsetAngBipod = Angle(0, 0, 0)

			if _Owner:Crouching() then

				-- Specify a good position
				offsetVecTube = Vector(16, 27, -11)
				offsetAngTube = Angle(130, 65, 70)

				offsetVecBase = Vector(-10.5, 30, -3)
				offsetAngBase = Angle(130, 65, 100)

				offsetVecBipod = Vector(7, 37.5, -15.5)
				offsetAngBipod = Angle(130, 65, 100)

			else

				-- Specify a good position
				offsetVecTube = Vector(5, -7, 0)
				offsetAngTube = Angle(-90, -90, -90)

				offsetVecBase = Vector(-23.5, -6, 0)
				offsetAngBase = Angle(-90, 90, 140)

				offsetVecBipod = Vector(-7.1, -10, 0)
				offsetAngBipod = Angle(-90, 40, 140)

			end


			local boneid = _Owner:LookupBone("ValveBiped.Bip01_Spine2") -- Right Hand
			if not boneid then return end

			local matrix = _Owner:GetBoneMatrix(boneid)
			if not matrix then return end

			local newPos, newAng = LocalToWorld(offsetVecTube, offsetAngTube, matrix:GetTranslation(), matrix:GetAngles())

			TubeModel:SetPos(newPos)
			TubeModel:SetAngles(newAng)

			newPos, newAng = LocalToWorld(offsetVecBase, offsetAngBase, matrix:GetTranslation(), matrix:GetAngles())

			BaseModel:SetPos(newPos)
			BaseModel:SetAngles(newAng)

			newPos, newAng = LocalToWorld(offsetVecBipod, offsetAngBipod, matrix:GetTranslation(), matrix:GetAngles())

			BipodModel:SetPos(newPos)
			BipodModel:SetAngles(newAng)

			TubeModel:SetupBones()
			BaseModel:SetupBones()
			BipodModel:SetupBones()

		else
			TubeModel:SetPos(self:GetPos())
			TubeModel:SetAngles(self:GetAngles())
			BaseModel:SetPos(self:GetPos())
			BaseModel:SetAngles(self:GetAngles())
			BipodModel:SetPos(self:GetPos())
			BipodModel:SetAngles(self:GetAngles())
		end

		TubeModel:SetMaterial( "models/props_canal/metalwall005b" )
--		TubeModel:SetColor( Color(164,190,148) )
		TubeModel:DrawModel()

		BaseModel:SetMaterial( "001wmetal" )
--		BaseModel:SetColor( Color(0,0,0) )
		BaseModel:DrawModel()

		BipodModel:SetMaterial( "models/props_canal/canal_bridge_railing_01c" )
		BipodModel:DrawModel()
	end
end


function SWEP:SetupDataTables()
	BaseClass.SetupDataTables(self)

	self:NetworkVar("Float", 0, "FuseDelay")
	self:NetworkVar("Float", 1, "Distance")
	self:NetworkVar("Float", 2, "Px")
	self:NetworkVar("Int", 3, "Py")
	self:NetworkVar("Float", 4, "Pg")
end

function SWEP:OnPrimaryAttack()
	self.BulletData.Owner = self:GetOwner()
	self.BulletData.Gun = self

end

function SWEP:SecondaryAttack()
	self:OnSecondaryAttack()

	if SERVER then
		local ZS = not self:GetZoomState()
		self:SetZoomState(ZS)
		self:SetOwnerZoomSpeed(ZS)
		self:EmitSound("npc/turret_floor/click1.wav",35,75)
	end
end

function SWEP:SetOwnerZoomSpeed(setSpeed)
	if CLIENT then return end

	local owner = self:GetOwner()

	if setSpeed then
		owner:ConCommand( "+duck" )
		owner:SetWalkSpeed(10)
		owner:SetRunSpeed(10) --10 is close enough to be immobile. Any lower and the crouch anim breaks because of course it does.

		local nextFire = (CurTime() + self.DeployDelay)
		self:SetNextPrimaryFire(nextFire) -- Stop reloads from resetting the fire delay

	elseif self.NormalPlayerWalkSpeed and self.NormalPlayerRunSpeed then
		owner:ConCommand( "-duck" )
		owner:SetWalkSpeed(math.min(self.NormalPlayerWalkSpeed * self.CarrySpeedMul, self.NormalPlayerWalkSpeed))
		owner:SetRunSpeed(math.min(self.NormalPlayerRunSpeed * self.CarrySpeedMul, self.NormalPlayerRunSpeed))
	end
end

function SWEP:GetViewModelPosition( EyePos, EyeAng )
	local Mul = 1

	local Offset = self.IronSightsPos
	local AngOffset = self.IronSightsAng

	if self.IronSightsAng then
		EyeAng = EyeAng * 1

		EyeAng:RotateAroundAxis( EyeAng:Right(),	AngOffset.x * Mul )
		EyeAng:RotateAroundAxis( EyeAng:Up(),	AngOffset.y * Mul )
		EyeAng:RotateAroundAxis( EyeAng:Forward(),  AngOffset.z * Mul )
	end

	local Right	= EyeAng:Right()
	local Up		= EyeAng:Up()
	local Forward	= EyeAng:Forward()

	EyePos = EyePos + Offset.x * Right * Mul
	EyePos = EyePos + Offset.y * Forward * Mul
	EyePos = EyePos + Offset.z * Up * Mul

	return EyePos, EyeAng
end

function SWEP:InitBulletData()
	self.Primary.BulletCount = 1 --Number of bullets to fire each shot, used for shotguns
	self.BaseSpread = 4 --First-shot random spread, in degrees

	self.BulletData = {}
	self.BulletData.Id = "80mmM"
	self.BulletData.Type = "HEAT"
	self.BulletData.Id = 2
	self.BulletData.Caliber = 8 --1 = 84 m/s
	self.BulletData.PropLength = 1 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 60 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 2000 --He Filler or Flechette count
	self.BulletData.Data6 = 55 --HEAT ConeAng or Flechette Spread
	self.BulletData.Data7 = 0
	self.BulletData.Data8 = 0
	self.BulletData.Data9 = 0
	self.BulletData.Data10 = 0 -- Tracer
	self.BulletData.Colour = Color(255, 0, 0)
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
	self.BulletData.BoomFillerMass = self.BulletData.FillerMass * 2
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
	self.BulletData.DragCoef = 0

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
end

function SWEP:InitBulletData2()
	self.BaseSpread = 8 --First-shot random spread, in degrees

	self.BulletData = {}
	self.BulletData.Id = "80mmM"
	self.BulletData.Type = "SM"
	self.BulletData.Id = 6
	self.BulletData.Caliber = 8 --1 = 84 m/s
	self.BulletData.PropLength = 1 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 60 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 1000 --He Filler or Flechette count
	self.BulletData.Data6 = 55 --HEAT ConeAng or Flechette Spread
	self.BulletData.Data7 = 0
	self.BulletData.Data8 = 0
	self.BulletData.Data9 = 0
	self.BulletData.Data10 = 0 -- Tracer
	self.BulletData.Colour = Color(255, 255, 255)
	--
	self.BulletData.Data13 = 0 --THEAT ConeAng2
	self.BulletData.Data14 = 0 --THEAT HE Allocation
	self.BulletData.Data15 = 0
	self.BulletData.AmmoType = self.BulletData.Type
	self.BulletData.FrArea = 3.1416 * (self.BulletData.Caliber / 2) ^ 2
	self.BulletData.ProjMass = self.BulletData.FrArea * (self.BulletData.ProjLength * 7.9 / 1000)
	self.BulletData.PropMass = self.BulletData.FrArea * (self.BulletData.PropLength * ACE.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.FillerVol = self.BulletData.Data5
	self.BulletData.FillerMass = self.BulletData.FillerVol * ACE.HEDensity / 1000 / 3
	self.BulletData.BoomFillerMass = self.BulletData.FillerMass * 2
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
	self.BulletData.DragCoef = 0

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
end

function SWEP:InitBulletData3()
	self.BaseSpread = 4 --First-shot random spread, in degrees

	self.BulletData = {}
	self.BulletData.Id = "80mmM"
	self.BulletData.Type = "AP"
	self.BulletData.Id = 1
	self.BulletData.Caliber = 2 --1 = 84 m/s
	self.BulletData.PropLength = 1 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 1200 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 0 --He Filler or Flechette count
	self.BulletData.Data6 = 0 --HEAT ConeAng or Flechette Spread
	self.BulletData.Data7 = 0
	self.BulletData.Data8 = 0
	self.BulletData.Data9 = 0
	self.BulletData.Data10 = 1 -- Tracer
	self.BulletData.Colour = Color(255, 0, 0)
	--
	self.BulletData.Data13 = 0 --THEAT ConeAng2
	self.BulletData.Data14 = 0 --THEAT HE Allocation
	self.BulletData.Data15 = 0
	self.BulletData.AmmoType = self.BulletData.Type
	self.BulletData.FrArea = 3.1416 * (self.BulletData.Caliber / 2) ^ 2
	self.BulletData.ProjMass = self.BulletData.FrArea * (self.BulletData.ProjLength * 7.9 / 1000)
	self.BulletData.PropMass = self.BulletData.FrArea * (self.BulletData.PropLength * ACE.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg

	self.BulletData.DragCoef = 0--Alternatively manually set it
	--Don't touch below here
	self.BulletData.MuzzleVel = ACE_MuzzleVelocity(self.BulletData.PropMass, self.BulletData.ProjMass, self.BulletData.Caliber)
	self.BulletData.ShovePower = 0.2
	self.BulletData.KETransfert = 0.3
	self.BulletData.PenArea = self.BulletData.FrArea ^ ACE.PenAreaMod
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


function SWEP:Reload()
	local nextFire = util.IsValidModel( self.ViewModel ) and self:GetNextPrimaryFire() or (CurTime() + 4)

	if self:Clip1() == self.Primary.ClipSize then return end
	if self:Ammo1() == 0 then return end

	self:OnReload()

	self:DefaultReload(ACT_VM_RELOAD)

	self.Heat = 0

	self.JustReloaded = true

	self:SetNextPrimaryFire(nextFire) -- Stop reloads from resetting the fire delay
end

function SWEP:Shoot()


		if CLIENT then
		return
		end

			local owner = self:GetOwner()

			local Xdist = self.TargetDistance
			local Ydist = 0

			local GVel = 84

			if self.TargetDistance < 100 then --If chain. Deal with it.
				GVel = 47.15
			elseif  self.TargetDistance < 200  then
				GVel = 56.25
			elseif  self.TargetDistance < 300  then
				GVel = 67
			elseif  self.TargetDistance < 400  then
				GVel = 79
			elseif  self.TargetDistance < 500  then
				GVel = 89
			elseif  self.TargetDistance < 700  then
				GVel = 106.7
			else
				GVel = 126.7
			end


			local ARC = 1 -- +1 for high, -1 for direct fire
			local G = (GetConVar("sv_gravity"):GetInt() / -39.37)
			self:SetPg(G)


			local eEye = owner:EyeAngles()

			Xdist = Xdist - 7 --Because of the incline of the shells near the end of their flight, this helps bring back the distribution a smidge. It just feels right

			local calculatedAngle = (math.atan( (GVel^2 + ARC * math.sqrt(GVel^4 - G * ( G * Xdist^2 + 2 * Ydist * GVel^2))) / (G * Xdist) )) * 180 / math.pi
			local VectorPos = ( Angle(eEye.x,eEye.y,0) + Angle(calculatedAngle,0,0) + Angle( math.Rand(-0.75,0.75) * self.BaseSpread, math.Rand(-1,1) * self.BaseSpread, 0)):Forward()


			self.BulletData.MuzzleVel = GVel

			self.BulletData.Filter = {self:GetOwner()}
			self.BulletData.DragCoef = 0
			self:ACEFireBullet(owner:GetShootPos() + owner:GetVelocity() * engine.TickInterval(), VectorPos)

end

function SWEP:PrimaryAttack()
	if not self:CanPrimaryAttack() then return end

	local ZS = self:GetZoomState()
	if not ZS then return end

	self:OnPrimaryAttack()

	if self.ShotgunReload then
		self.Reloading = false
	end

	if IsFirstTimePredicted() or game.SinglePlayer() then
		local owner = self:GetOwner()

		for _ = 1, self.Primary.BulletCount do
			self:Shoot()
		end

		if game.SinglePlayer() then
			ACE_NetworkSPEffects( self, self.BulletData.PropMass) -- singleplayer, this whole function is not called clientside, so we need to network the client here
		else
			--Client is called here. So lets go as usual.
			local sounds = ACE.GSounds.GunFire[self.Primary.Sound]
			if next(sounds) then
				if SERVER then
					ACE_NetworkMPEffects(owner, self, self.BulletData.PropMass)
				else
					self:EmitSound(sounds.main.Package[math.random(#sounds.main.Package)])
				end
			elseif CLIENT then
				self:EmitSound(self.Primary.Sound)
			end

			if CLIENT then
				ACE_RenderLight(self:EntIndex(), self.Primary.LightScale, Color(255, 128, 48), self:GetPos())
			end
		end

		owner:ViewPunch(Angle(-self.ViewPunchAmount, 0, 0))

		self.Heat = math.min(self.Heat + self.HeatPerShot, self.HeatMax)
	end

	if SERVER then
		self:TakePrimaryAmmo(1)
	end
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)
	self:SetNextPrimaryFire(CurTime() + math.Round(1 / self.FireRate, 2))

	self.LastFired = CurTime()

	if self.Primary.ClipSize == 1 and self:Clip1() == 0 and self:Ammo1() > 0 then
		self:Reload()
	end
end



function SWEP:Think()

	local owner = self:GetOwner()

	if not CLIENT then

		local CT = CurTime()
		local DT = CT-self.LastThink


		if owner:KeyDown( IN_SPEED ) then
			DT = DT * 10
		end

		if owner:KeyDown( IN_FORWARD ) then

			self.TargetDistance = math.Min(self.TargetDistance + 35 * DT,1050)

		elseif owner:KeyDown( IN_BACK ) then

			self.TargetDistance = math.Max(self.TargetDistance - 35 * DT,20)

		end


		if CT > self.RangeTick then --More of a secondary thing rate
			self.RangeTick = CT + 0.1
			self:SetPx(self.TargetDistance)
			self.CurrentReplenishTicks = self.CurrentReplenishTicks + 1

			if self.CurrentReplenishTicks > 50 and owner:GetAmmoCount( "CombineCannon" ) < 16 then --Reload
				self.CurrentReplenishTicks = 0
				owner:GiveAmmo( 1, "CombineCannon", true )
			end

			if owner:KeyDown( IN_RELOAD ) then
				if self.RoundType == 1 then
					self.RoundType = 2
					self:InitBulletData2()
					self:UpdateFakeCrate()
					self:SetPy(2)
				else
					self.RoundType = 1
					self:InitBulletData()
					self:UpdateFakeCrate()
					self:SetPy(1)
				end
			end

		end


		self.LastThink = CT
	end

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

	self:OnThink()
end
