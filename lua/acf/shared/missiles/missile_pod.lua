
--define the class
ACE.DefineGunClass("FFAR", {
	type			= "missile",
	spread		= 1,
	name			= "[FFAR] - Folding-Fin Aerial Rockets",
	desc			= ACFTranslation.MissileClasses[7],
	muzzleflash	= "40mm_muzzleflash_noscale",
	rofmod		= 1,
	year = 1960,
	sound		= "acf_extra/airfx/rocket_fire2.wav",
	soundDistance	= " ",
	soundNormal	= " ",
	effect		= "Rocket Motor FFAR"
} )




ACE.DefineGun("40mmFFAR", { --id

	name		= "40mm Pod Rocket",
	desc		= "A tiny, unguided rocket.  Useful for anti-infantry, smoke and suppression.  Folding fins allow the rocket to be stored in pods, which defend them from damage.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nMax Kinetic Pen: 122 mm",
	model	= "models/missiles/launcher7_40mm.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	= "ACE_MissileTiny",
	caliber	= 4,
	gunclass	= "FFAR",
	rack		= "40mm7xPOD",  -- Which rack to spawn this missile on?
	weight	= 6,
	length	= 65, -- Length affects inertia calculations
	rofmod	= 0.1,
	year		= 1960,
	modeldiameter	= 1.6,--Already in ammocrate units
	round	=
	{
		rocketmdl				= "models/missiles/ffar_40mm.mdl",
		rackmdl				= "models/missiles/ffar_40mm_closed.mdl",
		firedelay			= 0.075,
		reloadspeed			= 0.2,
		reloaddelay			= 15.0,
		inaccuracy			= 1.5,

		maxlength			= 60,							-- Length of missile. Used for ammo properties.
		propweight			= 0.2,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 20,							-- Armour effectiveness of casing, in mm

		turnrate			= 15,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 200,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.003,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul	= math.sqrt(0.5),

		waterthrusttype = 0, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
	},

	ent		= "acf_missile_to_rack", -- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb"},
	fuses	= {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {["40mm7xPOD"] = true},	-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	armdelay	= 0.15	-- minimum fuse arming delay
} )




ACE.DefineGun("70mmFFAR", { --id

	name		= "70mm Pod Rocket",
	desc		= "A small, optionally guided rocket.  Useful against light vehicles and infantry.  Folding fins allow the rocket to be stored in pods, which defend them from damage.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nMax Kinetic Pen: 284 mm",
	model	= "models/missiles/launcher7_70mm.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	= "ACE_MissileTiny",
	caliber	= 7,
	gunclass	= "FFAR",
	rack		= "70mm7xPOD",  -- Which rack to spawn this missile on?
	weight	= 12,
	length	= 45.5 * 2.53, --Convert to ammocrate units
	year		= 1960,
	roundclass  = "Rocket",
	modeldiameter	= 2.9,
	round	=
	{

		rocketmdl				= "models/missiles/ffar_70mm.mdl",
		rackmdl				= "models/missiles/ffar_70mm_closed.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 20.0,
		inaccuracy			= 2,

		maxlength			= 90,							-- Length of missile. Used for ammo properties.
		propweight			= 0.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 15,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 160,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul	= math.sqrt(0.65),	-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 4,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.

		waterthrusttype = 0, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
	},

	ent		= "acf_missile_to_rack", -- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb"},
	fuses	= {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {["70mm7xPOD"] = true},	-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	seekcone	= 30,	-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone	= 30,	-- getting outside this cone will break the lock.  Divided by 2.
	seeksensitivity = 0.5, --Less sophisticated seeker is better at close range

	armdelay	= 0.15	-- minimum fuse arming delay
} )

ACE.DefineGun("S8KO", { --id

	name        = "S-8KO Unguided Rockets",
	desc        = "The S-8 is a rocket weapon developed by the Soviet Air Force for use by military aircraft. It remains in service with the Russian Aerospace Forces and various export customers.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nMax Kinetic Pen: 194 mm",
	model       = "models/missiles/arend/s-8ko.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	= "ACE_MissileTiny",
	caliber	= 8,
	gunclass	= "FFAR",
	rack		= "20x S8KO",  -- Which rack to spawn this missile on?
	weight	= 12,
	length	= 60.5 * 2.53, --Convert to ammocrate units
	year		= 1960,
	roundclass  = "Rocket",
	modeldiameter	= 3.3,--Already in ammocrate units
	round	=
	{

		rocketmdl			= "models/missiles/arend/s-8ko.mdl",
		rackmdl				= "models/missiles/arend/s-8ko.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.1,
		reloaddelay			= 20.0,
		inaccuracy			= 2,

		maxlength			= 90,							-- Length of missile. Used for ammo properties.
		propweight			= 0.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 300,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.35,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.001,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul	= math.sqrt(0.65),	-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack",
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},
	racks      = {["20x S8KO"] = true},

	seekcone	= 30,	-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone	= 30,	-- getting outside this cone will break the lock.  Divided by 2.
	seeksensitivity = 0.5, --Less sophisticated seeker is better at close range

	ghosttime  = 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay   = 0.15

} )

ACE.DefineGun("Zuni ASR", { --id
	name             = "Zuni Rocket",
	desc             = "A heavy 5in air to surface unguided rocket, able to provide heavy suppressive fire in a single pass.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nMax Kinetic Pen: 388 mm",
	model            = "models/ghosteh/zuni.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	= "ACE_MissileSmall",
	caliber          = 12.7,
	gunclass         = "FFAR",
	rack             = "127mm4xPOD",
	weight           = 36.1,
	length           = 298,
	year             = 1957,
	roundclass       = "Rocket",
	modeldiameter    = 5.26,
	bodydiameter     = 6.7, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)


	round	=
	{
		rocketmdl			= "models/ghosteh/zuni.mdl",
		rackmdl				= "models/ghosteh/zuni_folded.mdl",
		firedelay			= 0.25,
		reloadspeed			= 0.3,
		reloaddelay			= 45.0,
		inaccuracy			= 0.1,

		maxlength			= 70,							-- Length of missile. Used for ammo properties.
		propweight			= 0.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 7,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 180,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.8,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0025,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul	= math.sqrt(0.825),	-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 0.4,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.

	},
	ent        = "acf_missile_to_rack",
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude", "Radio"},
	racks      = {["127mm4xPOD"] = true},

	viewcone	= 30,	-- getting outside this cone will break the lock.  Divided by 2.

	ghosttime  = 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay   = 0.15

})