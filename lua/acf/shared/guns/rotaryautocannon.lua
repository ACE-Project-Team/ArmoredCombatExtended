do
	--define the class
	ACF_defineGunClass("RAC", {
		type = "Gun",
		spread = 0.2,
		name = "Rotary Autocannon",
		desc = ACFTranslation.GunClasses[11],
		muzzleflash = "RAC",
		rofmod = 0.07,
		year = 1962,
		sound = "weapons/acf_gun/mg_fire2.wav",
		noloader = true,

		color = {135, 135, 135}
	} )

	ACF_defineGun("14.5mmRAC", { --id
		name = "14.5mm Rotary Autocannon",
		desc = "A lightweight rotary autocannon, a great support weapon for effortlessly shredding infantry and technicals alike.",
		model = "models/rotarycannon/kw/14_5mmrac.mdl",
		sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
		gunclass = "RAC",
		caliber = 1.45,
		weight = 400,
		year = 1962,
		rofmod = 0.96,
		round = {
			maxlength = 25,
			propweight = 0.06
		},
		acepoints = 200
	} )

	ACF_defineGun("20mmRAC", {
		name = "20mm Rotary Autocannon",
		desc = "The 20mm is able to chew up light armor with decent penetration or put up a big flak screen. Typically mounted on ground attack aircraft, SPAAGs and the ocassional APC.",
		model = "models/rotarycannon/kw/20mmrac.mdl",
		sound = "ace_weapons/multi_sound/20mm_hmg_multi.mp3",
		gunclass = "RAC",
		caliber = 2.0,
		weight = 1220,
		year = 1965,
		rofmod = 0.53,
		round = {
			maxlength = 36,
			propweight = 0.12
		},
		acepoints = 1100
	} )

	ACF_defineGun("30mmRAC", {
		name = "30mm Rotary Autocannon",
		desc = "The 30mm is the bane of ground-attack aircraft, able to tear up light armor without giving one single fuck.  Also seen in the skies above dead T-72s.",
		model = "models/rotarycannon/kw/30mmrac.mdl",
		sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
		gunclass = "RAC",
		caliber = 3.0,
		weight = 1830, --1830 Gau 8 total system weight.
		year = 1975,
		rofmod = 0.29,
		round = {
			maxlength = 45,
			propweight = 0.350
		},
		acepoints = 1500
	} )
end

do
	ACE_DefineMuzzleFlash("RAC", {

		muzzlefunc = function( Effect )
			if not Effect.Emitter then return end

			local PMul    = 1
			local size    = Effect.Radius * 1
			local Angle   = Effect.DirVec:Angle()
			local SmokeColor = Color( 175, 175, 175, 100 )

			local AdjOrigin = Effect.Origin + Effect.DirVec * -1 * size
			for _ = 0, size * PMul / 3 do

				Angle:RotateAroundAxis(Angle:Forward(), 360 / size * 3 * math.Rand(0.8, 1.0))
				local ShootVector = Angle:Right()
				local Smoke = Effect.Emitter:Add( "particles/smokey", AdjOrigin)

				if Smoke then
					Smoke:SetVelocity( ShootVector * 45 * size + Effect.DirVec * 30 * size * math.Rand(0.8, 1.0) + Effect.GunVelocity * 1.5 )
					Smoke:SetLifeTime( 0 )
					Smoke:SetDieTime(  1.75 * size / 4 )
					Smoke:SetStartAlpha( 15 )
					Smoke:SetEndAlpha( 0 )
					Smoke:SetStartSize( 1 * size )
					Smoke:SetEndSize( 15 * size )
					Smoke:SetRoll( math.Rand(0, 360) )
					Smoke:SetRollDelta( math.Rand(-0.2, 0.2) )
					Smoke:SetAirResistance( 250 )
					Smoke:SetGravity(Vector(0, 0, 0))
					local SMKColor = math.random( 0 , 20 )
					Smoke:SetColor( SmokeColor.r + SMKColor, SmokeColor.g + SMKColor, SmokeColor.b + SMKColor )
				end
			end


			local ParticleCount = math.ceil( math.Clamp( size / 3 , 5, 150 ) * PMul )

			AdjOrigin = Effect.Origin + Effect.DirVec * -6 * size

			local DustSpeed = 1
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("particles/smokey", AdjOrigin + Effect.DirVec * size * (-10 + 25 * (i / ParticleCount)) )

				if Dust then
					Dust:SetVelocity(Effect.DirVec * DustSpeed * size * 15 + Effect.GunVelocity * 1.5)
					DustSpeed = DustSpeed + 2 * (i / ParticleCount)
					Dust:SetLifeTime(0)
					Dust:SetDieTime(1 * (size / 3))
					Dust:SetStartAlpha(25 * (i / ParticleCount))
					Dust:SetEndAlpha(0)
					Dust:SetStartSize(1 * size)
					Dust:SetEndSize(8 * (3 + DustSpeed / 7.5) * size * (i / ParticleCount))
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.2, 0.2))
					Dust:SetAirResistance(200)
					Dust:SetGravity(Vector(0, 0, -100))
					Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
				end
			end

			local Dust = Effect.Emitter:Add("effects/muzzleflash" .. math.random(1,4), Effect.Origin - Effect.DirVec * size * 1 )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 100 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.15 * (size / 3))
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0.1 * size)
				Dust:SetEndSize(7 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				--local Length = 25 * size
				--Dust:SetStartLength( Length )
				--Dust:SetEndLength( Length * 1 )
			end

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin - Effect.DirVec * size * 1 )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 80 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.15 * (size / 3))
				Dust:SetStartAlpha(100)
				Dust:SetEndAlpha(100)
				Dust:SetStartSize(0.1 * size)
				Dust:SetEndSize(7 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				--local Length = 25 * size
				--Dust:SetStartLength( Length )
				--Dust:SetEndLength( Length * 1 )
			end

			local Dust = Effect.Emitter:Add("effects/muzzleflash" .. math.random(1,4), Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 35 + Effect.GunVelocity)
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

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.1 * (size / 3))
				Dust:SetStartAlpha(60)
				Dust:SetEndAlpha(0)
				Dust:SetStartSize(2 * size)
				Dust:SetEndSize(3 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				Dust:SetColor( 255, 0, 0 )
			end
			--[[
			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 10 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.1 * (size / 3))
				Dust:SetStartAlpha(100)
				Dust:SetEndAlpha(15)
				Dust:SetStartSize(0)
				Dust:SetEndSize(3 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			]]--
		end,
	})
end



