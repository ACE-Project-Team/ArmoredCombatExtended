AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

DEFINE_BASECLASS("acf_explosive")

--local GunTable	= ACF.Weapons.Guns
--local GuidanceTable = ACF.Guidance
--local FuseTable	= ACF.Fuse

function ENT:Initialize()



	--self:PhysicsInit(SOLID_NONE)
	self:SetMoveType(MOVETYPE_NONE)


	self.PhysObj = self:GetPhysicsObject()

	if not IsValid(self.PhysObj) then self:Remove() return end --Prevent duping missiles (to stop errors)

	self.BaseClass.Initialize(self)

	if not IsValid(self:CPPIGetOwner()) then
		self:CPPISetOwner(game.GetWorld())
	end

	self.PhysObj:EnableGravity( false )
	self.PhysObj:EnableMotion( false )

	self.SpecialHealth	= false  --If true needs a special ACF_Activate function
	self.SpecialDamage	= true  --If true needs a special ACF_OnDamage function

	self.MissileActive = false --False on rack, true in flight.

	self.Flight = Vector(0,0,0)
	self.LastVel = self.Flight
	self.CurPos = self:GetPos()
	--Glide phase?

	self.LastThink = ACF.CurTime


	self.FirstThink = true

	self.JustLaunched = true
	self.TimeOfLaunch = 0
	self.LastPos = Vector()
	self.ThinkDelay = engine.TickInterval()
	self.Exploded = false

	self.CanDetonate = false

	self.MissilePosition = self:GetPos()
	self.IsUnderWater = 0

	self.P = Angle(0,0,0)
	self.I = Angle(0,0,0)
	self.D = Angle(0,0,0)

	self.Pm = 0.75 --2 0.05
	self.Im = 0.25 --0.25
	self.IaccumulateMod = 0.1 --40
	self.Dm = 0.5

	--[[
	self.Pm = 0.75 --2 0.05
	self.Im = 0.25 --0.25
	self.IaccumulateMod = 0.1 --40
	self.Dm = 0.5
	]]--

	self.Speed = 0

	self.GuidanceActive = false
	self.GuidanceActivationDelay = self.GuidanceActivationDelay or 0
	self.TargetAcquired = false
	self.TargetDir		= Vector(0,0,0)

	self.TargetPos		= nil
	self.TargetVelocity = Vector(0,0,0) --Used when target is lost by inertial guidance to shift target position by last known target velocity.

	self.IgnitionDelay = 0

	self.WaterZHeight = -1 --If set to >=0 it will indicate it's a torpedo.
	self.UpdateFX = true

	--ECM Jamming
	self.IsJammed			= 0
	self.NextJamCheck		= 0
	self.ResetJamDelay		= 1 --Periodically resets jamming strength to zero for the jammer to apply the highest noise available. This means the jamming won't always remain at full strength without a lot of networking.

	self:SetNW2Bool("MissileActive", false)


	--[[
	self.LOSTraceData = {
		mins = vector_origin,
		maxs = vector_origin,
		filter = {self},
	}
	--
	]]
end



function ENT:Think()

	if self.Exploded then return true end

	local CT = ACF.CurTime
	DeltaTime = CT - self.LastThink
	self.LastThink = CT
	self:NextThink( CT + self.ThinkDelay )

	local Pos = self.MissilePosition
	--local DeltaPos = (Pos - self.LastPos)/DeltaTime

	self.LastVel = self.Flight * 39.37
	self.CurPos = Pos

	if self.FirstThink == true then
		self.FirstThink = false
		self:ConfigureMissile()

	end

	self.Speed = self.Flight:Length()

	local FlightDir = self.Flight:GetNormalized()
	local Facing = self:GetForward()
	local AngleOfAttack = math.min(math.abs(math.acos(FlightDir:Dot( Facing ))),0.785) --45*180/3.14
	--local DifFacing = (Facing:Angle() - FlightDir:Angle())
	local DifFacing = (FlightDir:Angle() - Facing:Angle())
	DifFacing = Angle(math.NormalizeAngle(DifFacing.pitch),math.NormalizeAngle(DifFacing.yaw),0)

	local LastWater = self.IsUnderWater
	self.IsUnderWater = self:WaterLevel() / 3

	if math.ceil(LastWater) ~= math.ceil(self.IsUnderWater) then
		self.UpdateFX = true

			local WaterTr = { }
			WaterTr.start = Pos - self.Flight * 10
			WaterTr.endpos = Pos + self.Flight * 500
			WaterTr.mask = MASK_WATER
			local Water = util.TraceLine( WaterTr )
			if Water.Hit then
				local Sparks = EffectData()
				Sparks:SetOrigin( Pos )
				Sparks:SetScale( self.Bulletdata2["Caliber"] * 2 )
				util.Effect( "watersplash", Sparks )
			end
	end

	if self.WaterZHeight == 0 then
		local WaterTr = { }
		WaterTr.start = Pos + Vector(0,0, 50000)
		WaterTr.endpos = Pos
		WaterTr.mask = MASK_WATER
		local Water = util.TraceLine( WaterTr )

		if Water.Hit then
			self.WaterZHeight = Water.HitPos.z
		end

	elseif self.WaterZHeight ~= -1 then
		--print(Pos.z - self.WaterZHeight)
		if Pos.z < self.WaterZHeight and Pos.z - self.WaterZHeight > -500 and self.MissileActive and CT > (self.NextWaterSplash or 0) then
			self.NextWaterSplash = CT + 0.03
			self.WaterZHeight = self.WaterZHeight
			local Sparks = EffectData()
			Sparks:SetOrigin( Vector(Pos.x, Pos.y, self.WaterZHeight) )
			Sparks:SetScale( self.RoundWeight / 50 )
			util.Effect( "waterripple", Sparks )
		end

	end

	--[[
	local Sparks = EffectData()
	Sparks:SetOrigin( Water.HitPos + Vector(0,0,0) )
	Sparks:SetScale( self.RoundWeight / 50 )
	util.Effect( "waterripple", Sparks )
	]]--

	local DMul = 1
	local GMul = 1
	if self.IsUnderWater > 0 then
		DMul = 1 + 60 * self.IsUnderWater
		GMul = math.max(1 - self.Buoyancy * self.IsUnderWater,0)
	end

	--------------------------
	-----Guidance Section-----
	--------------------------

	self.TargetAcquired = false
	--self.TargetDir = Vector()

	--
	if self.GuidanceActive and (self.Guidance.Name ~= "Dumb") then
		--print("Active")
		-- Guidance calculations
		local Guidance  = self.Guidance:GetGuidance(self)
		local TestPos = nil

		if Guidance.TargetPos then --Only updates with a valid position
			TestPos = Guidance.TargetPos
			self.TargetAcquired = true
		--elseif not self.TargetPos then
		--	TestPos = nil
		end

		if TestPos then --Guidance location is valid. Update the target position.
			self.TargetPos = TestPos or nil
		elseif self.HasDatalink and self.Launcher.TargPos and (self.IsJammed == 0) then --Guidance location is not valid. Use datalink position if available.
			--and IsValid(self.Launcher) Don't know if needed?


			self.TargetPos = self.Launcher.TargPos

		elseif self.HasInertial and self.TargetPos and self.MissileActive then --Guidance location is not valid. Update inertial position.
			self.TargetVelocity = self.TargetVelocity or Vector()
			self.TargetPos = self.TargetPos + self.TargetVelocity * DeltaTime
		else						--Guidance location not valid. No inertial guidance. Wipe it clean.
			self.TargetPos = nil
		end

		if self.TargetPos and self.TargetPos ~= Vector() then

			if not self.MissileActive then
				Pos = self.Launcher:GetPos()
			end

			self.TargetDir = (self.TargetPos - Pos):GetNormalized()
			--print("x: "..math.Round(self.TargetDir.x,2))
			--print("y: "..math.Round(self.TargetDir.y,2))
			--print("z: "..math.Round(self.TargetDir.z,2))

		end

	elseif not self.HasInertial then --Guidance is not active. But can be remembered by inertial nav.
		self.TargetPos = nil
	end

	if self.MissileActive then --Missile has been fired off the rails

	if self.StraightRunning > 0 then
	self.StraightRunning = self.StraightRunning - DeltaTime
	end

	--------------------------
	---Engine Motor Section---
	--------------------------

		if self.JustLaunched == true then
			self.Flight = self.Flight + self:GetForward() * self.BoostKick
			self.JustLaunched = false
			self:ConfigureLaunch()
			Pos = self.MissilePosition
		end

		if CT > self.ActivationTime + self.IgnitionDelay then
			--self.IgnitionDelay self.Guidance.StartDelay
			if self.BoostTime > 0 then --Missile has a booster left
				if CT > self.ActivationTime + self.BoostIgnitionDelay then --Past booster ignition delay
					local TMul = 1

					--Let's just never touch this again. Please.
					if self.BoostUnderwater ~= 1 then
						if self.IsUnderWater > 0 then
							if self.BoostUnderwater < 1 then --Abovewater only thruster is underwater
								TMul = 0
							else
								TMul = 1
							end
						else
							if self.BoostUnderwater > 1 then --Underwater only thruster is above water
								TMul = 0
							else
								TMul = 1
							end
						end
					end

					if self.UpdateFX then
						self:StopParticles()
						if TMul > 0 then
							self:SetNW2Bool("MissileActive", true)
							local effect = self.BoostEffect or ACF_GetGunValue(self.BulletData, "effectbooster")
							if effect then
								ParticleEffectAttach( effect, PATTACH_POINT_FOLLOW, self, self:LookupAttachment("exhaust") or 0 )
								self.UpdateFX = false
							end
						else
							self:SetNW2Bool("MissileActive", false)
						end
					end

					self.Flight = self.Flight + self:GetForward() * self.BoostAccel * DeltaTime * TMul
					self.BoostTime = self.BoostTime - DeltaTime

					if self.BoostTime <= 0 then --Booster detaches/stops. Begin regular rocket operations. Potentially add a parentable booster prop to missiles?
						self:StopParticles()
						self.ActivationTime = CT
						self.UpdateFX = true
					end
				end

			else --Regular Rocket Motor Functions

				if CT > self.ActivationTime + self.Burndelay and CT-self.ActivationTime-self.Burndelay < self.BurnTime then

					local TMul = 1
					--self.UnderwaterThrust = 1
					--self.IsUnderWater > 0
					--self.BoostUnderwater = 1
					--Let's just never touch this again. Please.
					--print(self.BoostUnderwater)
					if self.UnderwaterThrust ~= 1 then
						if self.IsUnderWater > 0 then
							if self.UnderwaterThrust < 1 then --Abovewater only thruster is underwater
								TMul = 0
							else
								TMul = 1
							end
						else
							if self.UnderwaterThrust > 1 then --Underwater only thruster is above water
								TMul = 0
							else
								TMul = 1
							end
						end
					end

					if self.UpdateFX then
						self:StopParticles()
						if TMul > 0 then
							self:SetNW2Bool("MissileActive", true)
							local effect = self.BoostEffect or ACF_GetGunValue(self.BulletData, "effect")
							if effect then
								ParticleEffectAttach( effect, PATTACH_POINT_FOLLOW, self, self:LookupAttachment("exhaust") or 0 )
								self.UpdateFX = false
							end
						else
							self:SetNW2Bool("MissileActive", false)
						end
					end

					self.Flight = self.Flight + self:GetForward() * self.Thrust * DeltaTime * TMul

				else
					self:StopParticles()
					self:StopSound(self.MotorSound or "")
					self.UpdateFX = false
					--print(DeltaPos:Length()/39.37) --Prints velocity on motor cutoff. Used for debugging missile speed.
				end
				--subtract burndelay from thrust subtraction
			end
		end

		--------------------------
		-----Steering Section-----
		--------------------------

		local EnableRotation = 0
		if CT > self.ActivationTime + 0.5 then
			EnableRotation = 1
		end

		if self.GuidanceActivationDelay > 0 then
			self.GuidanceActivationDelay = self.GuidanceActivationDelay - DeltaTime
			self:SetAngles(self:LocalToWorldAngles(Angle(math.Clamp( DifFacing.pitch, 0, 100 ), 0,0) * 2 * DeltaTime))
		elseif self.TargetPos then

			local OffsetTPos = self.TargetPos + VectorRand():GetNormalized() * 5 --Apply your noise here. I was thinking of putting noise multipliers in the guidance sections.
			local Tarang = Angle()
			local Heading = (OffsetTPos-Pos):Angle()
			--local LHeading = self:WorldToLocalAngles(Heading)

			--if false then
			--if true then
			if self.StraightRunning <= 0 then
				--Smart guidance. Doesn't work at high convergences. Use backup alternative outside safe range.
				local TDif = OffsetTPos - Pos

				--local TTime = TDif:Length()/self.Speed

				--local TarAng = (TDif + Vector(0,0,15*39.37*9.8*TTime^2)):Angle() --Angle we want to steer our velocity towards


				local TarAng = (TDif):Angle() --Angle we want to steer our velocity towards
				local FlightAngle = self.Flight:Angle() --Angle of our flight

				local ErrAngs = (TarAng-FlightAngle)


				--local ErrAngs2 = (TarAng+FlightAngle) --Bearing Ambiguity nonsense for when the missile becomes confused and wants to head away from the target.


				if ErrAngs.pitch > 180 or ErrAngs.pitch < -180 then
					ErrAngs.pitch = -ErrAngs.pitch
				end

				if ErrAngs.yaw > 180 or ErrAngs.yaw < -180 then
					ErrAngs.yaw = -ErrAngs.yaw
				end

				ErrAngs = Angle(math.Clamp( ErrAngs.pitch, -90, 90 ), math.Clamp( ErrAngs.yaw, -90, 90 ),0)

				--ErrAngs2 = Angle(math.Clamp( ErrAngs2.pitch, -90, 90 ), math.Clamp( ErrAngs2.yaw, -90, 90 ),0)

				--if (self.TargetPos - Pos - ErrAngs2:Forward()):LengthSqr() < (self.TargetPos - Pos - ErrAngs:Forward()):LengthSqr() then
				--	ErrAngs = ErrAngs2
				--	print("Reverse")
				--end

				--If well tuned the PID shouldn't need to be run every tick. Later this can be made to run every few ticks.

				local Plast = self.P
				self.P = ErrAngs * self.Pm
				--self.P = Angle(math.Clamp( ErrAngs.pitch, -25, 25 ), math.Clamp( ErrAngs.yaw, -25, 25 ),0) * self.Pm / self.TurnRate


				self.I = self.I + self.P * DeltaTime * self.IaccumulateMod
				self.I = Angle(math.Clamp( self.I.pitch, -10, 10 ), math.Clamp( self.I.yaw, -10, 10 ),0)

				self.D = (self.P - Plast) / (DeltaTime + 0.001)
				self.D = Angle(math.Clamp( self.D.pitch, -100, 100 ), math.Clamp( self.D.yaw, -100, 100 ),0)

					local PID = self.P + self.I * self.Im + self.D * self.Dm

					PID = Angle(math.Clamp( PID.pitch, -90, 90 ), math.Clamp( PID.yaw, -90, 90 ),0)

					Tarang = self:WorldToLocalAngles(self:GetAngles() + PID)
				else
					self.P = Angle(0,0,0)
					self.I = Angle(0,0,0)
					self.D = Angle(0,0,0)

					Tarang = self:WorldToLocalAngles(Heading) --Just point straight at the target
				end

			local AngAdjust = Tarang

			local adjustedrate = self.TurnRate * DMul * DeltaTime * (self.Speed^2 / 10000) * math.cos(AngleOfAttack) + self.ThrustTurnRate * DeltaTime
			AngAdjust = self:LocalToWorldAngles(Angle(math.Clamp(AngAdjust.pitch, -adjustedrate, adjustedrate), math.Clamp(AngAdjust.yaw, -adjustedrate, adjustedrate), 0)) --math.Clamp(AngAdjust.roll, -adjustedrate, adjustedrate)
			AngAdjust = Angle(AngAdjust.pitch,AngAdjust.yaw,0)
			self:SetAngles(AngAdjust + Angle(math.Clamp( DifFacing.pitch, 0, 100 ), math.Clamp( DifFacing.yaw, -100, 100 ),0) * 2 * DeltaTime * EnableRotation)
			--self:SetAngles(AngAdjust)

		else
			if EnableRotation then
				self:SetAngles(self:LocalToWorldAngles(Angle(math.Clamp( DifFacing.pitch, 0, 100 ), 0,0) * 2 * DeltaTime))
			end
		end

		--------------------------
		------Payload Section-----
		--------------------------

		--CT > self.TimeOfLaunch + self.MinArmingDelay
		if not self.CanDetonate and (self.Fuse:IsArmed() or CT > self.ActivationTime + self.Lifetime) then
			self.CanDetonate = true
		end

		--Detonation by fuse, if available

		if self.CanDetonate == true then
			local tr = util.QuickTrace(Pos + self.Flight * DeltaTime * -30, self.Flight * DeltaTime * 79, {self})

			--[[
			self.LOSTraceData.start = Pos + self.Flight * DeltaTime * -30
			self.LOSTraceData.endpos = self.Flight * DeltaTime * 79
			local tr = util.TraceHull(self.LOSTraceData)
			]]--

			local Exit = false

			if tr.Hit then --and (not tr.HitSky) and util.IsInWorld( tr.HitPos ) -- Removed passing outside the world

				if tr.Entity:IsValid() then
					local HitCont = tr.Entity:GetContraption() or {}
					if HitCont == self.Contraption then
						Exit = true
					end
				end

				if Exit == false then
					debugoverlay.Cross(tr.StartPos, 10, 10, Color(255, 0, 0))
					debugoverlay.Cross(tr.HitPos, 10, 10, Color(0, 255, 0))

					self:SetPos(tr.HitPos + self:GetForward() * -30)
					self:Detonate()
					return
				end

			end

			if self.Fuse:GetDetonate(self, self.Guidance) or CT > self.ActivationTime + self.Lifetime then
				self:Detonate()
				return
			end
		end

		--------------------------
		-----Movement Section-----
		--------------------------

		self.Flight = self.Flight + (Vector(0,0,-9.8 * GMul)) * DeltaTime
		self.MissilePosition = Pos + self.Flight * 39.37 * DeltaTime
		self:SetPos( self.MissilePosition )

		--25 is the result of dividing 2500 by a magic number to compress the speed variable to something nice. 25 = 2500/100
		self.Flight = self.Flight + (self:GetForward() * (self.Speed ^2 / 25) * math.cos(AngleOfAttack) - FlightDir * (self.Speed^2 / 25) * math.cos(AngleOfAttack)) * DeltaTime * self.FinMul --Adjusts a portion of the flgiht by the fin efficiency multiplier


		self.Flight = self.Flight - (self.Flight:GetNormalized() * self.Drag * DMul * self.Flight:LengthSqr()) * DeltaTime --Simple drag multiplier

		--[[
		--Delete the missile if it was fired outside of the map
		if not self:IsInWorld() then

			local Flash = EffectData()
			Flash:SetOrigin(self:GetPos() + Vector(0, 0, 8))
			Flash:SetNormal(Vector(0, 0, -1))
			Flash:SetRadius(2)
			util.Effect( "ACF_Scaled_Explosion", Flash )

			self:Remove()
			return
		end
		]]--

	end


	if self.IsJammed ~= 0 and ACF.CurTime > self.NextJamCheck then
		self.NextJamCheck = ACF.CurTime + self.ResetJamDelay
		--print("ResetJam")
		--Reset everything for next check
		self.IsJammed			= 0

	end

	self.LastPos = Pos

	return true
end

function ENT:ConfigureMissile()

	--local BulletData	= self.BulletData
	--local GunData	= GunTable[BulletData.Id]
	--local Round		= GunData.round

	if not IsValid(self.PhysObj) then self.PhysObj = self:GetPhysicsObject() end

	self.Filter	= self.Filter or {self}

	self.Guidance:Configure(self)


	--0-stops underwater
	--1-booster only underwater - DEFAULT
	--2-works above and below 
	--3-underwater only
	--4-booster all and under thrust only

	--0 for abovewater only, 1 for both, 2 for underwater only
	--self.UnderwaterThrust = 1
	--self.BoostUnderwater = 1
	--print(self.UnderwaterThrust)
	if self.UnderwaterThrust == 0 then
		self.UnderwaterThrust = 0
		self.BoostUnderwater = 0
	elseif self.UnderwaterThrust == 1 then
		self.UnderwaterThrust = 0
		self.BoostUnderwater = 1
	elseif self.UnderwaterThrust == 2 then
		self.UnderwaterThrust = 1
		self.BoostUnderwater = 1
	elseif self.UnderwaterThrust == 3 then
		self.UnderwaterThrust = 2
		self.BoostUnderwater = 2
		self.WaterZHeight = 0 --Will search for a waterheight
	elseif self.UnderwaterThrust == 4 then
		self.UnderwaterThrust = 2
		self.BoostUnderwater = 0
		self.WaterZHeight = 0 --Will search for a waterheight
	end

end

function ENT:ConfigureLaunch()

	--self.GuidanceActivationDelay = self.GuidanceActivationDelay + CT
	self.MissilePosition = self:GetPos()

	local CT = CurTime()
	ACF_ActiveMissiles[self] = true
	self.Fuse:Configure(self, self.Guidance)
	self.TimeOfLaunch = CT

end

function ENT:Detonate()
	if self.Exploded then return end

	self.Exploded = true
	ACF_ActiveMissiles[self] = nil

	local HEWeight = self.Bulletdata2.BoomFillerMass or self.Bulletdata2.FillerMass or 1
	local Radius = HEWeight ^ 0.33 * 8 * 39.37

--	if not IsValid(self.Launcher) then return end

--	self.Bulletdata2["Gun"]			= self.Launcher

--	self.Launcher.FakeCrate = self.Launcher.FakeCrate or ents.Create("acf_fakecrate2")
--	self.Launcher.FakeCrate:RegisterTo(self.Bulletdata2)
--	self.Bulletdata2["Crate"] = self.Launcher.FakeCrate:EntIndex()
--	self.Launcher:DeleteOnRemove(self.Launcher.FakeCrate)

	if not IsValid(self) then return end

	local fakecrate = ents.Create("acf_fakecrate2")
	self.Bulletdata2["Gun"]			= self
	--self.FakeCrate = self.FakeCrate or ents.Create("acf_fakecrate2")
	self.Bulletdata2["Crate"] = fakecrate:EntIndex()
	fakecrate:RegisterTo(self.Bulletdata2)

	self:SetNoDraw( true ) --Since we aren't immediately deleting the entity, hide it.
	self:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
	self:StopParticles()

	timer.Simple(0.5, function() --Keep missile alive and give it time to show effects
		if IsValid(fakecrate) then
			fakecrate:Remove()
		end
		if IsValid(self) then
			self:Remove()
		end
	end)

	self.Bulletdata2["PenArea"] = self.Bulletdata2["PenArea"] * self.MissileCalMul
	--self.Bulletdata2["Caliber"] = self.Bulletdata2["FrArea"] * self.MissileCalMul
--	self.Bulletdata2["Flight"] = self:GetForward():GetNormalized() * self.Flight * 39.37 * ACF.MissileVelocityMul
	self.Bulletdata2["Flight"] = self.Flight * 39.37 * self.MissileVelocityMul

	self.Bulletdata2.Pos = self:GetPos()
	self.Bulletdata2.Owner = self:CPPIGetOwner()

	self.CreateShell = ACF.RoundTypes[self.Bulletdata2.Type].create
	self:CreateShell( self.Bulletdata2 )

	if Radius > 0.25 then
		local Flash = EffectData()
		Flash:SetOrigin(self:GetPos() + Vector(0, 0, 8))
		Flash:SetNormal(Vector(0, 0, -1))
		Flash:SetRadius(math.Round(math.max(Radius / 39.37, 1),2))
		util.Effect( "ACF_Scaled_Explosion", Flash )
	end
--

end

function ENT:OnRemove()
	ACF_ActiveMissiles[self] = nil

	if self.MotorSound then
	self:StopSound(self.MotorSound)
	end
end

do

	--[[local HEATtbl = {
		HEAT	= true,
		THEAT	= true,
		HEATFS  = true,
		THEATFS = true
	}
	]]--
	local HEtbl = {
		HE	= true,
		HESH	= true,
		HEFS	= true
	}

	function ENT:ACF_OnDamage( Ent, Energy, FrArea, _, Inflictor, _, Type )	--This function needs to return HitRes

		local Mul	= (( HEtbl[Type] and 0.1 ) or 1) --HE penetrators better penetrate the armor of missiles
		local HitRes	= ACF_PropDamage( Ent, Energy , FrArea * Mul, 0, Inflictor ) --Calling the standard damage prop function. Angle of incidence set to 0 for more consistent damage.
		--local Activated = ACF_Check( Ent )
		--local CanDo = hook.Run("ACF_BulletDamage", Activated, Ent, Energy, FrArea, 0, Inflictor )

		local CanDo = hook.Run("ACF_BulletDamage", _, Ent, _, _, _, Inflictor, _, _ )
		----------------------(_, Entity, _, _, _, Inflictor, _, _)
		--print(math.Round(HitRes.Damage * 100))
		--print(HitRes.Loss * 100)

		--print(HitRes.Overkill)

		if (HitRes.Kill or HitRes.Overkill > 1) and CanDo then

			--self:Detonate()
			self.MissileActive = true
			self.ActivationTime = 0
			self.Lifetime = 0 --Instantly scuttle as soon as can execute.

			self.MissileVelocityMul = self.MissileVelocityMul * 0.05
			self.Bulletdata2.SlugMV = self.Bulletdata2.SlugMV * 0.1
			self.Bulletdata2.SlugMV2 = self.Bulletdata2.SlugMV * 0.1

			return { Damage = 0, Overkill = 0, Loss = 0, Kill = false }

		end

		return HitRes --This function needs to return HitRes

	end

end


function ENT:CanTool( _, _, _, _, _ ) --ply, trace, mode, tool, button

	if self.JustLaunched == true then
		return true
	else
		return false
	end
	--print("tool: "..mode)

end

function ENT:CanProperty( _, _)

	if self.JustLaunched == true then
		return true
	else
		return false
	end

	return false

end

hook.Add( "PhysgunPickup", "DisallowPhysgunMissiles", function( _, ent )
	if ( ent:GetClass() == "ace_missile" ) then
		--print("phys blocked")
		return false
	end
end )