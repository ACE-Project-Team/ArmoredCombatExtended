
--define the class
ACE.DefineGunClass("UAR", {
	type			= "missile",
	spread		= 0.2,
	name			= "[ASR] - Unguided Aerial Rockets",
	desc			= ACE.Translation.MissileClasses[9],
	muzzleflash	= "40mm_muzzleflash_noscale",
	rofmod		= 0.5,
	year = 1933,
	sound		= "acf_extra/airfx/rocket_fire2.wav",
	soundDistance	= " ",
	soundNormal	= " ",
	effect		= "Rocket Motor Arty"
} )


ACE.DefineGun("SPG-9 ASR", { --id

	name             = "SPG-9 Rocket",
	desc             = "A recoilless rocket launcher similar to an RPG or Grom.  The main charge ignites in the tube, while a rocket accelerates a small antitank grenade to the target, giving it a high initial velocity, smaller launch signature, and flatter trajectory than a conventional round but less accuracy.  A useful alternative to guided missiles, it is also quite capable as lightweight HE-slinging artillery for air-drop and expeditionary forces.",
	model            = "models/munitions/round_100mm_mortar_shot.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	 = "ACE_MissileTiny",
	caliber          = 7.3,
	gunclass         = "UAR",
	rack             = "1x SPG9",  -- Which rack to spawn this missile on?
	weight           = 47,
	length           = 63,
	year             = 1962,
	rofmod           = 0.4,
	roundclass       = "Rocket",
	rotmult          = 1,	-- Adjust this if you see that your missile falls too quickly. 0 to deny falling
	modeldiameter    = 5,

	round	= {
		rocketmdl			= "models/munitions/round_100mm_mortar_shot.mdl",
		rackmdl				= "models/munitions/round_100mm_mortar_shot.mdl",
		firedelay			= 0.25,
		reloadspeed			= 0.3,
		reloaddelay			= 7.0,
		inaccuracy			= 0.01,

		maxlength			= 240,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 15,							-- Armour effectiveness of casing, in mm

		turnrate			= 7,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 150,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 150,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.8,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0015,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul            = math.sqrt(0.2),	-- 215.9 HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)

	},

	ent        = "acf_missile_to_rack", -- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks      = {["1x SPG9"] = true},	-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	ghosttime  = 0.1,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.15	-- minimum fuse arming delay, very short since we have a high muzzle velocity
} )

ACE.DefineGun("RS82 ASR", { --id

	name             = "RS-82 Rocket",
	desc             = "A small, unguided rocket, often used in multiple-launch artillery as well as for attacking pinpoint ground targets.  It has a small amount of propellant, limiting its range, but is compact and light.",
	model            = "models/missiles/rs82.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	 = "ACE_MissileTiny",
	caliber          = 8.2,
	gunclass         = "UAR",
	rack             = "1xRK_small",  -- Which rack to spawn this missile on?
	weight           = 6.8,
	length           = 62,
	year             = 1933,
	rofmod           = 0.07,
	roundclass       = "Rocket",
	rotmult          = 1,	-- Adjust this if you see that your missile falls too quickly. 0 to deny falling
	modeldiameter    = 4,
	bodydiameter     = 4.8, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	= {
		rocketmdl			= "models/missiles/rs82.mdl",
		rackmdl				= "models/missiles/rs82.mdl",
		firedelay			= 0.25,
		reloadspeed			= 0.3,
		reloaddelay			= 20.0,
		inaccuracy			= 1,

		maxlength			= 50,							-- Length of missile. Used for ammo properties.
		propweight			= 0.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 15,							-- Armour effectiveness of casing, in mm

		turnrate			= 7,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 40,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 30,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul            = math.sqrt(0.3),	-- 215.9 HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack", -- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks      = {["1xRK"] = true, ["1xRK_small"] = true, ["3xUARRK"] = true, ["2xRK"] = true, ["3xRK"] = true, ["4xRK"] = true},	-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	ghosttime  = 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.15	-- minimum fuse arming delay
} )

ACE.DefineGun("HVAR ASR", { --id

	name             = "HVAR Rocket",
	desc             = "A medium, unguided rocket. More bang than the RS82, at the cost of size and weight.",
	model            = "models/missiles/hvar.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	 = "ACE_MissileSmall",
	caliber          = 12.7,
	gunclass         = "UAR",
	rack             = "1xRK",  -- Which rack to spawn this missile on?
	weight           = 63,
	length           = 174,
	year             = 1933,
	rofmod           = 0.5,
	roundclass       = "Rocket",
	rotmult          = 1,	-- Adjust this if you see that your missile falls too quickly. 0 to deny falling
	modeldiameter    = 12,
	bodydiameter     = 7, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	= {
		rocketmdl			= "models/missiles/hvar.mdl",
		rackmdl				= "models/missiles/hvar_folded.mdl",
		firedelay			= 0.25,
		reloadspeed			= 0.3,
		reloaddelay			= 45.0,
		inaccuracy			= 0.3,

		maxlength			= 90,							-- Length of missile. Used for ammo properties.
		propweight			= 3,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm

		turnrate			= 7,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 80,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 80,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul            = math.sqrt(0.4),	-- 215.9 HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack", -- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks      = {["1xRK"] = true, ["1xRK_small"] = true, ["3xUARRK"] = true, ["2xRK"] = true, ["3xRK"] = true, ["4xRK"] = true},	-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	ghosttime  = 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.15	-- minimum fuse arming delay
} )

ACE.DefineGun("S-24 ASR", { --id

	name             = "S-24 Rocket",
	desc             = "A big, unguided rocket. Mostly used by late cold war era attack planes and helicopters.",
	model            = "models/missiles/s24.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	 = "ACE_MissileSmall",
	caliber          = 24,
	gunclass         = "UAR",
	rack             = "1xRK",  -- Which rack to spawn this missile on?
	weight           = 235,
	length           = 223 , -- Note: intentional. When scalable system becomes true. I could fix this.
	year             = 1960,
	rofmod           = 0.4,
	roundclass       = "Rocket",
	rotmult          = 360,	-- Adjust this if you see that your missile falls too quickly. 0 to deny falling
	modeldiameter    = 18,
	bodydiameter     = 11, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	= {
		rocketmdl			= "models/missiles/s24.mdl",
		rackmdl				= "models/missiles/s24.mdl",
		firedelay			= 0.25,
		reloadspeed			= 0.3,
		reloaddelay			= 60.0,
		inaccuracy			= 0.3,

		maxlength			= 80,							-- Length of missile. Used for ammo properties.
		propweight			= 20,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 7,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.2,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,						-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 45,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 200,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.004,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul            = math.sqrt(0.4),	-- 215.9 HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack", -- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks      = {["1xRK"] = true, ["3xRK"] = true, ["2xRK"] = true, ["6xUARRK"] = true},	-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	skinindex  = {HEAT = 0, HE = 1},

	ghosttime  = 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.15	-- minimum fuse arming delay
} )

