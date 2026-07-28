--[[---------------------------------------------------------
	Initializes the effect. The data is a table of data
	which was passed from the server.
-----------------------------------------------------------]]

--this is crucial for subcaliber, this will boost the dust's size.
local RoundTypesSubCaliberBoost = {
	APDS    = true,
	APDSS   = true,
	APFSDS  = true,
	APFSDSS = true,
	APCR    = true,
	HVAP    = true
}


--the dust is for non-explosive rounds, so lets skip this
local RoundTypesIgnore = {
	--HEAT      = true,
	--THEAT      = true,
	--HEATFS      = true,
	--THEATFS      = true,
	HE      = true,
	HEFS    = true,
	HESH    = true
}

local EntityFilter = {
	player = true
}

local function PerformDecalTrace( Effect )
	local Tr = {}
	Tr.start = Effect.Origin - Effect.DirVec * 10
	Tr.endpos = Effect.Origin + Effect.DirVec * 200
	return util.TraceLine( Tr )
end

local function PerformBulletEffect( Effect )
	local BulletEffect = {}
	BulletEffect.Num       = 1
	BulletEffect.Src       = Effect.Origin - Effect.DirVec
	BulletEffect.Dir       = Effect.DirVec
	BulletEffect.Spread    = Vector(0,0,0)
	BulletEffect.Tracer    = 0
	BulletEffect.Force     = 0
	BulletEffect.Damage    = 0
	LocalPlayer():FireBullets(BulletEffect)
end

function EFFECT:Init( data )

	self.AmmoCrate   = data:GetEntity() 		-- The ammo crate Entity of this round.
	self.Origin      = data:GetOrigin() 		-- where the round did hit.
	self.DirVec      = data:GetNormal() 		-- the direction of the shell when did hit
	self.Velocity    = data:GetScale() 			-- Mass of the projectile in kg
	self.Mass        = data:GetMagnitude() 		-- Velocity of the projectile in gmod units

	local ValidCrate = IsValid(self.AmmoCrate)

	self.Scale       = math.max(self.Mass * (self.Velocity / 39.37) / 100,1) ^ 0.3
	self.Id          = ValidCrate and self.AmmoCrate:GetNWString( "AmmoType", "AP" ) or "AP"
	self.Caliber     = ValidCrate and self.AmmoCrate:GetNWFloat( "Caliber", 2 ) or 2
	self.Emitter     = ParticleEmitter( self.Origin )

	-- I know it looks like the messy way to do things. But it would make a lot of math equations harder to follow later like the area calculations. And require extra multiplication.
	self.Caliber	 = self.Caliber * 2 --Effect scale.


	local LocPly = LocalPlayer()
	local SurfaceTr = PerformDecalTrace( self )
	local TraceEntity = SurfaceTr.Entity
	self.HitNorm = SurfaceTr.HitNormal

	--do this if we are dealing with non-explosive rounds. nil types are being created by HEAT, so skip it too
	if self.Id and not RoundTypesIgnore[self.Id] or (IsValid(TraceEntity) and not EntityFilter[TraceEntity:GetClass()]) then

		if self.Id and self.Id == "FL" then self.Caliber = 0.01 end

		local Mat = SurfaceTr.MatType or 0
		MatVal = ACE.GetMaterialName( Mat )

		if SurfaceTr.HitNonWorld then --Overide with ACE prop material
			local TEnt = SurfaceTr.Entity
			if TEnt:IsPlayer() or TEnt:IsNPC() then --Super disgusting. Get rid of this ASAP.
				MatVal = "Flesh"
			else
				MatVal = "Metal"
			end
			--self.HitNorm = -self.HitNorm
			--self.DirVec = -self.DirVec
			--local TEnt = SurfaceTr.Entity
			--I guess the material is serverside only ATM? TEnt.ACF.Material doesn't return anything valid.
			--TODO: Add clienside way to get ACF Material
		end

		local SmokeColor = ACE.DustMaterialColor[MatVal] or ACE.DustMaterialColor["Concrete"] --Enabling lighting on particles produced some yucky results when gravity pulled particles below the map.
		local SMKColor = Color( SmokeColor.r, SmokeColor.g, SmokeColor.b, 150 ) --Used to prevent it from overwriting the global smokecolor :/
		local AmbLight = render.GetLightColor( self.Origin ) * 2 + render.GetAmbientLightColor()
		SMKColor.r = math.floor(SMKColor.r * math.Clamp( AmbLight.x, 0, 1 ))
		SMKColor.g = math.floor(SMKColor.g * math.Clamp( AmbLight.y, 0, 1 ))
		SMKColor.b = math.floor(SMKColor.b * math.Clamp( AmbLight.z, 0, 1 ))

		local DecalMat = "Impact.Concrete" --Disabled other impact effects due to source bug hitting odd materials. Not too much loss in fidelity anyways.

		if MatVal == "Metal" then
			self:Metal( SMKColor )
			--DecalMat = "Impact.Metal"
		elseif  MatVal == "Dirt" or MatVal == "Sand"  then
			self:Dust( SMKColor )
			--DecalMat = "Impact.Sand"
		elseif MatVal == "Concrete" then
			self:Concrete( SMKColor )
			--DecalMat = DecalMat
		elseif  MatVal == "Snow"  then
			self:Dust( SMKColor )
			--DecalMat = "Impact.Sand"
		elseif  MatVal == "Wood"  then
			self:Wood( SMKColor )
			--DecalMat = "Impact.Wood"
		elseif  MatVal == "Glass"  then
			self:Glass( SMKColor )
			--DecalMat = "Impact.Glass"
		elseif  MatVal == "Flesh"  then
			self:Flesh( Color( 100,0,0, 150 ) )
		else
			self:Dust( SMKColor )
		end

		util.Decal(DecalMat, SurfaceTr.StartPos, self.Origin + self.DirVec * 10 )
		ACE.SBulletImpact( self.Origin, self.Caliber, self.Velocity, SurfaceTr.HitWorld, MatVal )

	end

	local Energy = (self.Mass * (self.Velocity / 39.37) ^2) / 1000000

	if IsValid(LocPly) then
		local PlayerDist = (LocPly:GetPos() - self.Origin):Length() / 20 + 0.001 --Divide by 0 is death, 20 is roughly 39.37 / 2

		if PlayerDist < Energy * 8 and not LocPly:HasGodMode() then
			local Amp          = math.min(Energy / 350 / math.max(PlayerDist,5), 40)
			--local Amp          = math.min(self.Radius / 1.5 / math.max(PlayerDist,5),40)
			util.ScreenShake( self.Origin, 50 * Amp, 1.5 / Amp, math.min(Amp  * 2,2), Energy / 10 , false) --Energy/20
		end
	end

	PerformBulletEffect( self )


	if self.Emitter then self.Emitter:Finish() end
end

function EFFECT:Concrete( SmokeColor )

	if not self.Emitter then return end

	local Vel = self.Velocity / 2500
	local Mass = self.Mass

	local HalfArea = (RoundTypesSubCaliberBoost[self.Id] and 0.75) or 1
	local ShellArea = 3.141 * (self.Caliber / 2) * HalfArea

	local Pmul = 1

	--KE main formula
	local Energy = math.Clamp((((Mass * (Vel ^ 2)) / 2) / 2) * ShellArea, 4, math.max(ShellArea ^ 0.95, 4))


	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 4, 2, 100 ) * Pmul )

	local DustSpeed = 50
	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("particles/smokey", self.Origin - self.DirVec * 15)

		if Dust then
			Dust:SetVelocity(self.HitNorm * DustSpeed * Energy / ParticleCount * 0.75)
			DustSpeed = DustSpeed + 50
			--			Dust:SetVelocity(VectorRand() * math.random(20, 30 * Energy))
			Dust:SetLifeTime(0)
			Dust:SetDieTime(1 * (Energy / 6))
			Dust:SetStartAlpha(200)
			Dust:SetEndAlpha(0)
			Dust:SetStartSize(0.1 * Energy)
			Dust:SetEndSize(7 * Energy * (DustSpeed / 50))
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetAirResistance(15)
			Dust:SetGravity(Vector(0, 0, -320))
			Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
		end
	end

	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 4, 2, 100 ) * Pmul )

	for _ = 1, ParticleCount do
		local Debris = self.Emitter:Add("effects/fleck_tile" .. math.random(1,2), self.Origin - self.DirVec * 25)

		if Debris then
			Debris:SetVelocity((self.HitNorm + VectorRand() * 0.3) * 60 * Energy)
			Debris:SetLifeTime(0)
			Debris:SetDieTime(math.Rand(1, 2) * (Energy / 3))
			Debris:SetStartAlpha(255)
			Debris:SetEndAlpha(255)
			Debris:SetStartSize(0.75 * (self.Caliber + 2))
			Debris:SetEndSize(0.75 * (self.Caliber + 2))
			Debris:SetRoll(math.Rand(150, 360))
			Debris:SetRollDelta(math.Rand(-0.2, 0.2))
			Debris:SetAirResistance(15)
			Debris:SetGravity(Vector(0, 0, -500))
			Debris:SetColor(SmokeColor.r * 0.8, SmokeColor.g * 0.8, SmokeColor.b * 0.8)
			Debris:SetCollide( true )
			Debris:SetBounce( 0.25 )
		end
	end

	local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), self.Origin - self.DirVec * 1)

	if Flash then
		Flash:SetLifeTime(0)
		Flash:SetDieTime(0.05)
		Flash:SetStartAlpha(255)
		Flash:SetEndAlpha(255)
		Flash:SetStartSize(2 * (self.Caliber + 1))
		Flash:SetEndSize(3 * (self.Caliber + 1))
		Flash:SetRoll(math.Rand(150, 360))
		Flash:SetRollDelta(math.Rand(-0.3, 0.3))
		Flash:SetLighting( false )
	end

	local VectorMultiplier = 5
	local Dust = self.Emitter:Add("particles/smokey", self.Origin - self.DirVec * VectorMultiplier)

	if Dust then
		Dust:SetLifeTime(0)
		Dust:SetDieTime(1)
		Dust:SetStartAlpha(200)
		Dust:SetEndAlpha(75)
		Dust:SetStartSize(5 * self.Caliber)
		Dust:SetEndSize(25 * self.Caliber)
		Dust:SetRoll(math.Rand(150, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetColor(100, 100, 100)
	end


end

function EFFECT:Wood( SmokeColor )

	if not self.Emitter then return end

	local Vel = self.Velocity / 2500
	local Mass = self.Mass

	local HalfArea = (RoundTypesSubCaliberBoost[self.Id] and 0.75) or 1
	local ShellArea = 3.141 * (self.Caliber / 2) * HalfArea

	local Pmul = 1

	--KE main formula
	local Energy = math.Clamp((((Mass * (Vel ^ 2)) / 2) / 2) * ShellArea, 4, math.max(ShellArea ^ 0.95, 4))

	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 4, 2, 100 ) * Pmul )

	for _ = 1, ParticleCount do
		local Debris = self.Emitter:Add("effects/fleck_wood" .. math.random(1,2), self.Origin - self.DirVec * 15)

		if Debris then
			Debris:SetVelocity((self.HitNorm + VectorRand() * 0.45) * 100 * Energy)
			Debris:SetLifeTime(0)
			Debris:SetDieTime(math.Rand(1, 2) * (Energy / 3))
			Debris:SetStartAlpha(255)
			Debris:SetEndAlpha(255)
			Debris:SetStartSize(1.25 * (self.Caliber + 2))
			Debris:SetEndSize(1.25 * (self.Caliber + 2))
			Debris:SetRoll(math.Rand(150, 360))
			Debris:SetRollDelta(math.Rand(-0.2, 0.2))
			Debris:SetAirResistance(15)
			Debris:SetGravity(Vector(0, 0, -500))
			Debris:SetColor(SmokeColor.r * 0.8, SmokeColor.g * 0.8, SmokeColor.b * 0.8)
		end
	end

	local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), self.Origin - self.DirVec * 1)

	if Flash then
		Flash:SetLifeTime(0)
		Flash:SetDieTime(0.05)
		Flash:SetStartAlpha(255)
		Flash:SetEndAlpha(255)
		Flash:SetStartSize(2 * (self.Caliber + 1))
		Flash:SetEndSize(3 * (self.Caliber + 1))
		Flash:SetRoll(math.Rand(150, 360))
		Flash:SetRollDelta(math.Rand(-0.3, 0.3))
		Flash:SetLighting( false )
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 5)

	if Dust then
		Dust:SetLifeTime(0)
		Dust:SetDieTime(1)
		Dust:SetStartAlpha(200)
		Dust:SetEndAlpha(75)
		Dust:SetStartSize(5 * self.Caliber)
		Dust:SetEndSize(25 * self.Caliber)
		Dust:SetRoll(math.Rand(150, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetColor(SmokeColor.r * 0.9, SmokeColor.g * 0.9, SmokeColor.b * 0.9)
	end


end

function EFFECT:Flesh( SmokeColor )

	if not self.Emitter then return end

	local Vel = self.Velocity / 2500
	local Mass = self.Mass

	local HalfArea = (RoundTypesSubCaliberBoost[self.Id] and 0.75) or 1
	local ShellArea = 3.141 * (self.Caliber / 2) * HalfArea

	local Pmul = 1

	--KE main formula
	local Energy = math.Clamp((((Mass * (Vel ^ 2)) / 2) / 2) * ShellArea, 4, math.max(ShellArea ^ 0.95, 4))

	local ParticleCount = math.ceil( math.Clamp( self.Caliber * 2, 3, 100 ) * Pmul )

	for _ = 1, ParticleCount do
		local Debris = self.Emitter:Add("effects/mh_blood" .. math.random(1,3), self.Origin - self.DirVec * 15)

		if Debris then
			Debris:SetVelocity((self.HitNorm + VectorRand() * 0.45) * 10 * Energy)
			Debris:SetLifeTime(0)
			Debris:SetDieTime(math.Rand(1, 2) * (Energy / 3))
			Debris:SetStartAlpha(255)
			Debris:SetEndAlpha(255)
			Debris:SetStartSize(1 * (self.Caliber + 2))
			Debris:SetEndSize(1 * (self.Caliber + 2))
			Debris:SetRoll(math.Rand(150, 360))
			Debris:SetRollDelta(math.Rand(-0.2, 0.2))
			Debris:SetAirResistance(5)
			Debris:SetGravity(Vector(0, 0, -150))
			Debris:SetColor(SmokeColor.r * 0.8, SmokeColor.g * 0.8, SmokeColor.b * 0.8)
		end
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 5)

	if Dust then
		Dust:SetLifeTime(0)
		Dust:SetDieTime(1)
		Dust:SetStartAlpha(200)
		Dust:SetEndAlpha(75)
		Dust:SetStartSize(2 * self.Caliber)
		Dust:SetEndSize(12 * self.Caliber)
		Dust:SetRoll(math.Rand(150, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetGravity(Vector(0, 0, -50))
		Dust:SetColor(SmokeColor.r * 0.9, SmokeColor.g * 0.9, SmokeColor.b * 0.9)
	end


end

function EFFECT:Glass( SmokeColor )

	if not self.Emitter then return end

	local Vel = self.Velocity / 2500
	local Mass = self.Mass

	local HalfArea = (RoundTypesSubCaliberBoost[self.Id] and 0.75) or 1
	local ShellArea = 3.141 * (self.Caliber / 2) * HalfArea

	local Pmul = 1

	--KE main formula
	local Energy = math.Clamp((((Mass * (Vel ^ 2)) / 2) / 2) * ShellArea, 4, math.max(ShellArea ^ 0.95, 4))

	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 4, 2, 100 ) * Pmul )

	for _ = 1, ParticleCount do
		local Debris = self.Emitter:Add("effects/fleck_glass" .. math.random(1,3), self.Origin - self.DirVec * 15)

		if Debris then
			Debris:SetVelocity((self.HitNorm + VectorRand() * 0.45) * 100 * Energy)
			Debris:SetLifeTime(0)
			Debris:SetDieTime(math.Rand(1, 2) * (Energy / 3))
			Debris:SetStartAlpha(255)
			Debris:SetEndAlpha(255)
			Debris:SetStartSize(1.25 * (self.Caliber + 2))
			Debris:SetEndSize(1.25 * (self.Caliber + 2))
			Debris:SetRoll(math.Rand(150, 360))
			Debris:SetRollDelta(math.Rand(-0.2, 0.2))
			Debris:SetAirResistance(15)
			Debris:SetGravity(Vector(0, 0, -500))
			Debris:SetColor(SmokeColor.r * 0.8, SmokeColor.g * 0.8, SmokeColor.b * 0.8)
		end
	end

	local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), self.Origin - self.DirVec * 1)

	if Flash then
		Flash:SetLifeTime(0)
		Flash:SetDieTime(0.05)
		Flash:SetStartAlpha(255)
		Flash:SetEndAlpha(255)
		Flash:SetStartSize(2 * (self.Caliber + 1))
		Flash:SetEndSize(3 * (self.Caliber + 1))
		Flash:SetRoll(math.Rand(150, 360))
		Flash:SetRollDelta(math.Rand(-0.3, 0.3))
		Flash:SetLighting( false )
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 5)

	if Dust then
		Dust:SetLifeTime(0)
		Dust:SetDieTime(1)
		Dust:SetStartAlpha(200)
		Dust:SetEndAlpha(75)
		Dust:SetStartSize(5 * self.Caliber)
		Dust:SetEndSize(25 * self.Caliber)
		Dust:SetRoll(math.Rand(150, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetColor(SmokeColor.r * 0.9, SmokeColor.g * 0.9, SmokeColor.b * 0.9)
	end


end

function EFFECT:Dust( SmokeColor )

	if not self.Emitter then return end

	local Vel = self.Velocity / 2500
	local Mass = self.Mass

	local HalfArea = (RoundTypesSubCaliberBoost[self.Id] and 0.75) or 1
	local ShellArea = 3.141 * (self.Caliber / 2) * HalfArea

	local Pmul = 1

	--KE main formula
	local Energy = math.Clamp((((Mass * (Vel ^ 2)) / 2) / 2) * ShellArea, 4, math.max(ShellArea ^ 0.95, 4))

	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 8, 2, 100 ) * Pmul )


	local DustSpeed = 50
	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 15)

		if Dust then
			Dust:SetVelocity(self.HitNorm * DustSpeed * Energy / ParticleCount * 1.75)
			DustSpeed = DustSpeed + 50
			--			Dust:SetVelocity(VectorRand() * math.random(20, 30 * Energy))
			Dust:SetLifeTime(0)
			Dust:SetDieTime(1 * (Energy / 3))
			Dust:SetStartAlpha(255)
			Dust:SetEndAlpha(0)
			Dust:SetStartSize(0.5 * Energy)
			Dust:SetEndSize(10 * Energy * (DustSpeed / 50))
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetAirResistance(15)
			Dust:SetGravity(Vector(0, 0, -540))
			Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
		end
	end

	local Radius = (1.25 * self.Caliber)
	local Angle      = self.HitNorm:Angle()

	for _ = 0, 3 do

		Angle:RotateAroundAxis(Angle:Forward(), 60 )
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), self.Origin - self.DirVec * 15 )

		if Smoke then
			Smoke:SetVelocity( ShootVector * math.Rand(5,100 * Radius) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( math.Rand( 1 , 2 ) * Radius / 3 )
			Smoke:SetStartAlpha( math.Rand( 50, 120 ) )
			Smoke:SetEndAlpha( 20 )
			Smoke:SetStartSize( 10 * Radius )
			Smoke:SetEndSize( 16 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 200 )
			Smoke:SetGravity( Vector( math.Rand( -20 , 20 ), math.Rand( -20 , 20 ), math.Rand( 25 , 100 ) ) )

			Smoke:SetColor( SmokeColor.r * 0.8,SmokeColor.g * 0.8,SmokeColor.b * 0.8 )
		end
	end

	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 2, 2, 100 ) * Pmul )

	for _ = 1, ParticleCount do
		local Debris = self.Emitter:Add("effects/fleck_cement" .. math.random(1,2), self.Origin - self.DirVec * 1)

		if Debris then
			Debris:SetVelocity((self.HitNorm + VectorRand() * 0.4) * 100 * Energy)
			Debris:SetLifeTime(0)
			Debris:SetDieTime(math.Rand(1, 2) * (Energy / 3))
			Debris:SetStartAlpha(255)
			Debris:SetEndAlpha(255)
			Debris:SetStartSize(1 * (self.Caliber + 2))
			Debris:SetEndSize(1 * (self.Caliber + 2))
			Debris:SetRoll(math.Rand(150, 360))
			Debris:SetRollDelta(math.Rand(-0.2, 0.2))
			Debris:SetAirResistance(15)
			Debris:SetGravity(Vector(0, 0, -500))
			Debris:SetColor(SmokeColor.r * 0.8, SmokeColor.g * 0.8, SmokeColor.b * 0.8)
		end
	end

end

function EFFECT:Metal( SmokeColor )

	if not self.Emitter then return end

	local Vel = self.Velocity / 2500
	local Mass = self.Mass

	--this is the size boost fo subcaliber rounds
	local Boost = ( RoundTypesSubCaliberBoost[self.Id] and 2) or 1

	--KE main formula
	local Energy = math.max(((Mass * (Vel ^ 2)) / 2) * 0.005 * Boost, 2)
	local Pmul = 0.5

--	if self.Type == "RAC" then
--		Pmul = Pmul * 0
--	end


	local RNorm = (self.DirVec - 2 * (self.DirVec * self.HitNorm) * self.HitNorm):GetNormalized() --Reflects Shell direction across hitnormal

	local ParticleCount = math.ceil( math.Clamp( self.Caliber / 6, 3, 150 ) * Pmul )

	local DustSpeed = 10 / ParticleCount
	for _ = 1, math.ceil(6 * Pmul) do
		local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 3)

		if Dust then
			Dust:SetVelocity(RNorm * DustSpeed * self.Caliber * 5)
			DustSpeed = DustSpeed + (15 / ParticleCount)
			Dust:SetLifeTime(-0.05)
			Dust:SetDieTime(0.75 * (Energy / 3))
			Dust:SetStartAlpha(255 / ParticleCount * 2)
			Dust:SetEndAlpha(30 / ParticleCount * 2)
			Dust:SetStartSize(0.05 * DustSpeed * self.Caliber)
			Dust:SetEndSize(1 * DustSpeed * self.Caliber)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetAirResistance(200)
			Dust:SetGravity(Vector(0, 0, -440))
			Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
		end
	end


	local ParticleCount = math.ceil( math.Clamp( self.Caliber, 3, 600 ) * Pmul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/spark", self.Origin - self.HitNorm * -15)

		if Dust then
			Dust:SetVelocity((RNorm + VectorRand() * 0.45) * 200 * self.Caliber)
			local Lifetime = math.Rand(0.35, 0.4)
			Dust:SetLifeTime(-0.05)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(100)
			Dust:SetEndAlpha(20)
			local size = math.Rand(0.5, 4) * 0.5
			Dust:SetStartSize(size * self.Caliber)
			Dust:SetEndSize(size * 0.5 * self.Caliber)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -340))
			Dust:SetLighting( false )
			Dust:SetCollide( true )
			--Dust:SetBounce( 0.4 )	
			Dust:SetAirResistance(5)
			local ColorRandom = VectorRand() * 15
			Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
			local Length = math.Rand(15, 65) * 2
			Dust:SetStartLength(Length )
			Dust:SetEndLength(Length * 0.25 ) --Length
		end
	end

	ParticleCount = math.ceil( math.Clamp( self.Caliber * 3, 2, 600 ) * Pmul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/ar2_altfire1b", self.Origin)

		if Dust then
			Dust:SetVelocity((self.HitNorm + VectorRand() * 0.45) * 35 * self.Caliber)
			local Lifetime = math.Rand(0.25, 0.4)
			Dust:SetLifeTime(-0.05)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(100)
			Dust:SetEndAlpha(20)
			local size = math.Rand(0.5, 5) * 0.3 * self.Caliber
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.5)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -140))
			Dust:SetLighting( false )
			local ColorRandom = VectorRand() * 15
			Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
			local Length = math.Rand(5, 25) * self.Caliber
			Dust:SetStartLength( Length )
		end
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 5)

	if Dust then
		Dust:SetLifeTime(0)
		Dust:SetDieTime(1)
		Dust:SetStartAlpha(200)
		Dust:SetEndAlpha(75)
		Dust:SetStartSize(5 * self.Caliber)
		Dust:SetEndSize(15 * self.Caliber)
		Dust:SetRoll(math.Rand(150, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetColor(75, 75, 75)
	end

	Flash = self.Emitter:Add("effects/ar2_altfire1b", self.Origin + self.HitNorm * 2.5 * self.Caliber)

	if Flash then
		Flash:SetLifeTime(0)
		Flash:SetDieTime(0.3)
		Flash:SetStartAlpha(255)
		Flash:SetEndAlpha(255)
		Flash:SetStartSize(15 * self.Caliber)
		Flash:SetRoll(math.Rand(150, 360))
		Flash:SetRollDelta(math.Rand(-0.3, 0.3))
		Flash:SetColor(255, 255, 255)
		Flash:SetLighting( false )
	end

	local Glow = self.Emitter:Add( "sprites/orangeflare1", self.Origin- self.HitNorm * -5 )

	if Glow then
			Glow:SetLifeTime( 0 )
			Glow:SetDieTime(0.3)
			Glow:SetStartAlpha( math.Rand( 25, 50 ) )
			Glow:SetEndAlpha( 0 )
			Glow:SetStartSize( 50 * self.Caliber )
			Glow:SetEndSize( 1  )
			Glow:SetColor( 255, 255, 255 )
	end

end

--[[---------------------------------------------------------
	THINK
-----------------------------------------------------------]]
function EFFECT:Think( )
	return false
end

--[[---------------------------------------------------------
	Draw the effect
-----------------------------------------------------------]]
function EFFECT:Render()
end
