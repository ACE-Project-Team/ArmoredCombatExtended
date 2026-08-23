
--This is a fully loaded bullet removal
function ACE_RemoveBulletClient( Bullet, Index )

	if Bullet then
		if IsValid(Bullet.Tracer) then Bullet.Tracer:Finish() end

		local BulletEnt = Bullet.Effect
		if IsValid(BulletEnt) then
			BulletEnt.Alive = false
			BulletEnt:Remove()
		end

		if ACE.BulletEffect[Index] then
			ACE.BulletEffect[Index] = nil
		end
	end
end

do

	--Applies only to bullets that wants only their entity removed but keeping on the main table
	local function RemoveBulletEntry( Effect )
		if IsValid(Effect) then
			Effect.Alive = false
			Effect:Remove()
		end
	end

	function EFFECT:Init( data )

		self.Index = tostring(data:GetMaterialIndex())

		--print(self.Index)
		if not self.Index then
			RemoveBulletEntry( self )
			return
		end
		self.CreateTime = ACE.CurTime

		local Hit = data:GetScale()
		local Bullet = ACE.BulletEffect[self.Index]

		--Scale encodes the hit type, so if it's 0 it's a new bullet, else it's an update so we need to remove the effect
		if (Hit > 0 and Bullet) then

			--print("Updating Bullet Effect")
			Bullet.SimFlight = data:GetStart() * 10	--Updating old effect with new values
			Bullet.SimPos = data:GetOrigin()

			--Bullet has reached end of flight, remove old effect
			if (Hit == 1) then

				Bullet.Impacted = true

				self.HitEnd = ACE.RoundTypes[Bullet.AmmoType]["endeffect"]
				self:HitEnd( Bullet )
				ACE.BulletEffect[self.Index] = nil		--This is crucial, to effectively remove the bullet flight model from the client

				if IsValid(Bullet.Tracer) then Bullet.Tracer:Finish() end

			--Bullet penetrated, don't remove old effect
			elseif (Hit == 2) then

				self.HitPierce = ACE.RoundTypes[Bullet.AmmoType]["pierceeffect"]
				self:HitPierce( Bullet )

			--Bullet ricocheted, don't remove old effect
			elseif (Hit == 3) then

				self.HitRicochet = ACE.RoundTypes[Bullet.AmmoType]["ricocheteffect"]
				self:HitRicochet( Bullet )

			end

			ACE.SimBulletFlight( Bullet, self.Index )
			RemoveBulletEntry( self )

		else
			--print("Creating Bullet Effect")
			local BulletData = {}
			BulletData.Crate = data:GetEntity()

			--TODO: Check if it is actually a crate
			if not IsValid(BulletData.Crate) then
				RemoveBulletEntry( self )
				return
			end

			BulletData.IsMissile    = BulletData.IsMissile or (data:GetAttachment() == 1)

			BulletData.SimFlight    = data:GetStart() * 10
			BulletData.SimPos       = data:GetOrigin()
			BulletData.SimPosLast   = BulletData.SimPos
			BulletData.Caliber      = BulletData.Crate:GetNWFloat( "Caliber", 10 )
			BulletData.RoundMass    = BulletData.Crate:GetNWFloat( "ProjMass", 10 )
			BulletData.FillerMass   = BulletData.Crate:GetNWFloat( "FillerMass" )
			BulletData.WPMass       = BulletData.Crate:GetNWFloat( "WPMass" )
			BulletData.DragCoef     = BulletData.Crate:GetNWFloat( "DragCoef", 1 )
			BulletData.AmmoType     = BulletData.Crate:GetNWString( "AmmoType", "AP" )

			BulletData.Accel        = BulletData.Crate:GetNWVector( "Accel", Vector(0,0,-600))

			BulletData.LastThink    = CurTime() --ACE.CurTime
			BulletData.Effect       = self.Entity
			BulletData.CrackCreated = false
			BulletData.HasWhistled = false
			BulletData.HasSplashed = false
			BulletData.InitialPos   = BulletData.SimPos --Store the first pos, se we can limit the crack sound at certain distance

			BulletData.BulletModel  = BulletData.Crate:GetNWString( "BulletModel", "models/munitions/round_100mm_shot.mdl" )

			BulletData.Tracer         = ParticleEmitter( BulletData.SimPos )

			self.hasTracer = (BulletData.Crate:GetNWFloat( "Tracer" ) > 0)

			if self.hasTracer then
				BulletData.Counter        = 0
				BulletData.TracerColour   = BulletData.Crate:GetNWVector( "TracerColour", BulletData.Crate:GetColor() ) or Vector(255,255,255)
			end

			--Add all that data to the bullet table, overwriting if needed
			ACE.BulletEffect[self.Index] = BulletData

			--Moving the effect to the calculated position
			self:SetPos( BulletData.SimPos )
			self:SetAngles( BulletData.SimFlight:Angle() )
			self:SetModel( BulletData.BulletModel )
			self.Alive = true

			ACE.SimBulletFlight( ACE.BulletEffect[self.Index], self.Index )

		end

	end

end



function EFFECT:HitEnd()
	--You overwrite this with your own function, defined in the ammo definition file
	ACE.BulletEffect[self.Index] = nil		--Failsafe
end

function EFFECT:HitPierce()
	--You overwrite this with your own function, defined in the ammo definition file
	ACE.BulletEffect[self.Index] = nil		--Failsafe
end

function EFFECT:HitRicochet()
	--You overwrite this with your own function, defined in the ammo definition file
	ACE.BulletEffect[self.Index] = nil		--Failsafe
end

function EFFECT:Think()

	local Bullet = ACE.BulletEffect[self.Index]

	if self.Alive and Bullet and self.CreateTime > ACE.CurTime-30 then

		--We require this so the tracer is not spawned in middle of the gun (when initially fired)
		if self.hasTracer and IsValid(Bullet.Tracer) and Bullet.Counter < 4 then Bullet.Counter = Bullet.Counter + 1 end

		return true
	end

	--if the bullet will be not stand in the map, less its tracer
	if Bullet and IsValid(Bullet.Tracer) then Bullet.Tracer:Finish() end
	return false
end

--Check if the crack is allowed to perform or not
local function CanBulletCrack( Bullet )

	if Bullet.IsMissile then return false end
	if Bullet.CrackCreated then return false end
	if ACE.SInDistance( Bullet.InitialPos, 750 ) then return false end
	if not ACE.SInDistance( Bullet.SimPos, math.max(Bullet.Caliber * 100 * ACE.CrackDistanceMultipler,250) ) then return false end
	if Bullet.Impacted then return false end

	local SqrtSpeed = (Bullet.SimPos - Bullet.SimPosLast):LengthSqr()
	if SqrtSpeed < 2500 then return false end -- 2500 = 50^2

	return true
end

--Check if the crack is allowed to perform or not
local function CanWhistle( Bullet )

	if Bullet.IsMissile then return false end
	if Bullet.HasWhistled then return false end
	if Bullet.Impacted then return false end
	if Bullet.SimFlight:GetNormalized().z > -0.5 then return false end
	if Bullet.Caliber < 5 then return false end

	local BulSpeed = Bullet.SimFlight:Length()

	if BulSpeed < 50 then return false end
	if not ACE.SInDistance( Bullet.SimPos, math.min(BulSpeed, 5000)) then return false end

	if ACE.Approaching( Bullet.SimPos, Bullet.SimFlight ) > 0 then return false end --Shell is moving away.


	return true
end

--Check if the crack is allowed to perform or not
local function CanSplash( Bullet )

	if Bullet.IsMissile then return false end
	if Bullet.Impacted then return false end
	if not Bullet.IsUnderWater then return false end
	if Bullet.HasSplashed then return false end

	return true
end

function EFFECT:ApplyMovement( Bullet, Index )

	local setPos = Bullet.SimPos
	if (math.abs(setPos.x) > 16380) or (math.abs(setPos.y) > 16380) or (setPos.z < -16380) then -- the bullet will never come back to the map.
		ACE_RemoveBulletClient( Bullet, Index )

		return
	end
	if setPos.z < 16380 then
		self:SetPos( setPos ) --Moving the effect to the calculated position
		self:SetAngles( Bullet.SimFlight:Angle() )

		--sonic crack sound
		if CanBulletCrack( Bullet ) then
			ACE.SBulletCrack(Bullet, Bullet.Caliber)
		end

		--incoming shell whistle
		if CanWhistle( Bullet ) then
			ACE.SBulletWhistle(Bullet, Bullet.Caliber)
		end

		local WaterTr = { }
		WaterTr.start = Bullet.SimPos
		WaterTr.endpos = Bullet.SimPos + Bullet.SimFlight * 0.1
		WaterTr.mask = MASK_WATER
		local Water = util.TraceLine( WaterTr )

		Bullet.IsUnderWater = false
		if Water.HitWorld and Water.StartSolid then
				Bullet.IsUnderWater = true
				Bullet.WaterPos = Water.HitPos
		end

	else
		--We don't need small bullets to stay outside of skybox. This is meant for large calibers only.
		if Bullet.Caliber < 5 then
			ACE.RemoveBulletClient( Bullet, Index )
			return
		end
	end

	if IsValid(Bullet.Tracer) then

		local DeltaPos = Bullet.SimPos - Bullet.SimPosLast
		local Length =  math.min(-DeltaPos:Length() * 3.125,-1)

		if self.hasTracer and Bullet.Counter > 3 then

			local Light = Bullet.Tracer:Add( "sprites/acf_tracer.vmt", setPos )

			if (Light) then
				Light:SetAngles( Bullet.SimFlight:Angle() )
				Light:SetVelocity( Bullet.SimFlight:GetNormalized() )
				Light:SetColor( Bullet.TracerColour.x, Bullet.TracerColour.y, Bullet.TracerColour.z )
				Light:SetDieTime( math.Clamp(ACE.CurTime-self.CreateTime,0.0275,0.05625) ) -- 0.075, 0.1
				Light:SetStartAlpha( 180 )
				Light:SetEndAlpha( 0 )
				Light:SetStartSize( 30 * Bullet.Caliber ) -- 5
				Light:SetEndSize( 30 * Bullet.Caliber ) --15 * Bullet.Caliber
				Light:SetStartLength( Length )
				Light:SetEndLength( Length ) --Length
				Light:SetLighting( false )
			end

			Light = Bullet.Tracer:Add( "effects/ar2_altfire1b", setPos )

			--debugoverlay.Cross(setPos,3,1,Color(255,255,255,10), true)

			if (Light) then
				Light:SetAngles( Bullet.SimFlight:Angle() )
				Light:SetVelocity( Bullet.SimFlight:GetNormalized() )
				--Light:SetColor( Bullet.TracerColour.x, Bullet.TracerColour.y, Bullet.TracerColour.z )
				Light:SetDieTime( math.Clamp(ACE.CurTime-self.CreateTime,0.0275,0.05625) ) -- 0.075, 0.1
				Light:SetStartAlpha( 180 )
				Light:SetEndAlpha( 0 )
				Light:SetStartSize( 2 * Bullet.Caliber ) -- 5
				Light:SetEndSize( 2 * Bullet.Caliber ) --15 * Bullet.Caliber
				Light:SetStartLength( Length )
				Light:SetEndLength( Length ) --Length
				Light:SetLighting( false )
			end
		end

		--Splish Splash Water
		if CanSplash( Bullet ) then

			WaterTr = { }
			WaterTr.start = Bullet.SimPos - Bullet.SimFlight * 0.025
			WaterTr.endpos = Bullet.SimPos + Bullet.SimFlight * 500
			WaterTr.mask = MASK_WATER
			Water = util.TraceLine( WaterTr )

			local Sparks = EffectData()
			Sparks:SetOrigin( Water.HitPos + Vector(0,0,0) )
			Sparks:SetScale( Bullet.Caliber * 10 )
			util.Effect( "watersplash", Sparks )

			ACE.EmitSound( "ambient/water/water_splash" .. math.random(1,3) .. ".wav" , Water.HitPos, 100, 100 / Bullet.Caliber * 4, 300 )

			Bullet.HasSplashed = true
		end




		local Smoke = Bullet.Tracer:Add( "particle/smokesprites_000" .. math.random(1,9), setPos + DeltaPos )
		if (Smoke) then
			Smoke:SetAngles( Bullet.SimFlight:Angle() )
			Smoke:SetVelocity( Bullet.SimFlight * 0.05 )
			Smoke:SetColor( 200 , 200 , 200 )
			Smoke:SetDieTime( 0.8 ) -- 0.5
			Smoke:SetStartAlpha( 2 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( Bullet.Caliber * 3 )
			Smoke:SetEndSize( Bullet.Caliber * 3 )
			Smoke:SetStartLength( Length * 0.75 )
			Smoke:SetEndLength( Length * 0.75 ) --Length
			Smoke:SetRollDelta( 0.1 )
			Smoke:SetAirResistance( 150 )
			Smoke:SetGravity( Vector(0,0,20) )

		end



		--[[
		local MaxSprites = 1

		if MaxSprites > 0 then

			for i = 1, MaxSprites do
				local Smoke = Bullet.Tracer:Add( "particle/smokesprites_000" .. math.random(1,9), setPos + (DeltaPos * i / MaxSprites) )
				if (Smoke) then
					Smoke:SetAngles( Bullet.SimFlight:Angle() )
					Smoke:SetVelocity( Bullet.SimFlight * 0.05 )
					Smoke:SetColor( 200 , 200 , 200 )
					Smoke:SetDieTime( 0.6 ) -- 1.2
					Smoke:SetStartAlpha( 10 )
					Smoke:SetEndAlpha( 0 )
					Smoke:SetStartSize( 1 )
					Smoke:SetEndSize( Length / 400 * Bullet.Caliber )
					Smoke:SetRollDelta( 0.1 )
					Smoke:SetAirResistance( 150 )
					Smoke:SetGravity( Vector(0,0,20) )

				end
			end
		end
		]]--


	end
end

function EFFECT:Render()

	local Bullet = ACE.BulletEffect[self.Index]

	if (Bullet) then
		self.Entity:SetModelScale( Bullet.Caliber / 10 , 0 )
		self.Entity:DrawModel()	-- Draw the model.
	end

end
