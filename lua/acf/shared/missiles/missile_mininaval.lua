
--define the class
ACF_defineGunClass("mNAV", {
	type           = "missile",
	spread         = 1,
	name           = "[mNAV] - Scaled Naval Missiles",
	desc           = ACFTranslation.MissileClasses[3],
	muzzleflash    = "40mm_muzzleflash_noscale",
	year           = 1969,
	rofmod         = 1,
	sound          = "acf_extra/airfx/rocket_fire2.wav",
	soundDistance  = " ",
	soundNormal    = " ",
	effect         = "Rocket Motor Missile1",		-- Small/Medium size missile

	reloadmul      = 8
} )



ACF_defineGun("Scaled BGM-109 Tomahawk", {						-- id
	name             = "BGM-109 Tomahawk",
	desc             = "The gold standard of cruise missiles. Subsonic and long range. Though slow this ordinance has extreme range and good maneuverability. Good for removing distant targets. Cannot be updated after it has launched.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: 81 m/s",
	model            = "models/macc/Tomahawk_Small.mdl",
	effect           = "ACE_RocketBlackSmoke", --Rocket_Smoke_Trail
	effectbooster	 = "ACE_MissileMedium",
	gunclass         = "mNAV",
	rack             = "1xRK",						-- Which rack to spawn this missile on?
	length           = 250 * 2.53, --Convert to ammocrate units
	caliber          = 35.56,
	weight           = 1600,							-- Don't scale down the weight though!
	year             = 1983,
	modeldiameter    = 15, --Already in ammocrate units
	bodydiameter     = 24.25, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rofmod           = 0.3,
	round = {
		rocketmdl			= "models/macc/Tomahawk_Small.mdl",
		rackmdl				= "models/macc/Tomahawk_Folded_Small.mdl",
		firedelay			= 1.0,
		reloadspeed			= 5.0,
		reloaddelay			= 1.0,


		maxlength			= 220,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 40,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.7,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 30,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 15,							-- Acceleration in m/s.

		burntime			= 60,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 5,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 60,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 2,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0025,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= false,
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		penmul            = math.sqrt(1),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		waterthrusttype 	= 1, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
		pointcost			= 250
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "GPS", "GPS_TerrainAvoidant", "Radar"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["1xmVLS"] = true,
					["4xmVLS"] = true,
					["6xSmallTorpedo"] = true,
					["5xSmallTorpedo"] = true,
					["4xSmallTorpedo"] = true,
					["3xSmallTorpedo"] = true,
					["2xSmallTorpedo"] = true,
					["1xSmallTorpedo"] = true
				},

	seekcone   = 2,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 30,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3

} )


ACF_defineGun("Scaled AGM-84 Harpoon", {						-- id
	name             = "AGM-84 Harpoon",
	desc             = "Versatile subsonic anti ship missile. Though somewhat sluggish packs a wallop.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: 81 m/s",
	model            = "models/missiles/1xagm84.mdl",
	effect           = "ACE_RocketBlackSmoke", --Rocket_Smoke_Trail
	effectbooster	 = "ACE_MissileMedium",
	gunclass         = "mNAV",
	rack             = "1xRK",						-- Which rack to spawn this missile on?
	length           = 150 * 2.53, --Convert to ammocrate units
	caliber          = 34,
	weight           = 690,							-- Don't scale down the weight though!
	year             = 1977,
	modeldiameter    = 12.5, --Already in ammocrate units
	bodydiameter     = 15.25, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rofmod           = 0.3,
	round = {
		rocketmdl			= "models/missiles/375xagm84.mdl",
		rackmdl				= "models/missiles/375xagm84.mdl",
		firedelay			= 1.0,
		reloadspeed			= 5.0,
		reloaddelay			= 1.0,


		maxlength			= 100,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 60,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 30,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.4,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 50,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 14,							-- Acceleration in m/s.

		burntime			= 60,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 20,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 3,							-- Time in seconds for booster runtime
		boostdelay			= 0.25,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0025,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= false,
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		penmul            = math.sqrt(1),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		waterthrusttype 	= 1, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
		pointcost			= 1000
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Infrared", "Radar"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["1xmVLS"] = true,
					["4xmVLS"] = true,
					["6xSmallTorpedo"] = true,
					["5xSmallTorpedo"] = true,
					["4xSmallTorpedo"] = true,
					["3xSmallTorpedo"] = true,
					["2xSmallTorpedo"] = true,
					["1xSmallTorpedo"] = true
				},

	skinindex	= {HEAT = 1, HE = 0},

	seekcone   = 2,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 90,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3

} )

ACF_defineGun("Scaled Storm Shadow ASM", {						-- id
	name             = "SCALP-EG Storm Shadow",
	desc             = "The stormshadow is a low observability, turbojet driven cruise missile. Though slow this ordinance has extreme range, good maneuverability, staying time. And will obliterate anything it touches.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: Yes\nTop Speed: 81 m/s",
	model            = "models/macc/storm_shadow_open.mdl",
	effect           = "Rocket_Smoke_Trail",
	effectbooster	 = "ACE_MissileTiny",
	gunclass         = "mNAV",
	rack             = "1xRK",						-- Which rack to spawn this missile on?
	length           = 205 * 2.53, --Convert to ammocrate units
	caliber          = 35.56,
	weight           = 1300,							-- Don't scale down the weight though!
	year             = 2003,
	modeldiameter    = 20, --Already in ammocrate units
	bodydiameter     = 24.25, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rofmod           = 0.3,
	round = {
		rocketmdl			= "models/macc/Storm_Shadow_Open_Small.mdl",
		rackmdl				= "models/macc/Storm_Shadow_Closed_Small.mdl",
		firedelay			= 0.5,
		reloadspeed			= 20.0,
		reloaddelay			= 5.0,


		maxlength			= 220,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 7,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 55,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.7,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 10,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 60,							-- Acceleration in m/s.

		burntime			= 60,							-- time in seconds for rocket motor to burn at max proppelant.
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
		pointcost			= 250
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Laser", "GPS", "GPS_TerrainAvoidant"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["1xmVLS"] = true,
					["4xmVLS"] = true,
					["6xSmallTorpedo"] = true,
					["5xSmallTorpedo"] = true,
					["4xSmallTorpedo"] = true,
					["3xSmallTorpedo"] = true,
					["2xSmallTorpedo"] = true,
					["1xSmallTorpedo"] = true
			},

	seekcone   = 2,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 30,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3

} )

ACF_defineGun("Scaled 3M-54 Kalibr", {						-- id
	name             = "3M-54 Kalibr",
	desc             = "Russia's cruise missile. Fast and long range. This massive missile can easily remove entire regions. Cannot be updated after it has launched.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: 81 m/s",
	model            = "models/macc/Kalibr_small.mdl",
	effect           = "ACE_RocketBlackSmoke", --Rocket_Smoke_Trail
	effectbooster	 = "ACE_MissileLarge",
	gunclass         = "mNAV",
	rack             = "1xRK",						-- Which rack to spawn this missile on?
	length           = 250 * 2.53, --Convert to ammocrate units
	caliber          = 53.3,
	weight           = 2300,							-- Don't scale down the weight though!
	year             = 1983,
	modeldiameter    = 15, --Already in ammocrate units
	bodydiameter     = 24.25, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	rofmod           = 0.3,
	round = {
		rocketmdl			= "models/macc/Kalibr_small.mdl",
		rackmdl				= "models/macc/Kalibr_folded_small.mdl",
		firedelay			= 1.0,
		reloadspeed			= 5.0,
		reloaddelay			= 1.0,


		maxlength			= 220,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 50,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 10,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.7,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 30,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 40,							-- Acceleration in m/s.

		burntime			= 60,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 30,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 30,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 3,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 130,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0025,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= false,
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		penmul            = math.sqrt(1),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		waterthrusttype 	= 1, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
		pointcost			= 250
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "GPS", "GPS_TerrainAvoidant", "Radar"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["1xmVLS"] = true,
					["4xmVLS"] = true,
					["6xSmallTorpedo"] = true,
					["5xSmallTorpedo"] = true,
					["4xSmallTorpedo"] = true,
					["3xSmallTorpedo"] = true,
					["2xSmallTorpedo"] = true,
					["1xSmallTorpedo"] = true
				},

	seekcone   = 2,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone   = 30,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3

} )

ACF_defineGun("Scaled Black Shark Torp", {						-- id
	name             = "533mm Black Shark Torpedo",
	desc             = "Advanced heavyweight torpedo meant to strike fear into capital ships of all sizes.\n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: No\nTop Speed: N/A m/s",
	model            = "models/missiles/blacksharkwass_small.mdl",
	effect           = "ACE_TorpedoMedium",
	effectbooster    = "",
	gunclass         = "mNAV",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 250 * 2.53, --Convert to ammocrate units,
	caliber          = 15, --Unfortunately caliber determines the minimum length even above the max length var. For now has to be set lower than 1:1
	weight           = 1200,								-- Don't scale down the weight though!
	rofmod           = 0.3,
	year             = 2015,
	modeldiameter    = 15,
	bodydiameter     = 16, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/missiles/blacksharkwass_small.mdl",
		rackmdl				= "models/missiles/blacksharkwass_small.mdl",
		firedelay			= 0.5,
		reloadspeed			= 6.0,
		reloaddelay			= 25.0,

		maxlength			= 175,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm
		turnrate			= 6,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.5,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 40,							-- Acceleration in m/s.
		burntime			= 120,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 130,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.001,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		waterthrusttype 	= 4, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
		buoyancy			= 1,
		pointcost			= 1500,
	},

	ent		= "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb","Straight_Running","Acoustic_Straight","Wire"},
	fuses	= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["6xSmallTorpedo"] = true,
					["5xSmallTorpedo"] = true,
					["4xSmallTorpedo"] = true,
					["3xSmallTorpedo"] = true,
					["2xSmallTorpedo"] = true,
					["1xSmallTorpedo"] = true
				},

	seekcone   = 13,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone   = 13,								-- getting outside this cone will break the lock.  Divided by 2.

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15								-- minimum fuse arming delay		--was 0.4
} )

ACF_defineGun("Scaled G7a Torp", {						-- id
	name             = "533mm G7a Torpedo",
	desc             = "Classic German U-boat torpedo. Fast, heavy hitting, but not particularly advanced.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: N/A m/s",
	model            = "models/macc/Torpedo_G7A_Small.mdl",
	effect           = "ACE_TorpedoMedium",
	effectbooster    = "",
	gunclass         = "mNAV",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 250 * 2.53, --Convert to ammocrate units,
	caliber          = 15, --Unfortunately caliber determines the minimum length even above the max length var. For now has to be set lower than 1:1
	weight           = 1538,								-- Don't scale down the weight though!
	rofmod           = 0.3,
	year             = 1934,
	modeldiameter    = 15,
	bodydiameter     = 16, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/macc/Torpedo_G7A_Small.mdl",
		rackmdl				= "models/macc/Torpedo_G7A_Small.mdl",
		firedelay			= 0.5,
		reloadspeed			= 6.0,
		reloaddelay			= 25.0,

		maxlength			= 250,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm
		turnrate			= 2,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.5,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 150,							-- Acceleration in m/s.
		burntime			= 120,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 40,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.001,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		waterthrusttype 	= 4, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
		buoyancy			= 1,
		pointcost			= 1000,
	},

	ent		= "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb","Straight_Running"},
	fuses	= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["6xSmallTorpedo"] = true,
					["5xSmallTorpedo"] = true,
					["4xSmallTorpedo"] = true,
					["3xSmallTorpedo"] = true,
					["2xSmallTorpedo"] = true,
					["1xSmallTorpedo"] = true
				},

	seekcone   = 25,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone   = 50,								-- getting outside this cone will break the lock.  Divided by 2.

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15								-- minimum fuse arming delay		--was 0.4
} )

ACF_defineGun("Scaled Mk13 Torp", {						-- id
	name             = "570mm Mk 13 Torpedo",
	desc             = "One of the most common aerial torpedoes of WW2. Used by the US. Has claimed many capital ships.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: N/A m/s",
	model            = "models/macc/Torpedo_MK13_Small.mdl",
	effect           = "ACE_TorpedoMedium",
	effectbooster    = "",
	gunclass         = "mNAV",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 125 * 2.53, --Convert to ammocrate units,
	caliber          = 15, --Unfortunately caliber determines the minimum length even above the max length var. For now has to be set lower than 1:1
	weight           = 1942,								-- Don't scale down the weight though!
	rofmod           = 0.3,
	year             = 2015,
	modeldiameter    = 15,
	bodydiameter     = 16, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/macc/Torpedo_MK13_Small.mdl",
		rackmdl				= "models/macc/Torpedo_MK13_Small.mdl",
		firedelay			= 0.5,
		reloadspeed			= 6.0,
		reloaddelay			= 25.0,

		maxlength			= 100,							-- Length of missile. Used for ammo properties.
		propweight			= 0.001,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm
		turnrate			= 16,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.5,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 60,							-- Acceleration in m/s.
		burntime			= 120,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 130,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.001,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.
		waterthrusttype 	= 4, 	--0-stops underwater, 1-booster only underwater - DEFAULT, 2-works above and below, 3-underwater only, 4-booster all and under thrust only
		buoyancy			= 1,
		pointcost			= 750,
	},

	ent		= "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb","Straight_Running"},
	fuses	= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true
				},

	seekcone   = 45,								-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone   = 45,								-- getting outside this cone will break the lock.  Divided by 2.

	ghosttime  = 0.2,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay           = 0.15								-- minimum fuse arming delay		--was 0.4
} )

ACF_defineGun("Scaled 9M317ME SAM", {							-- id
	name             = "9M317ME Navalized BUK",
	desc             = "Get. Out. Of. MY. Airspace. Navalized version of the BUK often carried by cruisers. Perfect to designate a no-fly zone. Fast beyond belief and still decently maneuverable. \n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: Yes\nTop Speed: 273 m/s",
	model            = "models/macc/9M317ME_open_small.mdl",
	effect           = "ACE_MissileLarge",
	effectbooster	 = "ACE_MissileLarge",
	gunclass         = "mNAV",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 200 * 2.53, --Convert to ammocrate units
	caliber          = 20,								--Actual is 380. Had to reduce caliber because of shell customization ratio limits preventing not having a shell smaller than 50cm and thus having a huge warhead
	weight           = 1040,								-- Don't scale down the weight though!
	year             = 1981,
	modeldiameter    = 15,--Already in ammocrate units
	bodydiameter     = 10, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/macc/9M317ME_open_small.mdl",
		rackmdl				= "models/macc/9m317me_folded.mdl",
		firedelay			= 1.0,
		reloadspeed			= 10,
		reloaddelay			= 45.0,


		maxlength			= 111.8,							-- Length of missile. Used for ammo properties.
		propweight			= 15,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm
								--320
		turnrate			= 2,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 1.0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 60,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 165,							-- Acceleration in m/s.
		--120 seconds? Does it really have a 120 second burntime??? Not setting higher so people can't minimize proppelant
		burntime			= 15,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 20,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 4,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 19,							--Time in seconds after launch/booster stop before missile scuttles

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
	["1xRK"] = true,
	["1xmVLS"] = true,
	["4xmVLS"] = true
	},					-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)  --was 4
	viewcone           = 60,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 1,
	irccm				= true,

	agility            = 3,									-- multiplier for missile turn-rate.  --was 0.7
	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3
	guidelay           = 0.5,								-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.05									-- Time where this missile will be unable to hit surfaces, in seconds
} )

ACF_defineGun("Scaled 5V55 SAM", {							-- id
	name             = "5V55 S-300 SAM",
	desc             = "Ultimate Long range SAM. Extreme range, Maneuverable, and F A S T. \n\nInertial Guidance: Yes\nECCM: Yes\nDatalink: Yes\nTop Speed: 273 m/s",
	model            = "models/missiles/5v55_small.mdl",
	effect           = "ACE_MissileLarge",
	effectbooster	 = "ACE_RocketBlackSmoke",
	gunclass         = "mNAV",
	rack             = "1xRK",							-- Which rack to spawn this missile on?
	length           = 200 * 2.53, --Convert to ammocrate units
	caliber          = 20,								--Actual is 514. Had to reduce caliber because of shell customization ratio limits preventing not having a shell smaller than 50cm and thus having a huge warhead
	weight           = 1480,								-- Don't scale down the weight though!
	year             = 1981,
	modeldiameter    = 15,--Already in ammocrate units
	bodydiameter     = 20, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/missiles/5v55_small.mdl",
		rackmdl				= "models/missiles/5v55_small.mdl",
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
		["1xRK"] = true,
		["1xmVLS"] = true,
		["4xmVLS"] = true
	},					-- a whitelist for racks that this missile can load into.  can also be a 'function(bulletData, rackEntity) return boolean end'

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)  --was 4
	viewcone           = 60,								-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 1,
	irccm				= true,

	agility            = 3,									-- multiplier for missile turn-rate.  --was 0.7
	armdelay           = 0.15,								-- minimum fuse arming delay --was 0.3
	guidelay           = 0.5,								-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.05									-- Time where this missile will be unable to hit surfaces, in seconds
} )