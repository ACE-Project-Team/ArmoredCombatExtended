--define the class
ACF_defineGunClass("SAM", {
	type           = "missile",  -- i know i know
	spread         = 1,
	name           = "[SAM] - Surface-To-Air Missile",
	desc           = ACFTranslation.MissileClasses[8],
	muzzleflash    = "40mm_muzzleflash_noscale",
	rofmod         = 1,
	year           = 1960,
	sound          = "acf_extra/airfx/rocket_fire2.wav",
	soundDistance  = " ",
	soundNormal    = " ",
	effect         = "Rocket Motor",
	reloadmul      = 8
} )

-- The FIM-92, a lightweight, medium-speed short-range anti-air missile.
ACF_defineGun("FIM-92 SAM", {								-- id
	name             = "FIM-92 Missile",
	desc             = "The FIM-92 Stinger is a lightweight and versatile close-range air defense missile.\nWith a seek cone of 15 degrees and a sharply limited range that makes it useless versus high-flying targets, it is best to aim before firing and choose shots carefully.\n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: Yes\nTop Speed: 226 m/s",
	model            = "models/missiles/fim_92.mdl",
	effect           = "ACE_RocketBlackSmoke",					--Tiny motor for tiny rocket
	effectbooster    = "ACE_MissileSmall",
	gunclass         = "SAM",
	rack             = "1x FIM-92",							-- Which rack to spawn this missile on?
	length           = 150,
	caliber          = 7,
	weight           = 20,									-- 15.1,	-- Don't scale down the weight though!
	modeldiameter    = 3,									-- in cm
	year             = 1978,

	round = {
		rocketmdl			= "models/missiles/fim_92.mdl",
		rackmdl				= "models/missiles/fim_92_folded.mdl",
		firedelay			= 2.0,
		reloadspeed			= 8.0,
		reloaddelay			= 20,


		maxlength			= 30,							-- Length of missile. Used for ammo properties.
		propweight			= 0.3,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 20,							-- Armour effectiveness of casing, in mm

		turnrate			= 240,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.4,							--Fraction of speed redirected every second at max deflection

		thrust				= 5,							-- Acceleration in m/s.
		burntime			= 20,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 40,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 200,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.9,							-- Time in seconds for booster runtime
		boostdelay			= 0.25,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		velmul				= 0.1,		--No

		dragcoef			= 0.00015,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 83
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "Infrared" ,"Antimissile"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {										-- a whitelist for racks that this missile can load into.
				["1x FIM-92"] = true,
				["2x FIM-92"] = true,
				["4x FIM-92"] = true
			},

	seekcone           = 7,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 35
	viewcone           = 70,									-- getting outside this cone will break the lock.  Divided by 2.	--was 55
	SeekSensitivity    = 1.5,
	irccm				= true,
	seekreduction		= 0.3, --Low level seek reduction mainly meant to make it not incredibly easy to flare.

	armdelay	= 0.15,									-- minimum fuse arming delay		-was 0.3
	guidelay           = 0,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.5									-- Time where this missile will be unable to hit surfaces, in seconds
} )

-- The Mistral missile is a faster short range missile with greater range than fim92 but less agility
ACF_defineGun("Mistral SAM", {								-- id
	name             = "Mistral Missile",
	desc             = "A very fast short range missile, faster and less agile than FIM-92. Mostly for Anti-Aircraft and Anti-Missile operations.\n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: No\nTop Speed: 292 m/s",
	model            = "models/missiles/fim_92_folded.mdl",
	effect           = "ACE_RocketBlackSmoke",					--Tiny motor for tiny rocket
	effectbooster    = "ACE_MissileTiny",
	gunclass         = "SAM",
	rack             = "2x FIM-92",							-- Which rack to spawn this missile on?
	length           = 150,
	caliber          = 9,
	weight           = 19.7,									-- 15.1,	-- Don't scale down the weight though!
	modeldiameter    = 3,									-- in cm
	year             = 1974,

	round = {
		rocketmdl			= "models/missiles/fim_92.mdl",
		rackmdl				= "models/missiles/fim_92_folded.mdl",
		firedelay			= 2.0,
		reloadspeed			= 8.0,
		reloaddelay			= 20,


		maxlength			= 23,							-- Length of missile. Used for ammo properties.
		propweight			= 0.5,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 20,							-- Armour effectiveness of casing, in mm

		turnrate			= 50,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.3,							--Fraction of speed redirected every second at max deflection

		thrust				= 5,							-- Acceleration in m/s.
		burntime			= 20,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 60,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 130,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 6,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		velmul				= 0.1,		--No

		dragcoef			= 0.0015,						-- percent speed loss per second
		inertialcapable		= true,						-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 83
	},

	ent        = "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "Infrared", "Antimissile"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {											-- a whitelist for racks that this missile can load into.
				["1x FIM-92"] = true,
				["2x FIM-92"] = true,
				["4x FIM-92"] = true
				},

	seekcone			= 7,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 35
	viewcone			= 70,										-- getting outside this cone will break the lock.  Divided by 2.	--was 55
	SeekSensitivity		= 1.5,
	irccm				= true,
	seekreduction		= 0.3, --Low level seek reduction mainly meant to make it not incredibly easy to flare.

	guidelay   = 0,										-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime  = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay   = 0.15										-- minimum fuse arming delay		-was 0.3
} )


ACF_defineGun("TY-90 AAM", {								-- id
	name             = "TY-90 Anti Air Missile",
	desc             = "A short range missile with exceptional agility. Cruises at a moderate speed compared to the other short range SAMs.\n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: No\nTop Speed: 242 m/s",
	model            = "models/missiles/ty90.mdl",
	effect           = "ACE_RocketBlackSmoke",					--Tiny motor for tiny rocket
	effectbooster    = "ACE_MissileSmall",
	gunclass         = "SAM",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 115 * 2.53, --Convert to ammocrate units
	caliber          = 9,
	weight           = 20,								-- Don't scale down the weight though!
	year             = 1968,
	modeldiameter    = 20, --Already in ammocrate units
	bodydiameter     = 5.3, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/missiles/ty90.mdl",
		rackmdl				= "models/missiles/ty90.mdl",
		firedelay			= 2.0,
		reloadspeed			= 8.0,
		reloaddelay			= 20,

		maxlength			= 23,							-- Length of missile. Used for ammo properties.
		propweight			= 0.5,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 320,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.8,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 5,							-- Acceleration in m/s.
		burntime			= 20.0,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 40,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 120,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 6.0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		velmul				= 0.1,		--No

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 415
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "Infrared"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'
				["1xRK"] = true,
				["2xRK"] = true,
				["3xRK"] = true,
				["4xRK"] = true,
				["1xRK_small"] = true,
				["4x FIM-92"] = true
			},

	seekcone           = 7,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone           = 65,								-- getting outside this cone will break the lock.  Divided by 2.		--was 30
	SeekSensitivity    = 1.5,
	irccm				= true,
	seekreduction		= 0.2,

	armdelay           = 0.15,								-- minimum fuse arming delay		--was 0.4
	guidelay           = 0.25,								-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.075									-- Time where this missile will be unable to hit surfaces, in seconds
} )

-- The 9M31 Strela-1, a bulky, slow medium-range anti-air missile.
ACF_defineGun("Strela-1 SAM", {								-- id
	name             = "9M31 Strela-1",
	desc             = "The 9M31 Strela-1 is a medium-range homing SAM with a much bigger payload than the FIM-92. Bulky. It is best suited to ground vehicles or stationary units. Beware the narrow seeker. This helps with flares but makes acquisition harder.\n\nInertial Guidance: No\nECCM: Reduction\nDatalink: No\nTop Speed: 179 m/s",
	model            = "models/missiles/9m31.mdl",
	effect           = "ACE_MissileMedium",
	gunclass         = "SAM",
	rack             = "1x Strela-1",							-- Which rack to spawn this missile on?
	length           = 219,
	caliber          = 12,
	weight           = 72,									-- 15.1,	-- Don't scale down the weight though!
	year             = 1960,
	modeldiameter    = 10,
	bodydiameter     = 7.3, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/missiles/9m31.mdl",
		rackmdl				= "models/missiles/9m31f.mdl",
		firedelay			= 1.25,
		reloadspeed			= 8.0,
		reloaddelay			= 20,

		maxlength			= 22,							-- Length of missile. Used for ammo properties.
		propweight			= 0.5,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 60,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.25,							--Fraction of speed redirected every second at max deflection

		thrust				= 60,							-- Acceleration in m/s.
		--120 seconds? Does it really have a 120 second burntime??? Not setting higher so people can't minimize proppelant
		burntime			= 10,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 50,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		pointcost			= 250
	},

	ent			= "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Infrared","Antimissile"},
	fuses		= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks		= {										-- a whitelist for racks that this missile can load into.
						["1x Strela-1"] = true,
						["2x Strela-1"] = true,
						["4x Strela-1"] = true
					},

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone           = 70,									-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 1.5,
	irccm				= false,
	seekreduction		= 0.0002,

	armdelay	= 0.15,									-- minimum fuse arming delay
	guidelay           = 0.75,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.5									-- Time where this missile will be unable to hit surfaces, in seconds
} )

ACF_defineGun("VT-1 SAM", {										-- id
	name             = "VT-1 Missile",
	desc             = "Powerful command guided SAM. Great range, good agility, and a powerful warhead. \n\nInertial Guidance: False\nECCM: Reduction\nDatalink: Yes\nTop Speed: 183 m/s",
	model            = "models/missiles/arend/vt1.mdl",
	effect           = "ACE_MissileSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass         = "SAM",
	rack             = "1x VT-1",								-- Which rack to spawn this missile on?
	length           = 92 * 2.53, --Convert to ammocrate units
	caliber          = 16.5,
	weight           = 73,										-- Don't scale down the weight though!
	year             = 1960,
	modeldiameter    = 8,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/arend/vt1.mdl",
		rackmdl				= "models/missiles/arend/vt1_folded.mdl",
		firedelay			= 0.75,
		reloadspeed			= 5.0,
		reloaddelay			= 30.0,

		maxlength			= 38,							-- Length of missile. Used for ammo properties.
		propweight			= 3,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 65,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.3,							--Fraction of speed redirected every second at max deflection

		thrust				= 60,							-- Acceleration in m/s.
		burntime			= 10,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 50,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 300,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.25,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 353
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "SACLOS", "Semiactive"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks = {										-- a whitelist for racks that this missile can load into.
				["1x VT-1"] = true,
				["1xVLS"] = true,
				["1xmVLS"] = true,
				["4xVLS"] = true,
				["4xmVLS"] = true
			},

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone           = 70,									-- getting outside this cone will break the lock.  Divided by 2.
	irccm				= false,
	seekreduction		= 0.25,

	armdelay	= 0.15,									-- minimum fuse arming delay
	guidelay           = 0,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	SeekSensitivity    = 2
} )

--Tunguska Missile
ACF_defineGun("9M311 SAM", {										-- id
	name             = "9M311 Tunguska",
	desc             = "The 9M311 missile is SAM meant to minimize traveltime. While lacking the agility and energy retention to hit maneuvering planes, this missile excels against helicopters due to the short traveltime. \n\nInertial Guidance: No\nECCM: Reduction\nDatalink: Yes\nTop Speed: 365 m/s",
	model            = "models/missiles/arend/9m311_unfolded.mdl",
	effect           = "ACE_RocketBlackSmoke",
	effectbooster	= "ACE_MotorSmall",
	gunclass         = "SAM",
	rack             = "1x 9m311",								-- Which rack to spawn this missile on?
	length           = 100 * 2.53, --Convert to ammocrate units
	caliber          = 7.6,
	weight           = 71,										-- Don't scale down the weight though!
	year             = 1982,
	modeldiameter    = 7,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/arend/9m311_unfolded.mdl",
		rackmdl				= "models/missiles/arend/9m311_folded.mdl",
		firedelay			= 0.75,
		reloadspeed			= 5.0,
		reloaddelay			= 40.0,

		--Formerly 190 and 1. Reduced blast from 283j to 116Mj. For reference a 100kg bomb has 117Kj.

		maxlength			= 78,							-- Length of missile. Used for ammo properties.
		propweight			= 2,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm
		turnrate			= 13,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.3,							--Fraction of speed redirected every second at max deflection

		thrust				= 5,							-- Acceleration in m/s.
		burntime			= 20,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 60,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		--Should be around 1.5s. Set to 1/4th boost time.
		boostacceleration	= 800,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.35,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		velmul				= 0.1,		--No

		dragcoef			= 0.0001,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 235
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "SACLOS", "Semiactive"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks = {										-- a whitelist for racks that this missile can load into.
				["1x 9m311"] = true,
				["1xVLS"] = true,
				["1xmVLS"] = true,
				["4xVLS"] = true,
				["4xmVLS"] = true
			},

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone           = 70,									-- getting outside this cone will break the lock.  Divided by 2.
	irccm				= false,
	seekreduction		= 0.25,

	armdelay	= 0.15,									-- minimum fuse arming delay
	guidelay           = 0,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	SeekSensitivity    = 2
} )


--TOR Missile. This is going to be fun.
ACF_defineGun("9M331 SAM", {								-- id
	name             = "9M331 TOR",
	desc             = "The TOR Missile. Medium range SAM. This vertically Launched medium range missile is fast reacting making it good for missile intercepts, agile, and deadly. The missile is first kicked out of the tube, spun towards the target, then launched. \n\nInertial Guidance: Yes\nECCM: Reduction\nDatalink: Yes\nTop Speed: 251 m/s",
	model            = "models/missiles/arend/9m331_unfolded.mdl",
	effect           = "ACE_MissileMedium",
	effectbooster	 = "Rocket_Smoke_Trail",
	gunclass         = "SAM",
	rack             = "1x9M331 Pod",							-- Which rack to spawn this missile on?
	length           = 118 * 2.53, --Convert to ammocrate units
	caliber          = 15, --Had to artificially reduce the caliber from 23.5 to get the warhead area to reduce
	weight           = 167,									-- 15.1,	-- Don't scale down the weight though!
	year             = 1986,
	modeldiameter    = 10,
	bodydiameter     = 7.62, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/missiles/arend/9m331_unfolded.mdl",
		rackmdl				= "models/missiles/arend/9m331_folded.mdl",
		firedelay			= 0.5,
		reloadspeed			= 5.0,
		reloaddelay			= 40,

		maxlength			= 40,							-- Length of missile. Used for ammo properties.
		propweight			= 1.0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 35,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 5,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.5,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 120,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 120,							-- Acceleration in m/s.
		burntime			= 10,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 30,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.05,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		velmul				= 0.1,		--No

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 1.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 353
	},

	ent			= "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance		= {"Dumb", "SACLOS", "Semiactive","Antimissile"},
	fuses		= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks		= {										-- a whitelist for racks that this missile can load into.
						["1x9M331 Pod"] = true,
						["1xVLS"] = true,
						["1xmVLS"] = true,
						["4xVLS"] = true,
						["4xmVLS"] = true
				},

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone           = 60,									-- getting outside this cone will break the lock.  Divided by 2.
	irccm				= false,
	seekreduction		= 0.25,

	armdelay	= 0.15,									-- minimum fuse arming delay
	guidelay           = 0,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0									-- Time where this missile will be unable to hit surfaces, in seconds
} )

--AIM-54 phoenix. Being faster and bigger than AIM-120, can deliver a single big blast against the target, however, this 300kgs piece of aerial destruction has a serious trouble
--with its seek cone and is suggested to AIM before launching.
ACF_defineGun("9M38M1 SAM", {							-- id
	name             = "9M38M1 BUK",
	desc             = "Diabolically sized missile meant to bring about the end of aviation. Has a nasty amount of ECCM, an absurd warhead, and enough range to travel across some countries. Takes a bit to get up to speed but is remarkably difficult to defeat. \n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: Yes\nTop Speed: 273 m/s",
	model            = "models/macc/9m38m1.mdl",
	effect           = "ACE_MissileLarge",
	effectbooster	 = "ACE_MissileLarge",
	gunclass         = "SAM",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 220 * 2.53, --Convert to ammocrate units
	caliber          = 20,								--Actual is 330. Had to reduce caliber because of shell customization ratio limits preventing not having a shell smaller than 50cm and thus having a huge warhead
	weight           = 710,								-- Don't scale down the weight though!
	year             = 1981,
	modeldiameter    = 32,--Already in ammocrate units
	bodydiameter     = 20, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/macc/9m38m1.mdl",
		rackmdl				= "models/macc/9m38m1.mdl",
		firedelay			= 1.0,
		reloadspeed			= 10,
		reloaddelay			= 45.0,


		maxlength			= 111.8,							-- Length of missile. Used for ammo properties.
		propweight			= 15,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 10,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 1.0,							--Fraction of speed redirected every second at max deflection

		thrust				= 145,							-- Acceleration in m/s.
		--120 seconds? Does it really have a 120 second burntime??? Not setting higher so people can't minimize proppelant
		burntime			= 15,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 10,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 80,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		velmul				= 0.1,		--No

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.35,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 333
	},

	ent                = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance           = {"Dumb", "Radar"},
	fuses              = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks              = {
	["1xRK"] = true
	},					-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)  --was 4
	viewcone           = 60,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 1,
	irccm				= true,
	seekreduction		= 0.0002,

	agility            = 3,									-- multiplier for missile turn-rate.  --was 0.7
	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3
	guidelay           = 0.5,								-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.05									-- Time where this missile will be unable to hit surfaces, in seconds
} )


ACF_defineGun("5V55 SAM", {							-- id
	name             = "5V55 S-300 SAM",
	desc             = "Ultimate Long range SAM. Extreme range, Maneuverable, and F A S T. \n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: Yes\nTop Speed: 273 m/s",
	model            = "models/missiles/5v55.mdl",
	effect           = "ACE_MissileLarge",
	effectbooster	 = "ACE_RocketBlackSmoke",
	gunclass         = "SAM",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 200 * 2.53, --Convert to ammocrate units
	caliber          = 20,								--Actual is 514. Had to reduce caliber because of shell customization ratio limits preventing not having a shell smaller than 50cm and thus having a huge warhead
	weight           = 1480,								-- Don't scale down the weight though!
	year             = 1981,
	modeldiameter    = 32,--Already in ammocrate units
	bodydiameter     = 20, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/missiles/5v55.mdl",
		rackmdl				= "models/missiles/5v55.mdl",
		firedelay			= 1.0,
		reloadspeed			= 10,
		reloaddelay			= 45.0,


		maxlength			= 177.5,							-- Length of missile. Used for ammo properties.
		propweight			= 20,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 4,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.4,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 50,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 95,							-- Acceleration in m/s.
		--120 seconds? Does it really have a 120 second burntime??? Not setting higher so people can't minimize proppelant
		burntime			= 15,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 1,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.15,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00025,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.35,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 600
	},

	ent                = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance           = {"Dumb", "SACLOS", "Semiactive","Antimissile"},
	fuses              = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks              = {
	["1xVLS"] = true,
	["4xVLS"] = true
	},					-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)  --was 4
	viewcone           = 60,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 1,
	irccm				= true,
	seekreduction		= 0.25,

	agility            = 3,									-- multiplier for missile turn-rate.  --was 0.7
	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3
	guidelay           = 0.5,								-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.05									-- Time where this missile will be unable to hit surfaces, in seconds
} )


ACF_defineGun("StarstreakHVM", {										-- id
	name             = "Starstreak HVM",
	desc             = "Lightweight and extremely fast darts. While lacking much of the explosive power of other missiles these missiles make up in absolute speed and moderate kinetic abilities. \n\nInertial Guidance: No\nECCM: No\nDatalink: Yes\nTop Speed: 575 m/s\nMax Kinetic Pen: 409mm W/ APHE",
	model            = "models/missiles/hvm_folded.mdl",
	effect           = "ACE_MotorTiny",
	effectbooster	 = "ACE_MissileMedium",
	gunclass         = "SAM",
	rack             = "1x HVM",								-- Which rack to spawn this missile on?
	length           = 60 * 2.53, --Convert to ammocrate units
	caliber          = 6.6,
	weight           = 14,										-- Don't scale down the weight though!
	year             = 1982,
	modeldiameter    = 7,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/hvm.mdl",
		rackmdl				= "models/missiles/hvm_folded.mdl",
		firedelay			= 0.75,
		reloadspeed			= 5.0,
		reloaddelay			= 40.0,

		--Formerly 190 and 1. Reduced blast from 283j to 116Mj. For reference a 100kg bomb has 117Kj.

		maxlength			= 15,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm
		turnrate			= 3,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.6,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 30,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 200,							-- Acceleration in m/s.
		burntime			= 3,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 30,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		--Should be around 1.5s. Set to 1/4th boost time.
		boostacceleration	= 200,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 1.0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles
		calmul			= 0.0025,	--I guess it was a little too good at transfering energy. Increasing the velocitymul(energy limit) sent tanks to space
		velmul			= 0.05,

		dragcoef			= 0.0005,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.0,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		pointcost			= 235
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "Beam_Riding", "SACLOS", "Semiactive"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks = {										-- a whitelist for racks that this missile can load into.
			["1x HVM"] = true
			},

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone           = 70,									-- getting outside this cone will break the lock.  Divided by 2.

	armdelay	= 0.15,									-- minimum fuse arming delay
	guidelay           = 0,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	SeekSensitivity    = 2
} )