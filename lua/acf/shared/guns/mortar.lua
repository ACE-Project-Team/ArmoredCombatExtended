--define the class
ACF_defineGunClass("MO", {
	type = "Gun",
	spread = 0.5,
	name = "Mortar",
	desc = ACFTranslation.GunClasses[10],
	muzzleflash = "MO",
	rofmod = 2,
	maxrof = 35, -- maximum rounds per minute
	year = 1915,
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",

} )

ACF_defineGun("50mmM", { --id
	name = "50mm Mortar",
	desc = "The 50mm is an uncommon light mortar often seen at or before the beginning of ww2, it fires a light 50mm rounds that is good for splatting infantry.",
	model = "models/mortar/mortar_50mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "MO",
	caliber = 5.0,
	weight = 40,
	rofmod = 1.05,
	maxrof = 50, -- maximum rounds per minute
	year = 1930,
	round = {
		maxlength = 80,
		propweight = 0.1
	},
	acepoints = 60,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("60mmM", { --id
	name = "60mm Mortar",
	desc = "The 60mm is a common light infantry support weapon, with a high rate of fire but a puny payload.",
	model = "models/mortar/mortar_60mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "MO",
	caliber = 6.0,
	weight = 80,
	rofmod = 0.95,
	maxrof = 35, -- maximum rounds per minute
	year = 1930,
	round = {
		maxlength = 105,
		propweight = 0.2
	},
	acepoints = 100,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("80mmM", {
	name = "80mm Mortar",
	desc = "The 80mm is a common infantry support weapon, with a good bit more boom than its little cousin.",
	model = "models/mortar/mortar_80mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "MO",
	caliber = 8.0,
	weight = 210,
	rofmod = 0.7,
	maxrof = 27, -- maximum rounds per minute
	year = 1915,
	round = {
		maxlength = 160,
		propweight = 0.4
	},
	acepoints = 170,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("120mmM", {
	name = "120mm Mortar",
	desc = "The versatile 120 is sometimes vehicle-mounted to provide quick boomsplat to support the infantry.  Carries more boom in its boomsplat, has good HEAT performance, and is more accurate in high-angle firing.",
	model = "models/mortar/mortar_120mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "MO",
	caliber = 12.0,
	weight = 440,
	rofmod = 0.6,
	maxrof = 16, -- maximum rounds per minute
	year = 1935,
	round = {
		maxlength = 180,
		propweight = 0.9
	},
	acepoints = 450
} )

ACF_defineGun("150mmM", {
	name = "150mm Mortar",
	desc = "The perfect balance between the 120mm and the 200mm. Can prove a worthy main gun weapon, as well as a mighty good mortar emplacement",
	model = "models/mortar/mortar_150mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "MO",
	caliber = 15.0,
	weight = 680,
	rofmod = 0.55,
	maxrof = 9, -- maximum rounds per minute
	year = 1945,
	round = {
		maxlength = 165,
		propweight = 1
	},
	acepoints = 550
} )

ACF_defineGun("200mmM", {
	name = "200mm Mortar",
	desc = "The 200mm is a beast, often used against fortifications.  Though enormously powerful, feel free to take a nap while it reloads",
	model = "models/mortar/mortar_200mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "MO",
	caliber = 20.0,
	weight = 980,
	maxrof = 5, -- maximum rounds per minute
	year = 1940,
	round = {
		maxlength = 250,
		propweight = 2
	},
	acepoints = 1000
} )

ACF_defineGun("280mmM", {
	name = "280mm Mortar",
	desc = "Massive payload, with a reload time to match. Found in rare WW2 siege artillery pieces. It's the perfect size for a jeep.",
	model = "models/mortar/mortar_280mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "MO",
	caliber = 28.0,
	weight = 2000,
	maxrof = 2.3, -- maximum rounds per minute
	year = 1945,
	round = {
		maxlength = 500,
		propweight = 9
	},
	acepoints = 1500
} )

ACF_defineGun("380mmM", {
	name = "380mm Mortar",
	desc = "Massive payload, with a reload time to match. Found in rare WW2 siege artillery pieces.", --Coastal artillery, Rail artillery, and battleship guns
	model = "models/mortar/mortar_300mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "MO",
	caliber = 38.0,
	weight = 5000,
	maxrof = 2, -- maximum rounds per minute
	year = 1941,
	round = {
		maxlength = 635,
		propweight = 15
	},
	acepoints = 2800
} )

do
	ACE_DefineMuzzleFlash("MO", {

		muzzlefunc = function( Effect )
			if not Effect.Emitter then return end

			local PMul       = 1
			local size    = Effect.Radius * 0.25
			local Offset = Effect.DirVec * size * 0.5
			local SmokeColor = Color( 150, 150, 150, 100 )

			local ParticleCount = math.ceil( math.Clamp( size , 6, 150 ) * PMul )

			local DustSpeed = 1
			for i = 1, ParticleCount do
				local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

				if Dust then
					Dust:SetVelocity(Effect.DirVec * DustSpeed * size * 35)
					DustSpeed = DustSpeed + 6 * (i / ParticleCount)
					Dust:SetLifeTime(0)
					Dust:SetDieTime(3 * (size / 4))
					Dust:SetStartAlpha(50)
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


			local Dust = Effect.Emitter:Add("particles/smokey", Effect.Origin  + Offset )

			if Dust then
				Dust:SetVelocity(Effect.DirVec * size * -5)
				DustSpeed = DustSpeed + 6
				Dust:SetLifeTime(0)
				Dust:SetDieTime(6 * (size / 4))
				Dust:SetStartAlpha(50)
				Dust:SetEndAlpha(5)
				Dust:SetStartSize(0)
				Dust:SetEndSize(125 * size)
				Dust:SetRoll(math.Rand(150, 360))
				Dust:SetRollDelta(math.Rand(-0.2, 0.2))
				Dust:SetAirResistance(400)
				Dust:SetGravity(Vector(0, 0, -150))
				Dust:SetColor(SmokeColor.r, SmokeColor.g, SmokeColor.b)
			end

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