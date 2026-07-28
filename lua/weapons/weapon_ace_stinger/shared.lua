SWEP.PrintName = "FIM-92 Stinger"
SWEP.Base = "weapon_ace_base"
SWEP.Category = "ACE Weapons"
SWEP.SubCategory = "Special"
SWEP.Purpose = "Fire and forget about it"
SWEP.Spawnable = true
SWEP.Slot = 3 --Which inventory column the weapon appears in
SWEP.SlotPos = 1 --Priority in which the weapon appears, 1 tries to put it at the top

DEFINE_BASECLASS("weapon_ace_base")

--Main settings--
SWEP.Primary.Delay = 8--Reload in seconds

SWEP.Primary.ClipSize = 1
SWEP.Primary.DefaultClip = 12
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "RPG_Round"
SWEP.Primary.Sound = "acf_extra/airfx/missile_launch2.wav"
SWEP.Primary.LightScale = 200 --Muzzleflash light radius
SWEP.Primary.BulletCount = 1 --Number of bullets to fire each shot, used for shotguns

SWEP.TrackSound = "acf_extra/airfx/radar_track.wav"
SWEP.LockSound = "acf_extra/ACE/missiles/Seeker/SidewinderTone.wav"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

SWEP.ReloadSound = "npc/roller/mine/rmine_blip3.wav" --Sound other players hear when you reload - this is NOT your first-person sound
										--Most models have a built-in first-person reload sound

SWEP.ZoomFOV = 40
SWEP.HasScope = true --True if the weapon has a sniper-style scope


--Recoil (crosshair movement) settings--
--"Heat" is a number that represents how long you've been firing, affecting how quickly your crosshair moves upwards
SWEP.HeatReductionRate = 11 --Heat loss per second when not firing
SWEP.HeatReductionDelay = 0.1
SWEP.HeatPerShot = 8 --Heat generated per shot
SWEP.HeatMax = 8 --Maximum heat - determines max rate at which recoil is applied to eye angles
				--Also determines point at which random spread is at its highest intensity
				--HeatMax divided by HeatPerShot gives you how many shots until you reach MaxSpread

SWEP.RecoilSideBias = 0.1 --How much the recoil is biased to one side proportional to vertical recoil
						--Positive numbers bias to the right, negative to the left

SWEP.ZoomRecoilBonus = 0.0 --Reduce recoil by this amount when zoomed or scoped
SWEP.CrouchRecoilBonus = 0.0 --Reduce recoil by this amount when crouching
SWEP.ViewPunchAmount = 90 --Degrees to punch the view upwards each shot - does not actually move crosshair, just a visual effect


--Spread (aimcone) settings--
SWEP.BaseSpread = 0.1 --First-shot random spread, in degrees
SWEP.MaxSpread = 1.5 --Maximum added random spread from heat value, in degrees
					--If HeatMax is 0 this will be ignored and only BaseSpread will be taken into account (AT4 for example)
SWEP.MovementSpread = 7 --Increase aimcone to this many degrees when sprinting at full speed
SWEP.UnscopedSpread = 0 --Spread, in degrees, when unscoped with a scoped weapon


--Model settings--
SWEP.ViewModelFlip = false
SWEP.ViewModel = "models/weapons/v_RPG.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.HoldType = "ar2"
SWEP.DeployDelay = 2 --Time before you can fire after deploying the weapon
SWEP.CSMuzzleFlashes = true

SWEP.FuseDelay = 0

SWEP.CarrySpeedMul			= 0.7

SWEP.HeatAboveAmbient = 20 --Minimum Seeker Temp

SWEP.TarEnt = NULL

-- Adjust these variables to move the viewmodel's position
SWEP.IronSightsPos = Vector( 5.2, -13, -4 )
SWEP.IronSightsAng = Vector( 0, 0, 0 )

SWEP.SeekSensitivity = 2

SWEP.Lockrate = 0.034 --Lock rate per second

function SWEP:SetupDataTables()
	self:NetworkVar("Bool", 1, "LaunchAuth")
	self:NetworkVar("Float", 1, "TarPosX")
	self:NetworkVar("Float", 2, "TarPosY")
	self:NetworkVar("Float", 3, "TarPosZ")
	self:NetworkVar("Float", 4, "LockProgress")

	BaseClass.SetupDataTables(self)
end

function SWEP:InitBulletData()
	self.BulletData = {}
	self.BulletData.Id = "75mmHW"
	self.BulletData.Type = "HE"
	self.BulletData.Id = 2
	self.BulletData.Caliber = 11
	self.BulletData.PropLength = 7.75 --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.ProjLength = 60 --Volume of the projectile as a cylinder * streamline factor (Data5) * density of steel
	self.BulletData.Data5 = 2000 --He Filler or Flechette count
	self.BulletData.Data6 = 57 --HEAT ConeAng or Flechette Spread
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
	self.BulletData.PropMass = self.BulletData.FrArea * (self.BulletData.PropLength * ACF.PDensity / 1000) --Volume of the case as a cylinder * Powder density converted from g to kg
	self.BulletData.FillerVol = self.BulletData.Data5
	self.BulletData.FillerMass = self.BulletData.FillerVol * ACF.HEDensity / 1000
	self.BulletData.BoomFillerMass = self.BulletData.FillerMass
	local ConeArea = 3.1416 * self.BulletData.Caliber / 2 * ((self.BulletData.Caliber / 2) ^ 2 + self.BulletData.ProjLength ^ 2) ^ 0.5
	local ConeThick = self.BulletData.Caliber / 50
	local ConeVol = ConeArea * ConeThick
	self.BulletData.SlugMass = ConeVol * 7.9 / 1000
	local Rad = math.rad(self.BulletData.Data6 / 2)
	self.BulletData.SlugCaliber = self.BulletData.Caliber - self.BulletData.Caliber * (math.sin(Rad) * 0.5 + math.cos(Rad) * 1.5) / 2
	self.BulletData.SlugMV = (self.BulletData.FillerMass / 2 * ACF.HEPower * math.sin(math.rad(10 + self.BulletData.Data6) / 2) / self.BulletData.SlugMass) ^ ACF.HEATMVScale
	--		print("SlugMV: " .. self.BulletData.SlugMV)
	local SlugFrArea = 3.1416 * (self.BulletData.SlugCaliber / 2) ^ 2
	self.BulletData.SlugPenArea = SlugFrArea ^ ACF.PenAreaMod
	self.BulletData.SlugDragCoef = ((SlugFrArea / 10000) / self.BulletData.SlugMass) * 1000
	self.BulletData.SlugRicochet = 500 --Base ricochet angle (The HEAT slug shouldn't ricochet at all)
	self.BulletData.CasingMass = self.BulletData.ProjMass - self.BulletData.FillerMass - ConeVol * 7.9 / 1000
	self.BulletData.Fragments = math.max(math.floor((self.BulletData.BoomFillerMass / self.BulletData.CasingMass) * ACF.HEFrag), 2)
	self.BulletData.FragMass = self.BulletData.CasingMass / self.BulletData.Fragments
	--		self.BulletData.DragCoef  = 0 --Alternatively manually set it
	self.BulletData.DragCoef = ((self.BulletData.FrArea / 10000) / self.BulletData.ProjMass)
--	print(self.BulletData.SlugDragCoef)
	--Don't touch below here
	self.BulletData.MuzzleVel = ACF_MuzzleVelocity(self.BulletData.PropMass, self.BulletData.ProjMass, self.BulletData.Caliber)
	self.BulletData.ShovePower = 0.2
	self.BulletData.KETransfert = 0.3
	self.BulletData.PenArea = self.BulletData.FrArea ^ ACF.PenAreaMod
	self.BulletData.Pos = Vector(0, 0, 0)
	self.BulletData.LimitVel = 800
	self.BulletData.Ricochet = 999
	self.BulletData.Flight = Vector(0, 0, 0)
	self.BulletData.BoomPower = self.BulletData.PropMass + self.BulletData.FillerMass
	--		local SlugEnergy = ACF_Kinetic( self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37 , self.BulletData.SlugMass, 999999 )
	local SlugEnergy = ACF_Kinetic(self.BulletData.MuzzleVel * 39.37 + self.BulletData.SlugMV * 39.37, self.BulletData.SlugMass, 999999)
	self.BulletData.MaxPen = (SlugEnergy.Penetration / self.BulletData.SlugPenArea) * ACF.KEtoRHA
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
	self.BulletData.FuseLength = 0.001
end


function SWEP:GetViewModelPosition( EyePos, EyeAng )
	local Mul = 1

	local Offset = self.IronSightsPos
	local AngOffset = self.IronSightsAng




	if ( self.IronSightsAng ) then
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

function SWEP:GetWhitelistedEntsInCone()
	local owner = self:GetOwner()

	local ScanArray = ACE.contraptionEnts
	if table.IsEmpty(ScanArray) then return {} end

	local WhitelistEnts = {}
	local LOSdata	= {}
	local LOStr		= {}

	local IRSTPos	= owner:GetShootPos()

	local entpos		= Vector()
	local difpos		= Vector()
	local dist		= 0

	local MinimumDistance = 1	*  39.37
	local MaximumDistance = 2400  *  39.37

	for _, scanEnt in ipairs(ScanArray) do

		-- skip any invalid entity
		if IsValid(scanEnt) then

			entpos  = scanEnt:GetPos()
			difpos  = entpos - IRSTPos
			dist	= difpos:Length()

			if dist > MinimumDistance and dist < MaximumDistance then
				LOSdata.start		= IRSTPos
				LOSdata.endpos		= entpos
				LOSdata.collisiongroup  = COLLISION_GROUP_WORLD
				LOSdata.filter		= function( ent ) if ( ent:GetClass() ~= "worldspawn" ) then return false end end
				LOSdata.mins			= vector_origin
				LOSdata.maxs			= LOSdata.mins

				LOStr = util.TraceHull( LOSdata )

				--Trace did not hit world
				if not LOStr.Hit then
					table.insert(WhitelistEnts, scanEnt)
				end
			end
		end
	end

	return WhitelistEnts

end

function SWEP:AcquireLock()
	local owner = self:GetOwner()

	local found			= self:GetWhitelistedEntsInCone()

	local IRSTPos		= owner:GetShootPos()

	local Owners			= {}

	self.ClosestToBeam = -1
	local besterr		= math.huge --Hugh mungus number

	local entpos			= Vector()
	local difpos			= Vector()
	local nonlocang		= Angle()
	local ang			= Angle()
	local absang			= Angle()
	local dist			= 0

	local bestEnt		= NULL

	local LockCone = 6

	for _, scanEnt in ipairs(found) do
		entpos	= scanEnt:WorldSpaceCenter()
		difpos	= (entpos - IRSTPos)

		nonlocang	= difpos:Angle()
		ang		= self:WorldToLocalAngles(nonlocang)	--Used for testing if inrange
		absang	= Angle(math.abs(ang.p), math.abs(ang.y), 0)  --Since I like ABS so much

		--Doesn't want to see through peripheral vison since its easier to focus a seeker on a target front and center of an array
		errorFromAng = 0.01 * (absang.y / 90) ^ 2 + 0.01 * (absang.y / 90) ^ 2 + 0.01 * (absang.p / 90) ^ 2

		local physEnt = scanEnt:GetPhysicsObject()

		if absang.p < LockCone and absang.y < LockCone then --Entity is within seeker cone
			--if the target is a Heat Emitter, track its heat
			if scanEnt.Heat then
				Heat = self.SeekSensitivity * scanEnt.Heat
			else --if is not a Heat Emitter, track the friction's heat

				if IsValid(physEnt) and not physEnt:IsMoveable() then
					continue
				end

				dist = difpos:Length()
				Heat = ACE.InfraredHeatFromProp(scanEnt, dist)
			end

			--Skip if not Hotter than AmbientTemp in deg C.
			if Heat > ACE.AmbientTemp + self.HeatAboveAmbient then

				--Could do pythagorean stuff but meh, works 98% of time
				local err = absang.p + absang.y

				if self.TarEnt == scanEnt then
					err = err / 8
				end

				--Sorts targets as closest to being directly in front of radar
				if err < besterr then
					self.ClosestToBeam = #Owners + 1
					besterr = err
					bestEnt = scanEnt
				end

				--debugoverlay.Line(self:GetPos(), Positions[1], 5, Color(255, 255, 0), true)
			end
		end
	end

	return bestEnt or NULL

end


local function BreakLock( self, owner )
	self:SetLockProgress(0)
	owner:StopSound( self.TrackSound )
	owner:StopSound( self.LockSound )
	self:SetLaunchAuth(false)
end

local function HasLockOnProgress( self )
	return self:GetLockProgress() > 0
end

local function InLockOn( self )
	return self:GetLockProgress() > 1
end

function SWEP:PrimaryAttack()
	if not self:GetLaunchAuth() then return end

	if self:Clip1() == 0 and self:Ammo1() > 0 then
		self:Reload()

		return
	end

	if not self:CanPrimaryAttack() then return end

	if IsFirstTimePredicted() or game.SinglePlayer() then
		self:GetOwner():ViewPunch(Angle(-1, 0, 0))
	end

	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

	if SERVER and IsValid( self.TarEnt ) and self:GetLaunchAuth() then

		local owner = self:GetOwner()

		local MDat = {
			Owner = owner,
			Launcher = owner,

			Pos = owner:GetShootPos() + owner:GetAimVector() * 75,
			Ang = owner:GetAimVector():Angle(),

			Mdl = "models/missiles/fim_92.mdl",

			TurnRate = 240,
			FinMul = 0.4,
			ThrusterTurnRate = 0,

			InitialVelocity = 60,
			Thrust = 100,
			BurnTime = 2.0,
			MotorDelay = 0,

			BoostThrust = 0,
			BoostTime = 0,
			BoostDelay = 0,

			Drag = 0.001,
			GuidanceName = "Infrared",
			FuseName = "Overshoot",
			HasInertial = true,
			HasDatalink = false,

			ArmDelay = 0.2,
			DelayPrediction = 0.1,
			ArmorThickness = 16,

			MotorSound = "acf_extra/ACE/missiles/Launch/Strela.wav",
			BoostEffect = "ACE_MissileTiny",
			MotorEffect = "ACE_MissileTiny"
		}
		local BData = self.BulletData
		BData.BulletData = nil

		BData.FakeCrate = ents.Create("acf_fakecrate2")
		BData.FakeCrate:RegisterTo(BData)
		BData.Crate = BData.FakeCrate:EntIndex()
		--self:DeleteOnRemove(BData.FakeCrate)

		local MisEnt = GenerateMissile(MDat,BData.FakeCrate,BData)
		MisEnt.TargetPos = self.TarEnt:GetPos()

		--self.MissileEntity.TargetPos
		self:EmitSound(self.Primary.Sound)
		self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
		self:GetOwner():SetAnimation(PLAYER_ATTACK1)

		if self:Ammo1() > 0 then
			self:GetOwner():RemoveAmmo( 1, "RPG_Round")
			self:SetZoomState(false)
			self:SetOwnerZoomSpeed(false)
		else
			self:TakePrimaryAmmo(1)
		end


	end
end

SWEP.NextThinkTime = 0
SWEP.ThinkDelay = 0.1

function SWEP:Think()
	if CurTime() < self.NextThinkTime then return end
	if not SERVER then return end

	local owner = self:GetOwner()

	if self:GetZoomState() then
		local lasttarget = self.TarEnt
		self.TarEnt = self:AcquireLock()
		local CurTarget = self.TarEnt
		local DontBreak = false

		if IsValid(lasttarget) then

			local RootCTarget	= ACF_GetPhysicalParent( CurTarget )
			local RootLastTarget = ACF_GetPhysicalParent( lasttarget ) --looking for the physical entity of the last target.

			if IsValid(RootCTarget) and IsValid(RootLastTarget) then

				-- Press F to pay respects to the server
				local PhysContraptionEnts = constraint.GetAllConstrainedEntities( RootCTarget ) -- how expensive will be this with contraptions over 100 constrained ents?

				for _, physEnt in pairs(PhysContraptionEnts) do

					if not IsValid(physEnt) then
						continue
					end

					if physEnt:EntIndex() == RootLastTarget:EntIndex() then
						DontBreak = true

						break
					end
				end
			end
		end

		if IsValid(self.TarEnt) and (not lasttarget) or DontBreak then
			if not HasLockOnProgress( self ) then
				owner:EmitSound( self.TrackSound, 65, 105, 1, CHAN_AUTO )
			end

			self:SetLockProgress(self:GetLockProgress() + self.Lockrate)

			if not self:GetLaunchAuth() and InLockOn( self ) then
				owner:StopSound( self.TrackSound )
				owner:EmitSound( self.LockSound, 65, 105, 0.3, CHAN_AUTO )
			end

			if InLockOn( self ) then
				self:SetLaunchAuth(true)
			end
		else
			BreakLock( self, owner )
		end

		if ( IsValid( self.TarEnt ) ) then
			local TarPos = self.TarEnt:GetPos()

			self:SetTarPosX(TarPos.x)
			self:SetTarPosY(TarPos.y)
			self:SetTarPosZ(TarPos.z)
		end

		lasttarget = self.TarEnt

	else
		BreakLock( self, owner )
	end

	self.NextThinkTime = CurTime() + self.ThinkDelay
end

function SWEP:Holster()
	if SERVER then
		self:SetZoomState(false)
		self:SetOwnerZoomSpeed(false)
	end

	local owner = self:GetOwner()
	BreakLock( self, owner )
	BaseClass.Holster(self)

	return true
end
