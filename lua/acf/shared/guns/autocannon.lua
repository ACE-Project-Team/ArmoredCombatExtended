

do
	--define the class
	ACF_defineGunClass("AC", {
		type = "Gun",
		spread = 0.15,
		name = "Autocannon",
		desc = ACFTranslation.GunClasses[2],
		muzzleflash = "AC",
		rofmod = 0.35,
		year = 1930,
		sound = "ace_weapons/multi_sound/30mm_multi.mp3",
		noloader = true,
	} )

	--add a gun to the class
	ACF_defineGun("20mmAC", { --id
		name = "20mm Autocannon",
		desc = "The 20mm AC is the smallest of the family; having a good rate of fire but a tiny shell.",
		model = "models/autocannon/autocannon_20mm.mdl",
		sound = "ace_weapons/multi_sound/20mm_multi.mp3",
		caliber = 2.0,
		gunclass = "AC",
		nomag = true,
		weight = 170,
		year = 1930,
		rofmod = 0.5,
		round = {
			maxlength = 32,
			propweight = 0.13
		},
		acepoints = 300
	} )

	ACF_defineGun("30mmAC", {
		name = "30mm Autocannon",
		desc = "The 30mm AC can fire shells with sufficient space for a small payload, and has modest anti-armor capability",
		model = "models/autocannon/autocannon_30mm.mdl",
		sound = "ace_weapons/multi_sound/30mm_multi.mp3",
		gunclass = "AC",
		nomag = true,
		caliber = 3.01,
		weight = 255,
		year = 1935,
		rofmod = 0.5,
		round = {
			maxlength = 39,
			propweight = 0.350
		},
		acepoints = 425
	} )

	ACF_defineGun("40mmAC", {
		name = "40mm Autocannon",
		desc = "The 40mm AC can fire shells with sufficient space for a useful payload, and can get decent penetration with proper rounds.",
		model = "models/autocannon/autocannon_40mm.mdl",
		sound = "ace_weapons/multi_sound/40mm_multi.mp3",
		gunclass = "AC",
		nomag = true,
		caliber = 4.0,
		weight = 425,
		year = 1940,
		rofmod = 0.46,
		round = {
			maxlength = 45,
			propweight = 0.9
		},
		acepoints = 600
	} )

	ACF_defineGun("50mmAC", {
		name = "50mm Autocannon",
		desc = "The 50mm AC fires shells comparable with the 50mm Cannon, making it capable of destroying light armour quite quickly.",
		model = "models/autocannon/autocannon_50mm.mdl",
		sound = "ace_weapons/multi_sound/50mm_multi.mp3",
		gunclass = "AC",
		nomag = true,
		caliber = 5.0,
		weight = 880,
		year = 1965,
		rofmod = 0.45,
		round = {
			maxlength = 52,
			propweight = 1.2
		},
		acepoints = 1200
	} )

	ACF_defineGun("20mmHAC", { --id
		name = "20mm Heavy Autocannon",
		desc = "The 20mm HAC is the smallest heavy autocannon, special watercooling allows this autocannon to continuously fire its nonexistant payload at extreme rates, great for attacking unarmored planes or cutting down forests.",
		model = "models/autocannon/autocannon_20mm_compact.mdl",
		sound = "ace_weapons/multi_sound/20mm_hmg_multi.mp3",
		gunclass = "AC",
		nomag = true,
		caliber = 2.0,
		weight = 320,
		year = 1960,
		rofmod = 0.4,
		round = {
			maxlength = 24,
			propweight = 0.13
		},
		acepoints = 375
	} )

	ACF_defineGun("30mmHAC", {
		name = "30mm Heavy Autocannon",
		desc = "The watercooled 30mm HAC fires decently heavy shells at a rapid rate that are great for chewing through light armor",
		model = "models/autocannon/autocannon_30mm_compact.mdl",
		sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
		gunclass = "AC",
		nomag = true,
		caliber = 3.0,
		weight = 700,
		year = 1935,
		rofmod = 0.27,
		round = {
			maxlength = 28,
			propweight = 0.350
		},
		acepoints = 525
	} )

	ACF_defineGun("40mmHAC", {
		name = "40mm Heavy Autocannon",
		desc = "The watercooled 40mm HAC is a long range grinder created in secrecy by light vehicles with very little patience",
		model = "models/autocannon/autocannon_40mm_compact.mdl",
		sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
		gunclass = "AC",
		nomag = true,
		caliber = 4.0,
		weight = 1400,
		year = 1000,
		rofmod = 0.27,
		round = {
			maxlength = 34,
			propweight = 0.9
		},
		acepoints = 800
	} )
end

do
	ACE_DefineMuzzleFlash("AC", {

		muzzlefunc = function( Effect )
			if not Effect.Emitter then return end

			local PMul   = 0.5
			local size   = Effect.Radius * 0.5
			local Offset = Effect.DirVec * size * -2.5
			local Angle  = Effect.DirVec:Angle()
			local SmokeColor = Color( 175, 175, 175, 100 )

			for _ = 0, 1.5 * size * 4 * PMul do

				Angle:RotateAroundAxis(Angle:Forward(), 360 / size * 1.5 * 2 * math.Rand(0.9, 1.0))
				local ShootVector = Angle:Right()
				local Smoke = Effect.Emitter:Add( "particles/smokey", Effect.Origin + Offset )

				if Smoke then
					Smoke:SetVelocity( ShootVector * 800 * math.Rand(0.4, 1.0) * size + Effect.DirVec * -150 * size * math.Rand(0.8, 1.0) + Effect.GunVelocity * 1.5 )
					Smoke:SetLifeTime( 0 )
					Smoke:SetDieTime(  1.5 * size / 4 )
					Smoke:SetStartAlpha( 20 )
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
					Dust:SetStartAlpha(35)
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
				Dust:SetStartAlpha(50)
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

			local Dust = Effect.Emitter:Add("effects/muzzleflash" .. math.random(1,4), Effect.Origin - Effect.DirVec * size * 10 )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 100 )
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.075)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(1 * size)
				Dust:SetEndSize(14 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				local Length = 25 * size
				Dust:SetStartLength( Length )
				Dust:SetEndLength( Length * 1 )
			end

		end,
	})
end