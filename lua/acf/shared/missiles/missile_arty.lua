
--define the class
ACF_defineGunClass("ARTY", {
	type           = "missile",
	spread         = 1,
	name           = "[ARTY] - Artillery Rockets",
	desc           = ACFTranslation.MissileClasses[2],
	muzzleflash    = "40mm_muzzleflash_noscale",
	rofmod         = 1,
	sound          = "acf_extra/airfx/rocket_fire2.wav",
	year           = 1944,
	soundDistance  = " ",
	soundNormal    = " ",
	effect         = "Rocket Motor Arty"
} )


ACF_defineGun("Type 63 RA", {							-- id

	name             = "Type 63 Rocket",
	desc             = "A common artillery rocket in the third world, able to be launched from a variety of platforms with a painful whallop and a very arced trajectory.\nContrary to appearances and assumptions, does not in fact werf nebel.",
	model            = "models/missiles/glatgm/mgm51.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	= "ACE_MissileSmall",
	caliber          = 10.7,
	gunclass         = "ARTY",
	rack             = "1xRK_small",							-- Which rack to spawn this missile on?
	weight           = 80,
	length           = 126,
	year             = 1960,
	rofmod           = 0.3,
	roundclass       = "Rocket",
	modeldiameter    = 7.96,
	bodydiameter     = 8.8, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rotmult          = 60,	-- Adjust this if you see that your missile falls too quickly. 0 to deny falling
	maxrottq         = 2000, -- Max torque applied to the missile when its rotating during a unguided flight. Use this if you see your missile doing crazy movements when its out.

	round	=	{
		rocketmdl			= "models/missiles/glatgm/mgm51.mdl",
		rackmdl				= "models/missiles/glatgm/mgm51.mdl",
		firedelay			= 0.15,
		reloadspeed			= 0.5,
		reloaddelay			= 30.0,
		inaccuracy			= 3.0,

		maxlength			= 200,							-- Length of missile. Used for ammo properties.
		propweight			= 0.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.35,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 15,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 100,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00025,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.



		penmul            = math.sqrt(0.15)				-- 139 HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {										-- a whitelist for racks that this missile can load into.
					["1xRK_small"] = true,
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true,
					["6xUARRK"] = true
				},

	viewcone   = 30,									-- cone radius, 180 = full 360 tracking
	ghosttime  = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.15									-- minimum fuse arming delay
} )



ACF_defineGun("SAKR-10 RA", {							-- id

	name             = "SAKR-10 Rocket",
	desc             = "A short-range but formidable unguided artillery rocket, based upon the Grad.  Well suited to the backs of trucks.",
	model            = "models/missiles/9m28f.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	= "ACE_MissileMedium",
	caliber          = 12.2,
	gunclass         = "ARTY",
	rack             = "1xRK",								-- Which rack to spawn this missile on?
	weight           = 160,
	length           = 219, --320
	year             = 1980,
	roundclass       = "Rocket",
	modeldiameter    = 10,
	bodydiameter     = 7.3, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	=	{
		rocketmdl			= "models/missiles/9m28f.mdl",
		rackmdl				= "models/missiles/9m28f.mdl",
		firedelay			= 0.15,
		reloadspeed			= 1.0,
		reloaddelay			= 40.0,
		inaccuracy			= 3.0,

		maxlength			= 210,							-- Length of missile. Used for ammo properties.
		propweight			= 4,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 60,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00025,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {										-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true,
					["6xUARRK"] = true
				},

	viewcone   = 20,
	ghosttime  = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.15									-- minimum fuse arming delay
} )


ACF_defineGun("RW61 RA", {								-- id

	name             = "Raketwerfer-61",
	desc             = "A heavy, demolition-oriented rocket-assisted mortar, devastating against field works but takes a very, VERY long time to load.\n\n\nDon't miss.",
	model            = "models/missiles/RW61M.mdl",
	effect           = "ACE_MissileLarge",
	effectbooster	= "ACE_MissileLarge",
	caliber          = 38,
	gunclass         = "ARTY",
	rack             = "380mmRW61",							-- Which rack to spawn this missile on?
	weight           = 1800,
	length           = 161,
	year             = 1944,
	rofmod           = 0.25,
	roundclass       = "Rocket",
	modeldiameter    = 16,
	rotmult          = 100,	-- Adjust this if you see that your missile falls too quickly. 0 to deny falling

	round	=
	{
		rocketmdl			= "models/missiles/RW61M.mdl",
		rackmdl				= "models/missiles/RW61M.mdl",
		firedelay			= 0.25,
		reloadspeed			= 0.2,
		reloaddelay			= 60.0,
		inaccuracy			= 0.1,

		maxlength			= 200,							-- Length of missile. Used for ammo properties.
		propweight			= 7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 60,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 75,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 120,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.004,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul            = math.sqrt(0.4),						-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},		-- Because who doesn't love cluster RW61s

	racks	= {										-- a whitelist for racks that this missile can load into.
					["380mmRW61"] = true
				},

	seekcone   = 35,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 55,									-- getting outside this cone will break the lock.  Divided by 2.

	agility    = 1,										-- multiplier for missile turn-rate.
	ghosttime  = 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.15									-- minimum fuse arming delay
} )

ACF_defineGun("M26 RA", {							-- id

	name             = "M26 MLRS",
	desc             = "Long range unguided rocket built for the M270 MLRS.",
	model            = "models/missiles/gmlrs.mdl",
	effect           = "ACE_MissileMedium",
	effectbooster	= "ACE_MissileMedium",
	caliber          = 22.7,
	gunclass         = "ARTY",
	rack             = "6xUARRK",								-- Which rack to spawn this missile on?
	weight           = 308,
	length           = 155 * 2.53, --Convert to ammocrate units
	year             = 1980,
	roundclass       = "Rocket",
	modeldiameter    = 10, --Already in ammocrate units
	bodydiameter     = 7.3, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	=	{
		rocketmdl			= "models/missiles/GMLRS_M26.mdl",
		rackmdl				= "models/missiles/GMLRS_M26.mdl",
		firedelay			= 0.33,
		reloadspeed			= 1.0,
		reloaddelay			= 30.0,
		inaccuracy			= 4,

		maxlength			= 210,							-- Length of missile. Used for ammo properties.
		propweight			= 4,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 30,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 150,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.5,							-- Time in seconds for booster runtime
		boostdelay			= 0.2,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00025,						-- percent speed loss per second
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {										-- a whitelist for racks that this missile can load into.
					["6xUARRK"] = true
				},

	viewcone   = 30,
	ghosttime  = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.2									-- minimum fuse arming delay
} )

ACF_defineGun("SS-40 RA", {								-- id

	name             = "SS-40 Rocket",
	desc             = "A large, heavy, guided artillery rocket for taking out stationary or dug-in targets.  Slow to load, slow to fire, slow to guide, and slow to arrive.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No",
	model            = "models/missiles/aim120.mdl",
	effect           = "ACE_MissileMedium",
	effectbooster	= "ACE_MissileMedium",
	caliber          = 18.0,
	gunclass         = "ARTY",
	rack             = "1xRK",								-- Which rack to spawn this missile on?
	weight           = 320,
	length           = 383,
	year             = 1983,
	roundclass       = "Rocket",
	modeldiameter    = 4 * 2.54,
	bodydiameter     = 9.2, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	=	{
		rocketmdl			= "models/missiles/aim120.mdl",
		rackmdl				= "models/missiles/aim120.mdl",
		firedelay			= 0.5,
		reloadspeed			= 7,
		reloaddelay			= 10.0,
		inaccuracy			= 0,

		maxlength			= 180,							-- Length of missile. Used for ammo properties.
		propweight			= 4,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 25,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.4,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 3,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 30,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul            = math.sqrt(0.2),					-- 139 HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "GPS"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {										-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true,
					["6xUARRK"] = true
				},

	viewcone   = 180,
	ghosttime  = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.15									-- minimum fuse arming delay
} )

ACF_defineGun("M31 RA", {							-- id

	name             = "M31 GMLRS",
	desc             = "Long range precision strike missile found in the M270 MLRS. Guided to give better precision and control over trajectory.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No",
	model            = "models/missiles/gmlrs.mdl",
	effect           = "ACE_MissileMedium",
	effectbooster	= "ACE_MissileMedium",
	caliber          = 22.7,
	gunclass         = "ARTY",
	rack             = "6xUARRK",								-- Which rack to spawn this missile on?
	weight           = 308,
	length           = 155 * 2.53, --Convert to ammocrate units
	year             = 1980,
	roundclass       = "Rocket",
	modeldiameter    = 10, --Already in ammocrate units
	bodydiameter     = 7.3, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round	=	{
		rocketmdl			= "models/missiles/gmlrs.mdl",
		rackmdl				= "models/missiles/gmlrs.mdl",
		firedelay			= 0.6,
		reloadspeed			= 10,
		reloaddelay			= 12,
		inaccuracy			= 0.0,

		maxlength			= 210,							-- Length of missile. Used for ammo properties.
		propweight			= 4,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 15,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.4,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 3,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 0,							-- Acceleration in m/s.
		burntime			= 25,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 30,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 60,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 3,							-- Time in seconds for booster runtime
		boostdelay			= 0.25,							-- Delay in seconds before booster activates.

		fusetime			= 60,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "GPS"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {										-- a whitelist for racks that this missile can load into.
					["6xUARRK"] = true
				},

	viewcone   = 30,
	ghosttime  = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.2									-- minimum fuse arming delay
} )

ACF_defineGun("ATACMS RA", {						-- id
	name             = "MGM-140 ATACMS",
	desc             = "Mother of all artillery rockets. This slow lumbering menace of a MASSIVE missile is perfect for obliterating fortifications with precision. Though slow and not too maneuverabile it packs a hell of a punch. Get out of the way!!!\n\nInertial Guidance: Yes\nECCM: No\nDatalink: Yes",
	model            = "models/macc/MGM-140.mdl",
	effect           = "ACE_MissileLarge",
	effectbooster	 = "ACE_MissileLarge",
	gunclass         = "ARTY",
	rack             = "1xRK",						-- Which rack to spawn this missile on?
	length           = 145 * 2.53, --Convert to ammocrate units
	caliber          = 61,
	weight           = 1670,							-- Don't scale down the weight though!
	year             = 1974,
	modeldiameter    = 25, --Already in ammocrate units
	bodydiameter     = 21, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rofmod           = 0.3,
	round = {
		rocketmdl			= "models/macc/MGM-140.mdl",
		rackmdl				= "models/macc/mgm-140_closed.mdl",
		firedelay			= 0.5,
		reloadspeed			= 2.0,
		reloaddelay			= 50.0,


		maxlength			= 220,							-- Length of missile. Used for ammo properties.
		propweight			= 5,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 14,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 35,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.7,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 2,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 60,							-- Acceleration in m/s.

		burntime			= 10,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 0,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.01,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		penmul            = math.sqrt(1),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Laser", "GPS"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true
				},

	seekcone   = 2,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 30,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3

} )



ACF_defineGun("9M79-1", {						-- id
	name             = "9M79-1 Tochka-U",
	desc             = "Tactical nuke without the nuke. But what's the difference really? Will precisely wipe out entire gridsquares.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: Yes",
	model            = "models/missiles/9m79.mdl",
	effect           = "ACE_MotorLarge",
	effectbooster	 = "ACE_MissileLarge",
	gunclass         = "ARTY",
	rack             = "1xRK",						-- Which rack to spawn this missile on?
	length           = 230 * 2.53, --Convert to ammocrate units
	caliber          = 65,
	weight           = 2000,							-- Don't scale down the weight though!
	year             = 1974,
	modeldiameter    = 30, --Already in ammocrate units
	bodydiameter     = 23.5, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rofmod           = 0.3,
	round = {
		rocketmdl			= "models/missiles/9m79.mdl",
		rackmdl				= "models/missiles/9m79.mdl",
		firedelay			= 0.5,
		reloadspeed			= 2.0,
		reloaddelay			= 50.0,


		maxlength			= 300,							-- Length of missile. Used for ammo properties.
		propweight			= 5,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 7,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 20,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.6,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 18,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 45,							-- Acceleration in m/s.

		burntime			= 8,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 0,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 45,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 2.5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.005,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= false,
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		penmul            = math.sqrt(1),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "GPS"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true
				},

	seekcone   = 2,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 30,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3

} )