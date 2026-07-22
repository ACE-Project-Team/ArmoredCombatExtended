--[[-------------------------------------------------------
Initializes the effect. The data is a table of data
which was passed from the server.
---------------------------------------------------------]]

local EffectDebugCvar = CreateClientConVar("ace_effect_debug", "0", true, false, "Log ACE clientside effect entry/exit.")
local function DebugEffect(tag)
	if EffectDebugCvar:GetBool() then
		print(("[ACE Effect] %s"):format(tag))
	end
end

function EFFECT:Init( data )
	DebugEffect("ace_scaled_explosion Init:Enter")

	self.HitWater = false
	self.UnderWater = false

	self.Origin        = data:GetOrigin()
	self.DirVec        = data:GetNormal()
	self.Radius        = math.max( data:GetRadius() ,1)
	self.Emitter       = ParticleEmitter( self.Origin )

	local GroundTr = { }
		GroundTr.start = self.Origin + Vector(0,0,1) * self.Radius * 0.1
		GroundTr.endpos = self.Origin - Vector(0,0,1) * self.Radius * 20
		GroundTr.mask = MASK_NPCWORLDSTATIC
	local Ground = util.TraceLine( GroundTr )

	local WaterTr = { }
		WaterTr.start = self.Origin + Vector(0,0,60 * self.Radius)
		WaterTr.endpos = self.Origin + Vector(0,0,1)
		WaterTr.mask = MASK_WATER
	local Water = util.TraceLine( WaterTr )

	if Water.HitWorld then
		self.HitWater = true
		if Water.StartSolid then
			self.UnderWater = true
		end
	end

	local Mat = Ground.MatType or 0
	--print(Ground.MatType)
	local Material = ACE_GetMaterialName( Mat )

	--Overide with ACE prop material
	if Ground.HitNonWorld then
		Mat = Mat

		--I guess the material is serverside only ATM? TEnt.ACF.Material doesn't return anything valid.
		--TODO: Add clienside way to get ACF Material
		Material = "Metal"
	end

	local SmokeColor = ACE.DustMaterialColor[Material] or ACE.DustMaterialColor["Dirt"] --Enabling lighting on particles produced some yucky results when gravity pulled particles below the map.
	local SMKColor = Color( SmokeColor.r, SmokeColor.g, SmokeColor.b, 150 ) --Used to prevent it from overwriting the global smokecolor :/
	local AmbLight = render.GetLightColor( self.Origin + self.DirVec * -3 ) * 2 + render.GetAmbientLightColor()
	SMKColor.r = math.floor(SMKColor.r * math.Clamp( AmbLight.x, 0, 1 ) * 1)
	SMKColor.g = math.floor(SMKColor.g * math.Clamp( AmbLight.y, 0, 1 ) * 1)
	SMKColor.b = math.floor(SMKColor.b * math.Clamp( AmbLight.z, 0, 1 ) * 1)

	self.HitNormal = Ground.HitNormal

	if not self.HitWater and not self.UnderWater then
		-- when detonation is in midair
		if Material == "Dirt" or Material == "Sand"  then
			self:Dirt( SMKColor )
		else -- Nonspecific
			self:Dirt( SMKColor )
		end
	end

	if Ground.HitWorld and not Ground.HitSky then

		if self.HitWater and not self.UnderWater then
			self:Water( Water )
		else
			self:Shockwave( Ground, SMKColor )
		end
	end

	--Main explosion
	if self.Radius < 7 then
		self:ExplosionSmall()
		ACE_RenderLight( 0, self.Radius * 700, Color(255, 90, 15), self.Origin, 0.2) -- idx 0: world
	elseif self.Radius < 15 then
		self:ExplosionMedium()
		ACE_RenderLight( 0, self.Radius * 1600, Color(255, 90, 15), self.Origin, 0.5) -- idx 0: world
	else
		self:ExplosionMedium()
		ACE_RenderLight( 0, self.Radius * 1800, Color(255, 90, 15), self.Origin, 1) -- idx 0: world
	end

	ACE_SBlast( self.Origin, self.Radius, self.HitWater, Ground.HitWorld )

	local PlayerDist = (LocalPlayer():GetPos() - self.Origin):Length() / 20 + 0.001 --Divide by 0 is death, 20 is roughly 39.37 / 2
	if PlayerDist < self.Radius * 10 and not LocalPlayer():HasGodMode() then
		local Amp          = math.min(self.Radius * 0.5 / math.max(PlayerDist,1),40)
		util.ScreenShake( self.Origin, 50 * Amp, 1.5 / Amp, self.Radius / 7.5, 0 , true)
	end

	if IsValid(self.Emitter) then self.Emitter:Finish() end
	DebugEffect("ace_scaled_explosion Init:Exit")
end


function EFFECT:ExplosionSmall()

	if not self.Emitter then return end

	local Radius = self.Radius
	local PMul = 0.5
	local Glow = self.Emitter:Add( "sprites/orangeflare1", self.Origin - self.DirVec * (25 + 1.5 * Radius))

	if Glow then
		Glow:SetLifeTime( 0 )
		Glow:SetDieTime( 0.15 )
		Glow:SetStartAlpha( 150 )
		Glow:SetEndAlpha( 30 )
		Glow:SetStartSize( 1.5 * Radius )
		Glow:SetEndSize( 97.5 * Radius  )
		Glow:SetColor( 255, 225, 225 )
	end

	local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), self.Origin - self.DirVec * (25 + 1.5 * Radius))

	if Flash then
		Flash:SetLifeTime(0)
		Flash:SetDieTime(0.15)
		Flash:SetStartAlpha(100)
		Flash:SetEndAlpha(100)
		Flash:SetStartSize(3 * Radius)
		Flash:SetEndSize(12 * Radius)
		Flash:SetRoll(math.Rand(150, 360))
		Flash:SetRollDelta(math.Rand(-0.3, 0.3))
		Flash:SetLighting( false )
	end

	local ParticleCount = math.ceil( math.Clamp( Radius * 6, 3, 600 ) * PMul )
	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/ar2_altfire1b", self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Dust then
			Dust:SetVelocity((VectorRand()) * 210 * Radius)
			local Lifetime = math.Rand(0.25, 0.4)
			Dust:SetLifeTime(0)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(100)
			Dust:SetEndAlpha(20)
			local size = math.Rand(0.45, 3.6) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -340))
			Dust:SetAirResistance(250)
			Dust:SetLighting( false )
			local ColorRandom = VectorRand() * 15
			Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
			local Length = math.Rand(20, 40) * Radius
			Dust:SetStartLength( Length )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 10, 3, 600 ) * PMul )
	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/splash4", self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Dust then
			Dust:SetVelocity((VectorRand()) * 210 * Radius)
			local Lifetime = math.Rand(0.25, 0.4)
			Dust:SetLifeTime(0)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(200)
			Dust:SetEndAlpha(50)
			local size = math.Rand(4.5, 22.5) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -340))
			Dust:SetAirResistance(250)
			Dust:SetLighting( false )
			local ColorRandom = VectorRand() * 10
			Dust:SetColor(100 - ColorRandom.x, 100 - ColorRandom.y, 100 - ColorRandom.z)
			local Length = math.Rand(15, 37.5) * Radius
			Dust:SetStartLength( Length )
		end
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 5)
	if Dust then
		Dust:SetLifeTime(0)
		Dust:SetDieTime(0.2)
		Dust:SetStartAlpha(75)
		Dust:SetEndAlpha(100)
		Dust:SetStartSize(0)
		Dust:SetEndSize(30 * Radius)
		Dust:SetRoll(math.Rand(130, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetColor(50, 50, 50)
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), self.Origin - self.DirVec * 5)
	if Dust then
		Dust:SetLifeTime(-0.15)
		Dust:SetDieTime(0.3)
		Dust:SetStartAlpha(150)
		Dust:SetEndAlpha(30)
		Dust:SetStartSize(30 * Radius)
		Dust:SetEndSize(67.5 * Radius)
		Dust:SetRoll(math.Rand(130, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(15)
		Dust:SetColor(50, 50, 50)
	end
end

function EFFECT:ExplosionMedium()

	if not self.Emitter then return end

	local Radius = self.Radius
	local PMul = 0.5

	--Radius Debugging Circle

	local Test = Radius * 1.3 * 0 --1.3 for lethal radius. 1.0 for Indicated radius of HE
	local B = self.Emitter:Add( "effects/splashwake3", self.Origin + Vector(0,0,0) )

	if B then
		B:SetLifeTime( 0 )
		B:SetDieTime( 1 )
		B:SetStartAlpha( 255 )
		B:SetEndAlpha( 255 )
		B:SetStartSize( 20.915 * Test )
		B:SetEndSize( 20.915 * Test )
		B:SetColor( 255, 255, 255 )
	end

	local Glow = self.Emitter:Add( "sprites/orangeflare1", self.Origin - self.DirVec * (25 + 1.5 * Radius))

	if Glow then
		Glow:SetLifeTime( 0 )
		Glow:SetDieTime( 0.25 )
		Glow:SetStartAlpha( 200 )
		Glow:SetEndAlpha( 30 )
		Glow:SetStartSize( 1.5 * Radius )
		Glow:SetEndSize( 110 * Radius  )
		Glow:SetColor( 255, 225, 225 )
	end

	local Glow = self.Emitter:Add( "effects/yellowflare", self.Origin - self.DirVec * (25 + 1.5 * Radius))

	if Glow then
		Glow:SetLifeTime( 0 )
		Glow:SetDieTime( 0.5 )
		Glow:SetStartAlpha( 100 )
		Glow:SetEndAlpha( 0 )
		Glow:SetStartSize( 1.5 * Radius )
		Glow:SetEndSize( 130 * Radius  )
		Glow:SetColor( 255, 255, 255 )
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 5, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Flash then
			Flash:SetVelocity((VectorRand()) * 240 * Radius)
			Flash:SetLifeTime(0)
			Flash:SetDieTime(0.2)
			Flash:SetStartAlpha(255)
			Flash:SetEndAlpha(255)
			Flash:SetStartSize(1 * Radius)
			Flash:SetEndSize(10 * Radius)
			Flash:SetRoll(math.Rand(150, 360))
			Flash:SetRollDelta(math.Rand(-0.3, 0.3))
			Flash:SetAirResistance(600)
			Flash:SetLighting( false )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Flash = self.Emitter:Add("effects/ar2_altfire1b", self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Flash then
			Flash:SetVelocity((VectorRand()) * 240 * Radius)
			Flash:SetLifeTime(0)
			Flash:SetDieTime(0.2)
			Flash:SetStartAlpha(255)
			Flash:SetEndAlpha(255)
			Flash:SetStartSize(1 * Radius)
			Flash:SetEndSize(10 * Radius)
			Flash:SetRoll(math.Rand(150, 360))
			Flash:SetRollDelta(math.Rand(-0.3, 0.3))
			Flash:SetAirResistance(600)
			Flash:SetLighting( false )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 8, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/ar2_altfire1b", self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Dust then
			Dust:SetVelocity((VectorRand()) * 130 * Radius)
			local Lifetime = math.Rand(0.25, 0.5)
			Dust:SetLifeTime(0)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(100)
			Dust:SetEndAlpha(20)
			local size = math.Rand(0.45, 3.375) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -740))
			Dust:SetAirResistance(250)
			Dust:SetLighting( false )
			local ColorRandom = VectorRand() * 15
			Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
			local Length = math.Rand(15, 37.5) * Radius
			Dust:SetStartLength( Length )
			Dust:SetEndLength( Length * 0.15 )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 15, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/fire_embers" .. math.random(1,2), self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Dust then
			Dust:SetVelocity((VectorRand()) * 120 * Radius)
			local Lifetime = math.Rand(0.4, 0.7)
			Dust:SetLifeTime(0)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(255)
			Dust:SetEndAlpha(50)
			local size = math.Rand(2, 7.5) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -840))
			Dust:SetAirResistance(150)
			Dust:SetLighting( false )
			local ColorRandom = VectorRand() * 15
			Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 2, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/splash4", self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Dust then
			Dust:SetVelocity((VectorRand()) * 120 * Radius)
			local Lifetime = math.Rand(0.7, 1.0)
			Dust:SetLifeTime(0)
			Dust:SetDieTime(Lifetime)
			Dust:SetStartAlpha(200)
			Dust:SetEndAlpha(50)
			local size = math.Rand(4, 20) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -540))
			Dust:SetAirResistance(150)
			Dust:SetLighting( false )
			local ColorRandom = VectorRand() * 10
			Dust:SetColor(100 + ColorRandom.x, 100 + ColorRandom.y, 100 + ColorRandom.z)
			local Length = math.Rand(15, 45) * Radius
			Dust:SetStartLength( Length * 1.5 )
			Dust:SetEndLength( Length * 0.5 )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 0.75, 3, 300 ) * PMul )

	for _ = 1, ParticleCount do
		local Flash = self.Emitter:Add("particle/smokesprites_000" .. math.random(1,9), self.Origin - self.DirVec * (25 + 1.5 * Radius))

		if Flash then
			Flash:SetVelocity((VectorRand()) * 75 * Radius)
			Flash:SetLifeTime(-0.3)
			Flash:SetDieTime(4)
			Flash:SetStartAlpha(60)
			Flash:SetEndAlpha(0)
			Flash:SetStartSize(25 * Radius)
			Flash:SetEndSize(45 * Radius)
			Flash:SetRoll(math.Rand(80, 140))
			Flash:SetRollDelta(math.Rand(-0.3, 0.3))
			Flash:SetGravity(Vector(0, 0, -540))
			Flash:SetAirResistance(200)
			local ColorRandom = VectorRand() * 3
			Flash:SetColor(50 + ColorRandom.x, 50 + ColorRandom.y, 50 + ColorRandom.z)
		end
	end
end


function EFFECT:Shockwave( Ground, SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_explosion Shockwave:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_explosion Shockwave:Enter")

	local PMul       = 1
	local Radius     = (1-Ground.Fraction) * self.Radius
	local Density    = Radius
	local Angle      = self.HitNormal:Angle()

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/warp2_warp", Ground.HitPos + self.HitNormal * (5 + Radius * 5) )

		if Smoke then
			Smoke:SetVelocity( ShootVector * 400 * Radius )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime(  0.6 * Radius / 4 )
			Smoke:SetStartAlpha( 20 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 45 * Radius )
			Smoke:SetEndSize( 0 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 200 )
			Smoke:SetCollide( true )
		end
	end

	Radius     = (1-Ground.Fraction) * self.Radius * 0.75
	Density    = Radius * 12

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), Ground.HitPos + self.HitNormal * (5 + Radius * 5) )

		if Smoke then
			Smoke:SetVelocity( ShootVector * 500 * Radius * math.Rand(0.5, 1) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime(  1.2 * Radius / 4 )
			Smoke:SetStartAlpha( 20 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 5 * Radius )
			Smoke:SetEndSize( 55 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 150 )
			Smoke:SetCollide( true )
			Smoke:SetGravity(Vector(0, 0, 0))
			local SMKColor = math.random( 0 , 20 )
			Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
		end
	end


	DebugEffect("ace_scaled_explosion Shockwave:Exit")
end

local TextureTb = {
	"effects/splash4",
	"particle/smokesprites_0001",
	"particle/smokesprites_0002",
	"particle/smokesprites_0003",
	"particle/smokesprites_0004",
	"particle/smokesprites_0005",
	"particle/smokesprites_0006",
	"particle/smokesprites_0007",
	"particle/smokesprites_0008",
	"particle/smokesprites_0009",

}

function EFFECT:Water( Water )

	if not self.Emitter then
		DebugEffect("ace_scaled_explosion Water:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_explosion Water:Enter")

	local PMul = 1

	local WaterColor = Color(255,255,255,100)

	local Radius   = self.Radius
	local Density  = Radius * 15
	local Angle    = Water.HitNormal:Angle()
	local Dist     = math.max(math.abs((self.Origin - Water.HitPos):Length()) * 0.01,1)

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( TextureTb[math.random(#TextureTb)], Water.HitPos + Vector(0,0,5) )

		if Smoke then
			Smoke:SetVelocity( ShootVector * math.Rand(5,100 * Radius) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( math.Rand( 2 , 6 ) * Radius / 3 )
			Smoke:SetStartAlpha( math.Rand( 50, 120 ) )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 10 * Radius )
			Smoke:SetEndSize( 16 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 100 )
			Smoke:SetGravity( Vector( math.Rand( -20 , 20 ), math.Rand( -20 , 20 ), math.Rand( -25 , -150 ) ) )

			local SMKColor = math.random( 0 , 50 )
			Smoke:SetColor( WaterColor.r-SMKColor,WaterColor.g-SMKColor,WaterColor.b-SMKColor )
		end
	end

	for _ = 0, 2 * Radius * PMul do

		local Whisp = self.Emitter:Add( TextureTb[math.random(#TextureTb)], Water.HitPos )

		if Whisp then
			local Randvec = VectorRand()
			local absvec = math.abs(Randvec.y)

			Whisp:SetVelocity(Vector(Randvec.x,Randvec.y,absvec) * math.random( 100 * Radius / Dist,150 * Radius / Dist) * Vector(0.15,0.15,1))
			Whisp:SetLifeTime( 0 )
			Whisp:SetDieTime( math.Rand( 3 , 5 ) * Radius / 3  )
			Whisp:SetStartAlpha( math.Rand( 100, 125 ) )
			Whisp:SetEndAlpha( 0 )
			Whisp:SetStartSize( 10 * Radius )
			Whisp:SetEndSize( 80 * Radius )
			Whisp:SetRoll( math.Rand(150, 360) )
			Whisp:SetRollDelta( math.Rand(-0.2, 0.2) )
			Whisp:SetAirResistance( 100 )
			Whisp:SetGravity( Vector( math.random(-5,5) * Radius, math.random(-5,5) * Radius, -400 ) )

			local SMKColor = math.random( 0 , 50 )
			Whisp:SetColor( WaterColor.r-SMKColor,WaterColor.g-SMKColor,WaterColor.b-SMKColor )
		end
	end
	DebugEffect("ace_scaled_explosion Water:Exit")
end

function EFFECT:Concrete( SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_explosion Concrete:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_explosion Concrete:Enter")

	for _ = 0, 5 * self.Radius do --Flying Debris

		local Fragments = self.Emitter:Add( "effects/fleck_tile" .. math.random(1,2), self.Origin )
		if Fragments then
			Fragments:SetVelocity ( VectorRand() * math.random(50 * self.Radius,150 * self.Radius) )
			Fragments:SetLifeTime( 0 )
			Fragments:SetDieTime( math.Rand( 1 , 2 ) * self.Radius / 3 )
			Fragments:SetStartAlpha( 255 )
			Fragments:SetEndAlpha( 0 )
			Fragments:SetStartSize( 0.25 * self.Radius )
			Fragments:SetEndSize( 0.25 * self.Radius )
			Fragments:SetRoll( math.Rand(0, 360) )
			Fragments:SetRollDelta( math.Rand(-3, 3) )
			Fragments:SetAirResistance( 5 )
			Fragments:SetGravity( Vector( 0, 0, -650 ) )

			RandColor = 80-math.random( 0 , 50 )

			Fragments:SetColor( RandColor,RandColor,RandColor )
			Fragments:SetColor( RandColor,RandColor,RandColor )
		end
	end

	for _ = 0, 3 * self.Radius do

		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), self.Origin )
		if Smoke then
			Smoke:SetVelocity( self.HitNormal * math.random( 50,80 * self.Radius) + VectorRand() * math.random( 30,60 * self.Radius) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( math.Rand( 1 , 2 ) * self.Radius / 3  )
			Smoke:SetStartAlpha( math.Rand( 50, 150 ) )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 5 * self.Radius )
			Smoke:SetEndSize( 30 * self.Radius )
			Smoke:SetRoll( math.Rand(150, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 50 )
			Smoke:SetGravity( Vector( math.random(-5,5) * self.Radius, math.random(-5,5) * self.Radius, -250 ) )

			Smoke:SetColor(  SmokeColor.r,SmokeColor.g,SmokeColor.b  )
		end
	end
	DebugEffect("ace_scaled_explosion Concrete:Exit")
end

function EFFECT:Dirt( SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_explosion Dirt:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_explosion Dirt:Enter")

	local ScaleMul = 1

		if self.Radius < 10 then
			ScaleMul = 1.5
		elseif self.Radius < 20 then
			ScaleMul = 1
		end

	for _ = 0, 9 * self.Radius do

		local Texture = "effects/fleck_cement1"

		local Smoke = self.Emitter:Add( Texture, self.Origin )
		if Smoke then
			Smoke:SetVelocity( self.HitNormal * math.random( 100,300 ) * self.Radius + VectorRand() * math.random( 30, 80 ) * self.Radius )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( 2 * self.Radius / 3  )
			Smoke:SetStartAlpha( math.Rand( 5, 100 ) )
			Smoke:SetEndAlpha( 0 )
			local Size = math.Rand( 0.1, 3 ) * self.Radius
			Smoke:SetStartSize( Size )
			Smoke:SetEndSize( 0.2 * Size )
			Smoke:SetRoll( math.Rand(150, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 25 )
			Smoke:SetGravity( Vector( 0, 0, -1100 ) )

			Smoke:SetColor(  SmokeColor.r,SmokeColor.g,SmokeColor.b  )

		end
	end


	local Texture = "particles/smokey"

	for _ = 0, 2 * self.Radius do

		local Smoke = self.Emitter:Add( Texture, self.Origin )
		if Smoke then
			Smoke:SetVelocity( self.HitNormal * math.random( 75, 175 ) * self.Radius * ScaleMul + VectorRand() * math.random( 10,35) * self.Radius *  ScaleMul )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( 0.3 * self.Radius * ScaleMul / 3  )
			Smoke:SetStartAlpha( 50 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 5 * self.Radius * ScaleMul )
			Smoke:SetEndSize( 25 * self.Radius * ScaleMul )
			Smoke:SetRoll( math.Rand(150, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 100 )
			Smoke:SetGravity( Vector( math.random( -35,35 ) * self.Radius * ScaleMul, math.random( -35,35 ) * self.Radius * ScaleMul, -500 ) )

			Smoke:SetColor(  SmokeColor.r,SmokeColor.g,SmokeColor.b  )

		end
	end


	DebugEffect("ace_scaled_explosion Dirt:Exit")
end

function EFFECT:Sand( SmokeColor )
	if not self.Emitter then
		DebugEffect("ace_scaled_explosion Sand:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_explosion Sand:Enter")

	for _ = 0, 3 * self.Radius do

		local NumRand = math.random(-1, 2)
		local TScale = 1
		local Texture = "particle/smokesprites_000" .. math.random(1,9)

		if NumRand then
			TScale = 0.75
			Texture = "effects/splash4"
		end

		local Smoke = self.Emitter:Add( Texture, self.Origin )
		if Smoke then
			Smoke:SetVelocity( self.HitNormal * math.random( 50,80 * self.Radius) + VectorRand() * math.random( 30,60 * self.Radius) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime( math.Rand( 1 , 5 ) * self.Radius / 3  )
			Smoke:SetStartAlpha( math.Rand( 150, 200 ) )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 15 * self.Radius * TScale )
			Smoke:SetEndSize( 30 * self.Radius * TScale )
			Smoke:SetRoll( math.Rand(150, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 100 )
			Smoke:SetGravity( Vector( math.random(-5,5) * self.Radius, math.random(-5,5) * self.Radius, -275 ) )

			Smoke:SetColor(  SmokeColor.r,SmokeColor.g,SmokeColor.b  )
		end
	end
	DebugEffect("ace_scaled_explosion Sand:Exit")
end

function EFFECT:Airburst()

	if not self.Emitter then return end

	local Radius = self.Radius
	for _ = 0, Radius * 0.5 do --Flying Debris

		local Debris = self.Emitter:Add( "effects/fleck_tile" .. math.random(1,2), self.Origin )
		if Debris then
			Debris:SetVelocity ( VectorRand() * math.random(150 * Radius,450 * Radius) )
			Debris:SetLifeTime( 0 )
			Debris:SetDieTime( math.Rand( 0.2 , 0.4 ) * Radius / 3 )
			Debris:SetStartAlpha( 255 )
			Debris:SetEndAlpha( 0 )
			Debris:SetStartSize( 0.5 * Radius )
			Debris:SetEndSize( 0.5 * Radius )
			Debris:SetRoll( math.Rand(0, 360) )
			Debris:SetRollDelta( math.Rand(-3, 3) )
			Debris:SetAirResistance( 5 )
			Debris:SetGravity( Vector( 0, 0, -650 ) )
			Debris:SetColor( 120,120,120 )

			RandColor = 50-math.random( 0 , 50 )
			Debris:SetColor( RandColor,RandColor,RandColor )
		end
	end
end

--[[---------------------------------------------------------
	THINK
-----------------------------------------------------------]]
function EFFECT:Think( )

end

--[[---------------------------------------------------------
	Draw the effect
-----------------------------------------------------------]]
function EFFECT:Render()
end


