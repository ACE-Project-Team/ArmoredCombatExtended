--[[---------------------------------------------------------
Initializes the effect. The data is a table of data
which was passed from the server.
-----------------------------------------------------------]]

function EFFECT:Init( data )
	self.Origin = data:GetOrigin()
	self.Radius = data:GetRadius() --Slow deployinging smoke. Radius in meters
	self.Emitter = ParticleEmitter( self.Origin )

	self:StartSmoke( self.Radius * 12 ) --The initial puff and streamers before the smoke gets up to size

	--local Radius = math.max(self.Radius + self.Magnitude) * 15
	--local Flash = EffectData()
	--	Flash:SetOrigin( self.Origin)
	--	Flash:SetNormal( self.DirVecNormal )
	--	Flash:SetRadius( math.max( Radius, 1 ) )
	--util.Effect( "ACE_Scaled_Explosion", Flash )

	local PlayerDist = (LocalPlayer():GetPos() - self.Origin):Length() / 20 + 0.001 --Divide by 0 is death, 20 is roughly 39.37 / 2

		if PlayerDist < self.Radius * 10 and not LocalPlayer():HasGodMode() then
		--if PlayerDist < self.Radius * 10 then
		local Amp          = math.min(self.Radius * 0.5 / math.max(PlayerDist,1),40)
		ACE.ScreenShake( self.Origin, 50 * Amp, 1.5 / Amp, self.Radius / 7.5, 0 , true)
	end

	self.Emitter:Finish()
end


function EFFECT:StartSmoke( SRadius )

	-- Calculate the wind effect on velocity and gravity
	-- Apply wind effect based on wind direction and windStrength


		local PMul       = 1
		local Radius     = SRadius / 75 + 3 --Removed (1-Ground.Fraction)
		local Density    = Radius * 6
		local Angle      = vector_up:Angle()

		for _ = 0, Density * PMul do

			Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
			local ShootVector = Angle:Up()
			local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), self.Origin )

			if Smoke then
				Smoke:SetVelocity( ShootVector * 250 * Radius * math.Rand(0.3, 1) )
				Smoke:SetLifeTime( 0 )
				Smoke:SetDieTime(  0.75 * Radius / 4 )
				Smoke:SetStartAlpha( 50 )
				Smoke:SetEndAlpha( 0 )
				Smoke:SetStartSize( 15 * Radius )
				Smoke:SetEndSize( 55 * Radius )
				Smoke:SetRoll( math.Rand(0, 360) )
				Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
				Smoke:SetAirResistance( 100 )
				Smoke:SetGravity(Vector(0, 0, 25 ))
				local SMKColor = math.random( 135 , 150 )
				Smoke:SetColor( SMKColor, SMKColor, SMKColor )
			end
		end

		local PMul       = 1
		local Radius     = SRadius / 100 + 1 --Removed (1-Ground.Fraction)
		local Density    = Radius * 2
		local Angle      = vector_up:Angle()

		for _ = 0, Density * PMul do

			Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
			local ShootVector = Angle:Up()
			local Smoke = self.Emitter:Add( "effects/fire_cloud" .. math.random(1,2), self.Origin )

			if Smoke then
				Smoke:SetVelocity( ShootVector * 350 * Radius * math.Rand(0.3, 1) )
				Smoke:SetLifeTime( 0 )
				Smoke:SetDieTime(  0.75 * Radius / 4 )
				Smoke:SetStartAlpha( 125 )
				Smoke:SetEndAlpha( 0 )
				Smoke:SetStartSize( 15 * Radius )
				Smoke:SetEndSize( 55 * Radius )
				Smoke:SetRoll( math.Rand(0, 360) )
				Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
				Smoke:SetAirResistance( 200 )
				Smoke:SetGravity(Vector(0, 0, 25 ))
				--Smoke:SetColor( 255, 255, 255 )
			end
		end

		local Dust = self.Emitter:Add("effects/yellowflare", self.Origin  )

		if Dust then
			Dust:SetLifeTime(0)
			Dust:SetDieTime(0.3)
			Dust:SetStartAlpha(100)
			Dust:SetEndAlpha(0)
			Dust:SetStartSize(175 * Radius)
			Dust:SetEndSize(175 * Radius)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetAirResistance( 0 )
			Dust:SetGravity(Vector(0, 0, 0))
			Dust:SetLighting( false )
		end

		local ParticleCount = math.ceil( math.Clamp( Radius * 3, 3, 600 ) * PMul )

		for _ = 1, ParticleCount do
			local Spark = self.Emitter:Add("effects/ar2_altfire1b", self.Origin )

			if Spark then
				Spark:SetVelocity((VectorRand() * Vector(1,1,0.25)):GetNormalized() * 1500)
				Spark:SetLifeTime(-0.05)
				Spark:SetDieTime(math.Rand(1, 1.5))
				Spark:SetStartAlpha(100)
				Spark:SetEndAlpha(20)
				local size = math.Rand(1, 5) * Radius + 3
				Spark:SetStartSize(size)
				Spark:SetEndSize(size)
				Spark:SetRoll(math.Rand(150, 360))
				Spark:SetRollDelta(math.Rand(-0.2, 0.2))
				Spark:SetGravity(Vector(0, 0, -340))
				Spark:SetLighting( false )
				Spark:SetCollide( true )
				Spark:SetBounce( 0.5 )
				Spark:SetAirResistance(75)
				local ColorRandom = VectorRand() * 15
				Spark:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
				local Length = math.Rand(200, 250)
				Spark:SetStartLength( Length )
				Spark:SetEndLength( Length ) --Length
			end
		end


		local Dust = self.Emitter:Add("sprites/orangeflare1", self.Origin  )

		if Dust then
			Dust:SetLifeTime(0)
			Dust:SetDieTime(0.4)
			Dust:SetStartAlpha(100)
			Dust:SetEndAlpha(0)
			Dust:SetStartSize(175 * Radius)
			Dust:SetEndSize(0)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetAirResistance( 0 )
			Dust:SetGravity(Vector(0, 0, 0))
			Dust:SetLighting( false )
			Dust:SetColor( 255, 200, 200 )
		end

end




--keep this here, error pops up if it's removed
function EFFECT:Render()
end

