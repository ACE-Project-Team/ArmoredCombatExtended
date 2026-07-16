--define the class
ACF_defineGunClass("MG", {
	type = "Gun",
	spread = 0.13,
	name = "Machinegun",
	desc = ACFTranslation.GunClasses[9],
	muzzleflash = "MG",
	rofmod = 0.9,
	year = 1910,
	sound = "ace_weapons/multi_sound/7_62mm_multi.mp3",
	noloader = true,

} )

--add a gun to the class
ACF_defineGun("7.62mmMG", { --id
	name = "7.62mm Machinegun",
	desc = "The 7.62mm is effective against infantry, but its usefulness against armor is laughable at best.",
	model = "models/machinegun/machinegun_762mm.mdl",
	sound = "ace_weapons/multi_sound/7_62mm_multi.mp3",
	gunclass = "MG",
	caliber = 0.762,
	weight = 10,
	year = 1930,
	rofmod = 0.8,
	round = {
		maxlength = 13,
		propweight = 0.04
	},
	acepoints = 50,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("12.7mmMG", {
	name = "12.7mm Machinegun",
	desc = "The 12.7mm MG is still light, finding its way into a lot of mountings, including on top of tanks.",
	model = "models/machinegun/machinegun_127mm.mdl",
	sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
	gunclass = "MG",
	caliber = 1.27,
	weight = 20,
	year = 1910,
	rofmod = 0.47,
	round = {
		maxlength = 24,
		propweight = 0.1
	},
	acepoints = 60,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("14.5mmMG", {
	name = "14.5mm Machinegun",
	desc = "The 14.5mm MG trades its smaller stablemates' rate of fire for more armor penetration and damage.",
	model = "models/machinegun/machinegun_145mm.mdl",
	sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
	gunclass = "MG",
	caliber = 1.45,
	weight = 25,
	year = 1932,
	rofmod = 0.47,
	round = {
		maxlength = 27,
		propweight = 0.04
	},
	acepoints = 80,
	gunnerexception = true --Bypasses regular gunner rules.
} )


ACF_defineGun("20mmMG", {
	name = "20mm Machinegun",
	desc = "The 20mm MG is practically a cannon in its own right; the weight and recoil made it difficult to mount on light land vehicles, though it was adapted for use on both aircraft and ships.",
	model = "models/machinegun/machinegun_20mm.mdl",
	sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
	gunclass = "MG",
	caliber = 2.0,
	weight = 35,
	year = 1935,
	rofmod = 0.32,
	round = {
		maxlength = 32,
		propweight = 0.09
	},
	acepoints = 100,
	gunnerexception = true --Bypasses regular gunner rules.
} )

do
	ACE_DefineMuzzleFlash("MG", {

		muzzlefunc = function( Effect )

			if not Effect.Emitter then return end

			local PMul       = 0.4
			local size    = Effect.Radius * 0.5
			local Offset = Effect.DirVec * size * 0.5
			local SmokeColor = Color( 150, 150, 150, 100 )
			local ParticleCount = math.ceil( math.Clamp( size , 6, 150 ) * PMul )

			local DustSpeed = 1
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

				if Dust then
					Dust:SetVelocity(Effect.DirVec * DustSpeed * size * 50)
					DustSpeed = DustSpeed + 6 * (i / ParticleCount)
					Dust:SetLifeTime(0)
					Dust:SetDieTime(0.35 * (size / 4))
					Dust:SetStartAlpha(50)
					Dust:SetEndAlpha(0)
					Dust:SetStartSize(1 * size * (i / ParticleCount))
					Dust:SetEndSize(30 * size * (i / ParticleCount))
					Dust:SetRoll(math.Rand(150, 360))
					Dust:SetRollDelta(math.Rand(-0.2, 0.2))
					Dust:SetAirResistance(600)
					Dust:SetGravity(Vector(0, 0, -175))
					Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
				end
			end


			local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 10)
				DustSpeed = DustSpeed + 6
				Dust:SetLifeTime(0)
				Dust:SetDieTime(6 * (size / 4))
				Dust:SetStartAlpha(50)
				Dust:SetEndAlpha(5)
				Dust:SetStartSize(0)
				Dust:SetEndSize(55 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance(50)
				Dust:SetGravity(Vector(0, 0, -10))
				Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
			end

			size = size / 1.75

			local ParticleCount = math.ceil( math.Clamp( size * 3, 5, 600 ) * PMul )


			for _ = 1, ParticleCount do
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset)

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity + (Effect.DirAng:Right() * math.Rand (-1,1) + Effect.DirAng:Up() * math.Rand (-1,1)):GetNormalized() * 20 * size)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(1.0 * size)
				Dust:SetEndSize(3 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			end

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 15 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(4 * size)
				Dust:SetEndSize(10 * size)
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
				Dust:SetStartSize(2 * size)
				Dust:SetEndSize(12 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 2
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 40 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(0)
				Dust:SetEndSize(3 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end
			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 40 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(8 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

			--Fire 3
			local Dust = Effect.Emitter:Add("effects/fire_cloud" .. math.random(1,2), Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 50 + Effect.GunVelocity)
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

			local Dust = Effect.Emitter:Add("sprites/orangeflare1", Effect.Origin  )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 40 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(150)
				Dust:SetEndAlpha(150)
				Dust:SetStartSize(5  * size)
				Dust:SetEndSize(12 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
				Dust:SetColor( 255, 0, 0 )
			end

			local Dust = Effect.Emitter:Add("effects/ar2_altfire1b", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * 50 + Effect.GunVelocity)
				Dust:SetLifeTime(0)
				Dust:SetDieTime(0.2)
				Dust:SetStartAlpha(255)
				Dust:SetEndAlpha(255)
				Dust:SetStartSize(0)
				Dust:SetEndSize(10 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance( 0 )
				Dust:SetGravity(Vector(0, 0, 0))
				Dust:SetLighting( false )
			end

		end,
	})
end
