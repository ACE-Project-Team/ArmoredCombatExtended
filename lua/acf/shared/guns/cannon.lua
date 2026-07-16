--define the class
ACF_defineGunClass("C", {
	type = "Gun",
	spread = 0.1,
	name = "Cannon",
	desc = ACFTranslation.GunClasses[4],
	muzzleflash = "C",
	rofmod = 1.5,
	maxrof = 19, -- maximum rounds per minute
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",

} )

--add a gun to the class
ACF_defineGun("37mmC", { --id
	name = "37mm Cannon",
	desc = "A light and fairly weak cannon with good accuracy.",
	model = "models/tankgun/tankgun_37mm.mdl",
	sound = "ace_weapons/multi_sound/50mm_multi.mp3",
	gunclass = "C",
	caliber = 3.7,
	weight = 95,
	year = 1919,
	rofmod = 1.4,
	maxrof = 42, -- maximum rounds per minute
	round = {
		maxlength = 48,
		propweight = 1.125
	},
	acepoints = 600
} )

ACF_defineGun("50mmC", {
	name = "50mm Cannon",
	desc = "The 50mm is surprisingly fast-firing, with good effectiveness against light armor, but a pea-shooter compared to its bigger cousins",
	model = "models/tankgun/tankgun_50mm.mdl",
	sound = "ace_weapons/multi_sound/50mm_multi.mp3",
	gunclass = "C",
	caliber = 5.0,
	weight = 380,
	year = 1935,
	maxrof = 32, -- maximum rounds per minute
	round = {
		maxlength = 63,
		propweight = 2.1
	},
	acepoints = 800
} )

ACF_defineGun("75mmC", {
	name = "75mm Cannon",
	desc = "The 75mm is still rather respectable in rate of fire, but has only modest payload.  Often found on the Eastern Front, and on cold war light tanks.",
	model = "models/tankgun/tankgun_75mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	gunclass = "C",
	caliber = 7.5,
	weight = 660,
	year = 1942,
	maxrof = 25, -- maximum rounds per minute
	round = {
		maxlength = 78,
		propweight = 3.8
	},
	acepoints = 1100
} )

ACF_defineGun("85mmC", {
	name = "85mm Cannon",
	desc = "Slightly better than 75, however may introduce problems to tanks, whose armor could stop 75mm. T-34-85 gun.",
	model = "models/tankgun/tankgun_85mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	gunclass = "C",
	caliber = 8.5,
	weight = 1030,
	year = 1944,
	maxrof = 23.5, -- maximum rounds per minute
	round = {
		maxlength = 85.5,
		propweight = 6.65
	},
	acepoints = 1200
} )

ACF_defineGun("100mmC", {
	name = "100mm Cannon",
	desc = "The 100mm was a benchmark for the early cold war period, and has great muzzle velocity and hitting power, while still boasting a respectable, if small, payload.",
	model = "models/tankgun/tankgun_100mm.mdl",
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",
	gunclass = "C",
	caliber = 10.0,
	weight = 1400,
	year = 1944,
	maxrof = 22, -- maximum rounds per minute
	round = {
		maxlength = 93,
		propweight = 9.5
	},
	acepoints = 1400
} )

ACF_defineGun("120mmC", {
	name = "120mm Cannon",
	desc = "Often found in MBTs, the 120mm shreds lighter armor with utter impunity, and is formidable against even the big boys.",
	model = "models/tankgun/tankgun_120mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "C",
	caliber = 12.0,
	weight = 2100,
	year = 1955,
	maxrof = 20, -- maximum rounds per minute
	round = {
		maxlength = 110,
		propweight = 18
	},
	acepoints = 1700
} )

ACF_defineGun("140mmC", {
	name = "140mm Cannon",
	desc = "The 140mm fires a massive shell with enormous penetrative capability, but has a glacial reload speed and a very hefty weight.",
	model = "models/tankgun/tankgun_140mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "C",
	caliber = 14.0,
	weight = 3900,
	year = 1990,
	maxrof = 12, -- maximum rounds per minute
	round = {
		maxlength = 127,
		propweight = 28
	},
	acepoints = 1825
} )

ACF_defineGun("170mmC", {
	name = "170mm Cannon",
	desc = "The 170mm fires a gigantic shell with ginormous penetrative capability, but has a glacial reload speed and an extremely hefty weight.",
	model = "models/tankgun/tankgun_170mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "C",
	caliber = 17.0,
	weight = 7800,
	year = 1990,
	maxrof = 6.5, -- maximum rounds per minute
	round = {
		maxlength = 154,
		propweight = 34
	},
	acepoints = 2400
} )

do
	ACE_DefineMuzzleFlash("C", {

		muzzlefunc = function( Effect )
			if not Effect.Emitter then return end

			local PMul       = 1
			local size    = Effect.Radius * 0.5
			local SmokeColor = Color( 175, 175, 175, 100 )

			local Offset = Effect.DirVec * size * -12
			size = size * 0.625

			--[[

			local Angle      = Effect.DirVec:Angle()

			for _ = 0, 1.5 * size * 4 * PMul do

				Angle:RotateAroundAxis(Angle:Forward(), 360 / size * 1.5 * 2 * math.Rand(0.9, 1.0))
				local ShootVector = Angle:Right()
				local Smoke = Effect.Emitter:Add( "particles/smokey", Effect.Origin + Offset )

				if Smoke then
					Smoke:SetVelocity( ShootVector * 800 * math.Rand(0.4, 1.0) * size + Effect.DirVec * -850 * size * math.Rand(-1, 1.0) + Effect.GunVelocity * 1.5 )
					Smoke:SetLifeTime( 0 )
					Smoke:SetDieTime(  3 * size / 4 )
					Smoke:SetStartAlpha( 40 )
					Smoke:SetEndAlpha( 0 )
					Smoke:SetStartSize( 35 * size )
					Smoke:SetEndSize( 18 * size )
					Smoke:SetRoll( math.Rand(0, 360) )
					Smoke:SetAirResistance( 650 )
					Smoke:SetGravity(Vector(0, 0, 0))
					local SMKColor = math.random( 0 , 20 )
					Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
				end
			end
			]]--

			size = size * 1.6

			local ParticleCount = math.ceil( math.Clamp( size , 6, 150 ) * PMul )

			local DustSpeed = 1
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

				if Dust then
					Dust:SetVelocity(Effect.DirVec * DustSpeed * size * 35 + Effect.GunVelocity * 1.5)
					DustSpeed = DustSpeed + 6 * (i / ParticleCount)
					Dust:SetLifeTime(0)
					Dust:SetDieTime(3 * (size / 4))
					Dust:SetStartAlpha(110)
					Dust:SetEndAlpha(0)
					Dust:SetStartSize(15 * size * (i / ParticleCount))
					Dust:SetEndSize(80 * size * (i / ParticleCount))
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.2, 0.2))
					Dust:SetAirResistance(600)
					Dust:SetGravity(Vector(0, 0, -175))
					Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
				end
			end

			--[[
			local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * -5 + Effect.GunVelocity * 1.5)
				DustSpeed = DustSpeed + (6)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(6 * (size / 4))
				Dust:SetStartAlpha(75)
				Dust:SetEndAlpha(5)
				Dust:SetStartSize(0)
				Dust:SetEndSize(125 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance(400)
				Dust:SetGravity(Vector(0, 0, -150))
				Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
			end
			]]--

			--Old cannon smoke. It shot out too far and was way too smokey.
			--[[
			local ParticleCount = math.ceil( math.Clamp( size * 2 , 6, 300 ) * PMul )

			local DustSpeed = 4
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

				if Dust then
					Dust:SetVelocity((Effect.DirVec+ VectorRand()*0.2):GetNormalized() * DustSpeed * size * 60 + Effect.GunVelocity * 1.5)
					DustSpeed = DustSpeed + (6) * (i/ParticleCount)
					Dust:SetLifeTime(-0.15)
					Dust:SetDieTime(6 * (size / 4))
					Dust:SetStartAlpha(75)
					Dust:SetEndAlpha(5)
					Dust:SetStartSize(25 * size * (i/ParticleCount))
					Dust:SetEndSize(350 * size * (i/ParticleCount))
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.5, 0.5))
					Dust:SetAirResistance(900)
					Dust:SetGravity(Vector(0, 0, -250))
					Dust:SetCollide( true )
					Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
				end
			end
			]]--

			local ParticleCount = math.ceil( math.Clamp( size * 2, 5, 600 ) * PMul )


			for _ = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("effects/spark", Effect.Origin + Offset )

				if Dust then
					Dust:SetVelocity((Effect.DirVec + VectorRand() * 0.5) * 200 * size)
					local Lifetime = math.Rand(0.5, 1.0)
					Dust:SetLifeTime(-0.0)
					Dust:SetDieTime(Lifetime)
					Dust:SetStartAlpha(100)
					Dust:SetEndAlpha(20)
					local size = math.Rand(1, 3) * 2
					Dust:SetStartSize(size * size)
					Dust:SetEndSize(size * 0.5 * size)
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.2, 0.2))
					Dust:SetGravity(Vector(0, 0, -640))
					Dust:SetLighting( false )
					Dust:SetCollide( true )
					Dust:SetBounce( 0.4 )
					Dust:SetAirResistance(5)
					local ColorRandom = VectorRand() * 15
					Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
					local Length = math.Rand(15, 65) * 3
					Dust:SetStartLength( Length )
					Dust:SetEndLength( Length * 0.25 ) --Length
				end
			end

			size = size * 2.5


			--Fire 1
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 40 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(0)
				Dust:SetEndSize(4 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 40 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(7 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 2
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 55 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(0)
				Dust:SetEndSize(8 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 55 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(12 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 3

			local ParticleCount = math.ceil( math.Clamp( size * 1, 5, 600 ) * PMul )


			for _ = 1, ParticleCount do
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset)

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 70 + Effect.GunVelocity + (Effect.DirAng:Right() * math.Rand (-1,1) + Effect.DirAng:Up() * math.Rand (-1,1)):GetNormalized() * 15 * size)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(1.0 * size)
				Dust:SetEndSize(5 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			end

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 70 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(4 * size)
				Dust:SetEndSize(20 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				Dust:SetColor( 255, 0, 0 )
			end


			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 70 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(100)
				Dust:SetEndAlpha(15)
				Dust:SetStartSize(2 * size)
				Dust:SetEndSize(7 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 3
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1, 2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 85 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(0)
				Dust:SetEndSize(10 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 85 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(5  * size)
				Dust:SetEndSize(50 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				Dust:SetColor( 255, 0, 0 )
			end

			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 90 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(13 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			local Dust = Effect.Emitter:Add("effects/fire_cloud2", Effect.Origin )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 5 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0.1 * size)
				Dust:SetEndSize(4 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				local Length = 3 * size
				Dust:SetStartLength( Length )
				Dust:SetEndLength( Length * 3 )
			end

			local Dust = Effect.Emitter:Add("effects/fire_cloud2", Effect.Origin )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0.1 * size)
				Dust:SetEndSize(10 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				local Length = 3 * size
				Dust:SetStartLength( Length )
				Dust:SetEndLength( Length * 3 )
			end

			local Dust = Effect.Emitter:Add("particles/flamelet" .. math.random(1,5), Effect.Origin )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 160 + Effect.GunVelocity)
				Dust:SetLifeTime(-0.05)
				Dust:SetDieTime(0.3)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(0)
				Dust:SetStartSize(0.1 * size)
				Dust:SetEndSize(25 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetAirResistance( 200 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				local Length = 15 * size
				Dust:SetStartLength( Length * 0.1 )
				Dust:SetEndLength( Length * 1 )
			end

			local ParticleCount = math.ceil( math.Clamp( size , 6, 300 ) * PMul )


			local DustSpeed = 10
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("effects/fire_cloud2", Effect.Origin  + Offset )

				if Dust then
					Dust:SetVelocity(Effect.DirVec * DustSpeed * size * 10 + Effect.GunVelocity * 1.5)
					DustSpeed = DustSpeed + 3.5 * (i / ParticleCount)
					Dust:SetLifeTime(-0.125)
					Dust:SetDieTime(0.35)
					Dust:SetStartAlpha(50)
					Dust:SetEndAlpha(0)
					Dust:SetStartSize(-1)
					Dust:SetEndSize(11.5 * size * (i / ParticleCount))
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.5, 0.5))
					Dust:SetAirResistance(600)
					Dust:SetCollide( true )
				end
			end

		end,
	})

	ACE_DefineMuzzleFlash("Default", {

		muzzlefunc = function( Effect )
			if not Effect.Emitter then return end

			local PMul   = 1
			local size   = Effect.Radius * 0.5
			local Offset = Effect.DirVec * size * -2.5
			local Angle  = Effect.DirVec:Angle()
			local SmokeColor = Color( 150, 150, 150, 100 )

			for _ = 0, 1.5 * size * 4 * PMul do

				Angle:RotateAroundAxis(Angle:Forward(), 360 / size * 1.5 * 2 * math.Rand(0.9, 1.0))
				local ShootVector = Angle:Right()
				local Smoke = Effect.Emitter:Add( "particles/smokey", Effect.Origin + Offset )

				if Smoke then
					Smoke:SetVelocity( ShootVector * 800 * math.Rand(0.4, 1.0) * size + Effect.DirVec * -150 * size * math.Rand(0.8, 1.0) + Effect.GunVelocity * 1.5 )
					Smoke:SetLifeTime( 0 )
					Smoke:SetDieTime(  1.5 * size / 4 )
					Smoke:SetStartAlpha( 65 )
					Smoke:SetEndAlpha( 0 )
					Smoke:SetStartSize( 25 * size )
					Smoke:SetEndSize( 18 * size )
					Smoke:SetRoll( math.Rand(0, 360) )
					Smoke:SetAirResistance( 650 )
					Smoke:SetGravity(Vector(0, 0, 0))
					local SMKColor = math.random( 0 , 20 )
					Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
				end
			end


			local ParticleCount = math.ceil( math.Clamp( size * 2 , 6, 150 ) * PMul )

			local DustSpeed = 4
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

				if Dust then
					Dust:SetVelocity(Effect.DirVec * DustSpeed * size * 50 + Effect.GunVelocity * 1.5)
					DustSpeed = DustSpeed + 6 * (i / ParticleCount)
					Dust:SetLifeTime(0)
					Dust:SetDieTime(1.5 * (size / 4))
					Dust:SetStartAlpha(75)
					Dust:SetEndAlpha(5)
					Dust:SetStartSize(20 * size * (i / ParticleCount))
					Dust:SetEndSize(75 * size * (i / ParticleCount))
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.2, 0.2))
					Dust:SetAirResistance(400)
					Dust:SetGravity(Vector(0, 0, -150))
					Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
				end
			end

			local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity * 1.5)
				DustSpeed = DustSpeed + 6
				Dust:SetLifeTime(0)
				Dust:SetDieTime(1.5 * (size / 4))
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(5)
				Dust:SetStartSize(20 * size)
				Dust:SetEndSize(100 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance(400)
				Dust:SetGravity(Vector(0, 0, -150))
				Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
			end

			local ParticleCount = math.ceil( math.Clamp( size, 5, 600 ) * PMul )


			for _ = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("effects/spark", Effect.Origin + Offset )

				if Dust then
					Dust:SetVelocity((Effect.DirVec + VectorRand() * 0.7) * 200 * size)
					local Lifetime = math.Rand(0.35, 0.4)
					Dust:SetLifeTime(-0.05)
					Dust:SetDieTime(Lifetime)
					Dust:SetStartAlpha(100)
					Dust:SetEndAlpha(20)
					local size = math.Rand(0.5, 4) * 0.5
					Dust:SetStartSize(size * size)
					Dust:SetEndSize(size * 0.5 * size)
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.2, 0.2))
					Dust:SetGravity(Vector(0, 0, -340))
					Dust:SetLighting( false )
					Dust:SetCollide( true )
					Dust:SetBounce( 0.4 )
					Dust:SetAirResistance(5)
					local ColorRandom = VectorRand() * 15
					Dust:SetColor(240 + ColorRandom.x, 205 + ColorRandom.y, 135 + ColorRandom.z)
					local Length = math.Rand(15, 65) * 0.5
					Dust:SetStartLength( Length )
					Dust:SetEndLength( Length * 0.25 ) --Length
				end
			end

			size    = size * 2

			--[[
			local Dust = Effect.Emitter:Add("effects/muzzleflash".. math.random(1,4), Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 55 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2 * (size / 3))
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(1 * size)
				Dust:SetEndSize(10 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				local Length = 25 * size
		--		Dust:SetStartLength( Length )
		--		Dust:SetEndLength( Length*1 )
			end

			]]--

			--[[
			local Dust = Effect.Emitter:Add("effects/muzzleflash".. math.random(1,4), Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.15 * (size / 3))
				Dust:SetStartAlpha(200)
				Dust:SetEndAlpha(15)
				Dust:SetStartSize(1 * size)
				Dust:SetEndSize(10 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			]]--

			--sprites/orangeflare1
			local Dust = Effect.Emitter:Add("effects/yellowflare", Effect.Origin + Offset  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(100)
				Dust:SetEndAlpha(0)
				Dust:SetStartSize(6 * size)
				Dust:SetEndSize(6 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(3 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(2 * size)
				Dust:SetEndSize(6 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				Dust:SetColor( 255, 0, 0 )
			end

			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(100)
				Dust:SetEndAlpha(15)
				Dust:SetStartSize(0)
				Dust:SetEndSize(6 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 2
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 28 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(0)
				Dust:SetEndSize(2 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			--[[
			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 28 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(1.5  * size)
				Dust:SetEndSize(5 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			]]--
			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 28 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(6 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 3
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 42 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(0)
				Dust:SetEndSize(4 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 42 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(2.5 * size)
				Dust:SetEndSize(13 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				Dust:SetColor( 255, 0, 0 )
			end

			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 42 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(8.5 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

		end,
	})


end
