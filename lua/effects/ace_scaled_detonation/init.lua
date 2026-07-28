--[[-------------------------------------------------------
Initializes the effect. The data is a table of data
which was passed from the server.
---------------------------------------------------------]]

local function GetVelocityScale( radius, minVal, maxVal )
	radius = math.Clamp( radius / 40, 0, 1 )
	return Lerp( radius, minVal, maxVal )
end

local function StageParticle( particle, delay, lifetime )
	delay = delay or 0
	lifetime = math.max(lifetime or 0.1, 0.1)
	particle:SetLifeTime( delay )
	particle:SetDieTime( delay + lifetime )
end

local function RandomFireColor()
	local g = math.Rand(175, 225)
	local b = math.Rand(110, 155)
	return Color(255, g, b)
end

local function RandomSmokeColor()
	local gray = math.Rand(35, 85)
	return Color(gray, gray, gray)
end

local function ClampColor( value )
	return math.Clamp( math.floor( value ), 0, 255 )
end

local EffectDebugCvar = CreateClientConVar("acf_effect_debug", "0", true, false, "Log ACE clientside effect entry/exit.")
local function DebugEffect(tag)
	if EffectDebugCvar:GetBool() then
		print(("[ACE Effect] %s"):format(tag))
	end
end

local VisualScale = 1.3
local FlashScale = 1.25
local SmokeScale = 0.8
local MAX_VISUAL_RADIUS = 25

local function ExplosionFlashOrigin( effect, radius, extra )
	extra = extra or 0
	local offset = math.Clamp(12 + radius * 0.6 + extra, 10, 35)
	return effect.Origin - effect.DirVec * offset
end

function EFFECT:Init( data )
	DebugEffect("ace_scaled_detonation Init:Enter")

	self.HitWater = false
	self.UnderWater = false

	self.Origin        = data:GetOrigin()
	self.DirVec        = data:GetNormal()
	self.Radius        = math.max( data:GetRadius()  / 39.4 ,1)
	self.Radius        = math.min(self.Radius, MAX_VISUAL_RADIUS)
	self.Emitter       = ParticleEmitter( self.Origin )

	local GroundTr = { }
		GroundTr.start = self.Origin + Vector(0,0,1) * self.Radius * 0.1
		GroundTr.endpos = self.Origin - Vector(0,0,1) * self.Radius * 20
		GroundTr.mask = MASK_NPCWORLDSTATIC
	local Ground = util.TraceLine( GroundTr )

	if Ground.HitWorld then
		self.Origin = Ground.HitPos + Ground.HitNormal * 5
	end

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
	local Material = ACE.GetMaterialName( Mat )

	if Ground.HitNonWorld then --Overide with ACE prop material
		Mat = Mat
		--self.HitNorm = -self.HitNorm
		--self.DirVec = -self.DirVec
		--local TEnt = Ground.Entity
			--I guess the material is serverside only ATM? TEnt.ACF.Material doesn't return anything valid.
			--TODO: Add clienside way to get ACF Material
			Material = "Metal"
	end

	local SmokeColor = ACE.DustMaterialColor[Material] or ACE.DustMaterialColor["Concrete"] --Enabling lighting on particles produced some yucky results when gravity pulled particles below the map.
	local SMKColor = Color( SmokeColor.r, SmokeColor.g, SmokeColor.b, 150 ) --Used to prevent it from overwriting the global smokecolor :/
	local AmbLight = render.GetLightColor( self.Origin + self.DirVec * -3 ) * 2 + render.GetAmbientLightColor()
	SMKColor.r = math.floor(SMKColor.r * math.Clamp( AmbLight.x, 0, 1 ) * 1)
	SMKColor.g = math.floor(SMKColor.g * math.Clamp( AmbLight.y, 0, 1 ) * 1)
	SMKColor.b = math.floor(SMKColor.b * math.Clamp( AmbLight.z, 0, 1 ) * 1)

	self.HitNormal = Ground.HitNormal

	local surfaceDetonation = Ground.HitWorld and not Ground.HitSky

	if not self.HitWater and not self.UnderWater then
		-- when detonation is in midair
		if Material == "Dirt" or Material == "Sand"  then
			self:Dirt( SMKColor )
		else -- Nonspecific
			self:Dirt( SMKColor )
			--self:Concrete( SMKColor )
		end
	end

	--Main explosion
	if self.Radius < 10 then
		self:ExplosionSmall()
		ACF_RenderLight( 0, self.Radius * 450, Color(255, 90, 15), self.Origin, 0.08) -- idx 0: world
	elseif self.Radius < 20 then
		self:ExplosionMedium()
		ACF_RenderLight( 0, self.Radius * 950, Color(255, 90, 15), self.Origin, 0.12) -- idx 0: world
	else
		self:ExplosionMedium()
		ACF_RenderLight( 0, self.Radius * 1100, Color(255, 90, 15), self.Origin, 0.16) -- idx 0: world
	end

	local flashOrigin = self.Origin - self.DirVec * math.Clamp(12 + self.Radius * 0.4, 10, 30)
	local FinalFlash = self.Emitter:Add( "effects/splashwake3", flashOrigin )

	if FinalFlash then
		FinalFlash:SetLifeTime( 0 )
		FinalFlash:SetDieTime( 0.16 )
		FinalFlash:SetStartAlpha( 255 )
		FinalFlash:SetEndAlpha( 70 )
		FinalFlash:SetStartSize( (12 * self.Radius + math.Rand(-1, 2)) * VisualScale )
		FinalFlash:SetEndSize( (40 * self.Radius) * VisualScale )
		local burstColor = RandomFireColor()
		FinalFlash:SetColor( burstColor.r, burstColor.g, burstColor.b )
		FinalFlash:SetRollDelta( math.Rand( -0.5, 0.5 ) )
	end

	local FinalGlow = self.Emitter:Add( "sprites/orangeflare1", flashOrigin )

	if FinalGlow then
		FinalGlow:SetLifeTime( 0 )
		FinalGlow:SetDieTime( 0.14 )
		FinalGlow:SetStartAlpha( 220 )
		FinalGlow:SetEndAlpha( 50 )
		FinalGlow:SetStartSize( (4.5 * self.Radius + math.Rand(-1, 1)) * VisualScale )
		FinalGlow:SetEndSize( (18 * self.Radius) * VisualScale )
		FinalGlow:SetColor( 255, 200, 140 )
		FinalGlow:SetRollDelta( math.Rand(-0.4, 0.4) )
	end

	if surfaceDetonation then
		if self.HitWater and not self.UnderWater then
			self:Water( Water )
		else
			self:Shockwave( Ground, SMKColor )
		end
	end

	if not self.UnderWater then
		self:DelayedSmoke( SMKColor )
	end


	local PlayerDist = (LocalPlayer():GetPos() - self.Origin):Length() / 20 + 0.001 --Divide by 0 is death, 20 is roughly 39.37 / 2

		if PlayerDist < self.Radius * 10 and not LocalPlayer():HasGodMode() then
		--if PlayerDist < self.Radius * 10 then
		local Amp          = math.min(self.Radius * 0.5 / math.max(PlayerDist,1),40)
		util.ScreenShake( self.Origin, 50 * Amp, 1.5 / Amp, self.Radius / 7.5, 0 , true)
	end


	if IsValid(self.Emitter) then self.Emitter:Finish() end
	DebugEffect("ace_scaled_detonation Init:Exit")
end


function EFFECT:ExplosionSmall()

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation ExplosionSmall:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation ExplosionSmall:Enter")

	local Radius = self.Radius * 0.9
	local PMul = 0.5
	local FireOrigin = ExplosionFlashOrigin( self, Radius )
	local DirBias = self.DirVec * 0.25

	--local RandColor = 0
	--local WaterColor = Color(255,255,255,100)

	--Radius Debugging Circle
	--[[
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
	]]--

	local Glow = self.Emitter:Add( "sprites/orangeflare1", FireOrigin)

	if Glow then
			Glow:SetLifeTime( 0 )
			Glow:SetDieTime( 0.2 )
			Glow:SetStartAlpha( math.Rand(120, 180) )
			Glow:SetEndAlpha( math.Rand(6, 18) )
			Glow:SetStartSize( (1.3 * Radius + math.Rand(-1, 2)) * VisualScale )
			Glow:SetEndSize( math.min( 97.5 * Radius, 220 ) * VisualScale )
			Glow:SetColor( 255, math.Rand(190, 215), math.Rand(120, 170) )
			Glow:SetRollDelta( math.Rand(-0.5, 0.5) )
	end

	local FlashBurst = self.Emitter:Add( "effects/splashwake3", FireOrigin )

	if FlashBurst then
		FlashBurst:SetLifeTime( 0 )
		FlashBurst:SetDieTime( 0.15 )
		FlashBurst:SetStartAlpha( 160 )
		FlashBurst:SetEndAlpha( 20 )
		FlashBurst:SetStartSize( (10 * Radius + math.Rand(-2, 3)) * VisualScale )
		FlashBurst:SetEndSize( 80 * Radius * math.Rand(0.85, 1.2) * VisualScale )
		local burstColor = RandomFireColor()
		FlashBurst:SetColor( burstColor.r, burstColor.g, burstColor.b )
		FlashBurst:SetRollDelta( math.Rand( -0.6, 0.6 ) )
	end

	local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), FireOrigin)

	if Flash then
		Flash:SetLifeTime(0)
		Flash:SetDieTime(0.22)
		Flash:SetStartAlpha(220)
		Flash:SetEndAlpha(220)
		Flash:SetStartSize(5.5 * Radius * VisualScale * FlashScale)
		Flash:SetEndSize( math.min( 26 * Radius, 90 ) * VisualScale * FlashScale )
		Flash:SetRoll(math.Rand(150, 360))
		Flash:SetRollDelta(math.Rand(-0.3, 0.3))
		Flash:SetLighting( false )
		local flashColor = RandomFireColor()
		Flash:SetColor( flashColor.r, flashColor.g, flashColor.b )
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 8, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/ar2_altfire1b", FireOrigin)

		if Dust then
			local SpreadDir = (VectorRand() + self.HitNormal * 0.08 + DirBias):GetNormalized()
			local Velocity = SpreadDir * GetVelocityScale( Radius, 80, 150 ) + self.HitNormal * (Radius * 12 + 8) + self.DirVec * (Radius * 6)
			Dust:SetVelocity( Velocity )
			local Delay = math.Rand(0, 0.08)
			local Lifetime = math.Rand(0.4, 1.1)
			StageParticle( Dust, Delay, Lifetime )
			Dust:SetStartAlpha( math.Rand(90, 110) )
			Dust:SetEndAlpha( math.Rand(10, 30) )
			local size = math.Rand(0.9, 4.25) * Radius * VisualScale
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * math.Rand(0.1, 0.25))
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -340))
			Dust:SetAirResistance(250)
			Dust:SetLighting( false )
			local fireColor = RandomFireColor()
			local ColorRandom = VectorRand() * 8
			Dust:SetColor( ClampColor( fireColor.r + ColorRandom.x ), ClampColor( fireColor.g + ColorRandom.y ), ClampColor( fireColor.b + ColorRandom.z ) )
			local Length = math.Rand(15, 37.5) * Radius
			Dust:SetStartLength( Length )
			Dust:SetEndLength( Length * math.Rand(0.1, 0.3) )
		end
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), FireOrigin)

	if Dust then
		local delay = math.Rand(0.6, 0.85)
		local life = math.Rand(1.8, 2.6)
		StageParticle( Dust, delay, life )
		Dust:SetStartAlpha(math.Rand(35, 70))
		Dust:SetEndAlpha( math.Rand(5, 20) )
		Dust:SetStartSize( 2 * Radius * SmokeScale )
		Dust:SetEndSize( 6 * Radius * SmokeScale )
		local Vel = VectorRand() * (25 * Radius * SmokeScale)
		Vel.z = Vel.z * 0.05
		Dust:SetVelocity( Vel )
		Dust:SetRoll(math.Rand(130, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(30)
		Dust:SetGravity(Vector(0, 0, -70 * Radius * SmokeScale))
		local smokeColor = RandomSmokeColor()
		Dust:SetColor( smokeColor.r, smokeColor.g, smokeColor.b )
	end

	local Dust = self.Emitter:Add("particle/smokesprites_000" .. math.random(1, 9), FireOrigin)

	if Dust then
		local delay = math.Rand(1.1, 1.4)
		local life = math.Rand(1.9, 3.2)
		StageParticle( Dust, delay, life )
		Dust:SetStartAlpha(math.Rand(50, 90))
		Dust:SetEndAlpha(math.Rand(5, 15))
		Dust:SetStartSize(5 * Radius * SmokeScale)
		Dust:SetEndSize(10 * Radius * SmokeScale)
		local Vel = VectorRand() * (30 * Radius * SmokeScale)
		Vel.z = Vel.z * 0.1
		Dust:SetVelocity( Vel )
		Dust:SetRoll(math.Rand(130, 360))
		Dust:SetRollDelta(math.Rand(-0.2, 0.2))
		Dust:SetAirResistance(25)
		Dust:SetGravity(Vector(0, 0, -90 * Radius * SmokeScale))
		local smokeColor = RandomSmokeColor()
		Dust:SetColor( smokeColor.r, smokeColor.g, smokeColor.b )
	end

	DebugEffect("ace_scaled_detonation ExplosionSmall:Exit")
end


function EFFECT:ExplosionMedium()

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation ExplosionMedium:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation ExplosionMedium:Enter")

	local Radius = self.Radius * 0.6
	local PMul = 0.5
	local FireOrigin = ExplosionFlashOrigin( self, Radius )
	local DirBias = self.DirVec * 0.28

	--local RandColor = 0
	--local WaterColor = Color(255,255,255,100)

	--Radius Debugging Circle

	local Glow = self.Emitter:Add( "sprites/orangeflare1", FireOrigin)

	if Glow then
			Glow:SetLifeTime( 0 )
			Glow:SetDieTime( 0.2 )
			Glow:SetStartAlpha( math.Rand(140, 200) )
			Glow:SetEndAlpha( math.Rand(8, 24) )
			Glow:SetStartSize( (1.4 * Radius + math.Rand(-1, 3)) * VisualScale )
			Glow:SetEndSize( math.min( 110 * Radius, 260 ) * VisualScale )
			Glow:SetColor( 255, math.Rand(200, 220), math.Rand(140, 180) )
			Glow:SetRollDelta( math.Rand(-0.5, 0.5) )
	end

	local ImpactFlash = self.Emitter:Add( "effects/fire_cloud" .. math.random(1,2), FireOrigin )
	if ImpactFlash then
		ImpactFlash:SetLifeTime( 0 )
		ImpactFlash:SetDieTime( 0.14 )
		ImpactFlash:SetStartAlpha(math.Rand(140, 180))
		ImpactFlash:SetEndAlpha(math.Rand(10, 22))
		ImpactFlash:SetStartSize( (10 * Radius + math.Rand(-2, 3)) * VisualScale )
		ImpactFlash:SetEndSize( 40 * Radius * math.Rand(0.9, 1.05) * VisualScale )
		ImpactFlash:SetRoll( math.Rand(120, 360) )
		ImpactFlash:SetRollDelta( math.Rand(-0.4, 0.4) )
		ImpactFlash:SetLighting( false )
		local impactColor = RandomFireColor()
		ImpactFlash:SetColor( impactColor.r, impactColor.g, impactColor.b )
	end

	local Glow = self.Emitter:Add( "effects/yellowflare", FireOrigin)

	if Glow then
			Glow:SetLifeTime( 0 )
			Glow:SetDieTime( 0.45 )
			Glow:SetStartAlpha( 100 )
			Glow:SetEndAlpha( 0 )
			Glow:SetStartSize( 1.5 * Radius * VisualScale )
			Glow:SetEndSize( 130 * Radius * VisualScale )
			Glow:SetColor( 255, 255, 255 )
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 3.5, 2, 450 ) * PMul )

	for _ = 1, ParticleCount do
		local Flash = self.Emitter:Add("effects/fire_cloud" .. math.random(1,2), FireOrigin)

		if Flash then
			local SpreadDir = (VectorRand() + self.HitNormal * 0.25 + DirBias):GetNormalized()
			local Velocity = SpreadDir * GetVelocityScale( Radius, 110, 190 ) + self.HitNormal * (Radius * 12 + 10) + self.DirVec * (Radius * 8)
			Flash:SetVelocity( Velocity )
			Flash:SetLifeTime(0)
			Flash:SetDieTime(0.18)
			Flash:SetStartAlpha(220)
			Flash:SetEndAlpha(220)
			Flash:SetStartSize(1 * Radius * VisualScale * FlashScale)
			Flash:SetEndSize(7.5 * Radius * VisualScale * FlashScale)
			Flash:SetRoll(math.Rand(150, 360))
			Flash:SetRollDelta(math.Rand(-0.3, 0.3))
			Flash:SetAirResistance(600)
			Flash:SetLighting( false )
			local flashColor = RandomFireColor()
			Flash:SetColor( flashColor.r, flashColor.g, flashColor.b )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 0.6, 2, 400 ) * PMul )

	for _ = 1, ParticleCount do
		local Flash = self.Emitter:Add("effects/ar2_altfire1b", FireOrigin)

		if Flash then
			local SpreadDir = (VectorRand() + self.HitNormal * 0.15 + DirBias):GetNormalized()
			local Velocity = SpreadDir * GetVelocityScale( Radius, 100, 170 ) + self.HitNormal * (Radius * 10 + 6) + self.DirVec * (Radius * 6)
			Flash:SetVelocity( Velocity )
			Flash:SetLifeTime(0)
			Flash:SetDieTime(0.18)
			Flash:SetStartAlpha(215)
			Flash:SetEndAlpha(215)
			Flash:SetStartSize(1 * Radius * VisualScale * FlashScale)
			Flash:SetEndSize(7.5 * Radius * VisualScale * FlashScale)
			Flash:SetRoll(math.Rand(150, 360))
			Flash:SetRollDelta(math.Rand(-0.3, 0.3))
			Flash:SetAirResistance(600)
			Flash:SetLighting( false )
			local flashColor = RandomFireColor()
			Flash:SetColor( flashColor.r, flashColor.g, flashColor.b )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 12, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/ar2_altfire1b", FireOrigin)

		if Dust then
			local SpreadDir = (VectorRand() + self.HitNormal * 0.2 + DirBias):GetNormalized()
			local Velocity = SpreadDir * GetVelocityScale( Radius, 90, 150 ) + self.HitNormal * (Radius * 8 + 5) + self.DirVec * (Radius * 7)
			Dust:SetVelocity( Velocity )
			local Delay = math.Rand(0.08, 0.18)
			local Lifetime = math.Rand(0.4, 1.1)
			StageParticle( Dust, Delay, Lifetime )
			Dust:SetStartAlpha(math.Rand(80, 110))
			Dust:SetEndAlpha(math.Rand(20, 40))
			local size = math.Rand(0.45, 3.375) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -740))
			Dust:SetAirResistance(250)
			Dust:SetLighting( false )
			local fireColor = RandomFireColor()
			local ColorRandom = VectorRand() * 12
			Dust:SetColor( ClampColor( fireColor.r + ColorRandom.x ), ClampColor( fireColor.g + ColorRandom.y ), ClampColor( fireColor.b + ColorRandom.z ) )
			local Length = math.Rand(15, 37.5) * Radius
			Dust:SetStartLength( Length )
			Dust:SetEndLength( Length * math.Rand(0.15, 0.35) )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 10, 3, 600 ) * PMul )

	for _ = 1, ParticleCount do
		local Dust = self.Emitter:Add("effects/fire_embers" .. math.random(1,2), FireOrigin)

		if Dust then
			local SpreadDir = (VectorRand() + self.HitNormal * 0.12 + DirBias):GetNormalized()
			local Velocity = SpreadDir * GetVelocityScale( Radius, 70, 130 ) + self.HitNormal * (Radius * 6 + 4) + self.DirVec * (Radius * 5)
			Dust:SetVelocity( Velocity )
			local Delay = math.Rand(0.12, 0.25)
			local Lifetime = math.Rand(0.4, 1.2)
			StageParticle( Dust, Delay, Lifetime )
			Dust:SetStartAlpha(math.Rand(180, 230))
			Dust:SetEndAlpha(math.Rand(30, 70))
			local size = math.Rand(2, 7.5) * Radius
			Dust:SetStartSize(size)
			Dust:SetEndSize(size * 0.25)
			Dust:SetRoll(math.Rand(150, 360))
			Dust:SetRollDelta(math.Rand(-0.2, 0.2))
			Dust:SetGravity(Vector(0, 0, -840))
			Dust:SetAirResistance(150)
			Dust:SetLighting( false )
			local fireColor = RandomFireColor()
			local ColorRandom = VectorRand() * 20
			Dust:SetColor( ClampColor( fireColor.r + ColorRandom.x ), ClampColor( fireColor.g + ColorRandom.y ), ClampColor( fireColor.b + ColorRandom.z ) )
		end
	end

	ParticleCount = math.ceil( math.Clamp( Radius * 0.8 * VisualScale, 3, 140 ) * PMul )

	for _ = 1, ParticleCount do
		local Flash = self.Emitter:Add("particle/smokesprites_000" .. math.random(1,9), FireOrigin)

		if Flash then
			local Vel = VectorRand() * (28 * Radius * SmokeScale)
			Vel.z = Vel.z * 0.12
			Flash:SetVelocity( Vel )
			local Delay = math.Rand(0.8, 1.15)
			local Lifetime = math.Rand(3.2, 5)
			StageParticle( Flash, Delay, Lifetime )
			Flash:SetStartAlpha( math.Rand(30, 55) )
			Flash:SetEndAlpha( math.Rand(0, 6) )
			Flash:SetStartSize(3 * Radius * SmokeScale)
			Flash:SetEndSize(7 * Radius * SmokeScale)
			Flash:SetRoll(math.Rand(80, 140))
			Flash:SetRollDelta(math.Rand(-0.3, 0.3))
			Flash:SetGravity(Vector(0, 0, -110 * Radius * SmokeScale))
			Flash:SetAirResistance(200)
			local ColorRandom = VectorRand() * 3
			local smokeColor = RandomSmokeColor()
			Flash:SetColor( ClampColor( smokeColor.r + ColorRandom.x ), ClampColor( smokeColor.g + ColorRandom.y ), ClampColor( smokeColor.b + ColorRandom.z ) )
		end
	end

	DebugEffect("ace_scaled_detonation ExplosionMedium:Exit")
end


function EFFECT:Shockwave( Ground, SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation Shockwave:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation Shockwave:Enter")

	local PMul       = 1
	local Radius     = (1-Ground.Fraction) * self.Radius
	local Density    = Radius
	local Angle      = self.HitNormal:Angle()

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/warp2_warp", Ground.HitPos + self.HitNormal * (5 + Radius * 5) )

		if Smoke then
			Smoke:SetVelocity( ShootVector * 160 * Radius )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime(  0.55 * Radius / 4 )
			Smoke:SetStartAlpha( 30 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 40 * Radius )
			Smoke:SetEndSize( 0 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 200 )
			Smoke:SetCollide( true )

			--local SMKColor = math.random( 0 , 50 )
			--Smoke:SetColor( SmokeColor.r-SMKColor,SmokeColor.g-SMKColor,SmokeColor.b-SMKColor )
		end
	end

	--[[
	PMul       = self.ParticleMul
	Radius     = (1-Ground.Fraction) * self.Radius * 0.75
	Density    = Radius * 12
	Angle      = self.HitNormal:Angle()

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), Ground.HitPos + self.HitNormal * (5 + Radius * 5) )

		if Smoke then
			Smoke:SetVelocity( ShootVector * 500 * Radius * math.Rand(0.5, 1) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime(  0.4 * Radius / 4 )
			Smoke:SetStartAlpha( 40 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 5 * Radius )
			Smoke:SetEndSize( 35 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 150 )
			Smoke:SetCollide( true )
			Smoke:SetGravity(Vector(0, 0, 400))
			local SMKColor = math.random( 0 , 20 )
			Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
		end
	end
	]]--
	PMul       = 1
	Radius     = (1-Ground.Fraction) * self.Radius * 0.75
	Density    = Radius * 12
	Angle      = self.HitNormal:Angle()

	for _ = 0, Density * PMul do

		Angle:RotateAroundAxis(Angle:Forward(), 360 / Density)
		local ShootVector = Angle:Up()
		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), Ground.HitPos + self.HitNormal * (5 + Radius * 5) )

		if Smoke then
			Smoke:SetVelocity( ShootVector * 220 * Radius * math.Rand(0.5, 1) )
			Smoke:SetLifeTime( 0 )
			Smoke:SetDieTime(  1.1 * Radius / 4 )
			Smoke:SetStartAlpha( 35 )
			Smoke:SetEndAlpha( 0 )
			Smoke:SetStartSize( 5 * Radius )
			Smoke:SetEndSize( 55 * Radius )
			Smoke:SetRoll( math.Rand(0, 360) )
			Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
			Smoke:SetAirResistance( 150 )
			Smoke:SetCollide( true )
			Smoke:SetGravity(Vector(0, 0, 0))
			local SMKColor = math.random( 0 , 15 )
			Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
		end
	end


	DebugEffect("ace_scaled_detonation Shockwave:Exit")
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
		DebugEffect("ace_scaled_detonation Water:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation Water:Enter")

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
	DebugEffect("ace_scaled_detonation Water:Exit")
end

function EFFECT:Concrete( SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation Concrete:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation Concrete:Enter")

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
	DebugEffect("ace_scaled_detonation Concrete:Exit")
end

function EFFECT:Dirt( SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation Dirt:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation Dirt:Enter")

	local ScaleMul = 1

		if self.Radius < 10 then
			ScaleMul = 1.5
		elseif self.Radius < 20 then
			ScaleMul = 0.5
		end

	for _ = 0, 9 * self.Radius do

		Texture = "effects/fleck_cement1"

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


	Texture = "particles/smokey"

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


	DebugEffect("ace_scaled_detonation Dirt:Exit")
end

function EFFECT:Sand( SmokeColor )

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation Sand:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation Sand:Enter")

	for _ = 0, 6 * self.Radius do

		NumRand = math.random(-1, 2)
		TScale = 1
		Texture = "particle/smokesprites_000" .. math.random(1,9)

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
	DebugEffect("ace_scaled_detonation Sand:Exit")
end

function EFFECT:Airburst()

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation Airburst:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation Airburst:Enter")

	local Radius = self.Radius
	for _ = 0, 0.5 * Radius do --Flying Debris

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
	DebugEffect("ace_scaled_detonation Airburst:Exit")
end

function EFFECT:DelayedSmoke( color )

	if not self.Emitter then
		DebugEffect("ace_scaled_detonation DelayedSmoke:NoEmitter")
		return
	end
	DebugEffect("ace_scaled_detonation DelayedSmoke:Enter")
	color = color or RandomSmokeColor()
	local radius = math.max( self.Radius * 0.8, 1.5 )
	local plumeOrigin = ExplosionFlashOrigin( self, radius, -8 )
	local steps = {0.9}

	for i, delayBase in ipairs( steps ) do
		local Smoke = self.Emitter:Add( "particle/smokesprites_000" .. math.random(1,9), plumeOrigin )

		if Smoke then
			local life = math.Rand(2.8, 4.2) * (1 + i * 0.1)
			local sizeSeed = (3.5 + i * 2.8) * radius * SmokeScale * 0.95
			StageParticle( Smoke, delayBase, life )
			Smoke:SetStartAlpha( math.Rand(130, 190) )
			Smoke:SetEndAlpha( math.Rand(60, 90) )
			Smoke:SetStartSize( sizeSeed )
			Smoke:SetEndSize( sizeSeed * math.Rand(1.1, 1.4) )
			local Vel = VectorRand() * ((22 + i * 10) * radius * SmokeScale)
			Vel.z = Vel.z * 0.15
			Smoke:SetVelocity( Vel )
			Smoke:SetRoll(math.Rand(100, 260))
			Smoke:SetRollDelta(math.Rand(-0.3, 0.3))
			Smoke:SetAirResistance(40)
			Smoke:SetGravity(Vector(0, 0, -110 * radius * SmokeScale))
			local colorRand = VectorRand() * 4
			Smoke:SetColor( ClampColor( color.r + colorRand.x ), ClampColor( color.g + colorRand.y ), ClampColor( color.b + colorRand.z ) )
		end
	end
	DebugEffect("ace_scaled_detonation DelayedSmoke:Exit")
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


