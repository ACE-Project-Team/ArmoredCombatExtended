ACF_defineGunClass("ATGM", {
	type			= "missile",
	spread			= 1,
	name			= "[ATGM] - Anti-Tank Guided Missile",
	desc			= ACFTranslation.MissileClasses[4],
	muzzleflash		= "40mm_muzzleflash_noscale",
	rofmod			= 1,
	sound			= "acf_extra/airfx/rocket_fire2.wav",
	year			= 1969,
	soundDistance	= " ",
	soundNormal		= " ",
	effect			= "Rocket Motor ATGM",
	reloadmul		= 5,
	guidanceInac	= 1,  -- How much inaccuracy this missile will have when its being guided. Note that this is a squared relation. Meaning that 20 inac means 40 units in total. Deal about it
} )

-- The BGM-71E, a wire guided missile with medium anti-tank effectiveness.
ACF_defineGun("BGM-71E ASM", {								-- id
	name			= "BGM-71E Missile",
	desc			= "The BGM-71E missile is a lightweight, wire guided anti-tank munition. It can be used in both air-to-surface and surface-to-surface combat, making it a decent alternative for ground vehicles.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 181 m/s\nMax Kinetic Pen: 602 mm",
	model			= "models/missiles/bgm_71e.mdl",
	effect			= "Rocket Motor ATGM",
	effectbooster	= "ACE_MissileSmall",
	gunclass		= "ATGM",
	rack			= "1x BGM-71E",								-- Which rack to spawn this missile on?
	length			= 123,										-- Used for the physics calculations
	caliber			= 15.2,
	weight			= 76.4,										-- Don't scale down the weight though!
	year			= 1970,
	modeldiameter	= 3 * 2.54,

	round = {
		rocketmdl			= "models/missiles/bgm_71e.mdl",
		rackmdl				= "models/missiles/bgm_71e.mdl",
		firedelay			= 2,
		reloadspeed			= 6,
		reloaddelay			= 13.0,

		maxlength			= 105,							-- Length of missile. Used for ammo properties.
		propweight			= 1.2,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 15,							-- Armour effectiveness of casing, in mm

		turnrate			= 25,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.35,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 10,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 90,							-- Acceleration in m/s.
		burntime			= 9,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 30,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 60,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.003,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(0.9265),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.3,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.

	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Wire", "Beam_Riding"},
	fuses		= {"Contact", "Optical", "Timed", "Altitude", "Plunging"},

	racks	= {											-- a whitelist for racks that this missile can load into.
					["1x BGM-71E"] = true,
					["2x BGM-71E"] = true,
					["4x BGM-71E"] = true
				},


	viewcone		= 90,										-- getting outside this cone will break the lock.  Divided by 2.

	ghosttime		= 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.15										-- minimum fuse arming delay
} )

ACF_defineGun("9M113 ATGM", {									-- id
	name			= "9M113 Konkurs Missile",
	desc			= "The tube-launched Konkurs is a solid ATGM all around. With a decent speed, maneuverability, and warhead.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 108 m/s\nMax Kinetic Pen: 409 mm",
	model			= "models/missiles/9m113.mdl",
	effect			= "Rocket Motor ATGM",
	effectbooster	= "Rocket Motor ATGM",
	gunclass		= "ATGM",
	rack			= "1x 9M113",							-- Which rack to spawn this missile on?
	length			= 51 * 2.53, --Convert to ammocrate units
	caliber			= 13.5,
	weight			= 14.6,									-- Don't scale down the weight though!
	year			= 1970,
	modeldiameter	= 6, --Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/9m113.mdl",
		rackmdl				= "models/missiles/arend/9m113_folded.mdl",
		firedelay			= 0.5,
		reloadspeed			= 6.0,
		reloaddelay			= 12.0,

		maxlength			= 105,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 15,							-- Armour effectiveness of casing, in mm

		turnrate			= 5,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 1.0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 30,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 37,							-- Acceleration in m/s.
		burntime			= 8,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 10,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 600,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.05,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0035,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(0.7),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.4,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 3,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Wire", "Beam_Riding"},
	fuses		= {"Contact", "Optical", "Timed", "Altitude"},



	racks	= {											-- a whitelist for racks that this missile can load into.
					["1x 9M113"] = true
			},

	viewcone		= 25,										-- getting outside this cone will break the lock.  Divided by 2.

	armdelay	= 0.15										-- minimum fuse arming delay
} )

ACF_defineGun("9M133 ASM", {									-- id
	name			= "9M133 Kornet Missile",
	desc			= "The Kornet is a modern antitank missile, with good range and a very powerful warhead, but somewhat limited maneuverability.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 153 m/s\nMax Kinetic Pen: 802 mm",
	model			= "models/kali/weapons/kornet/parts/9m133 kornet missile.mdl",
	effect			= "Rocket Motor ATGM",
	effectbooster	= "Rocket Motor ATGM",
	gunclass		= "ATGM",
	rack			= "1x Kornet",							-- Which rack to spawn this missile on?
	length			= 130,
	caliber			= 15.2,
	weight			= 29,									-- Don't scale down the weight though!
	year			= 1994,
	modeldiameter	= 3 * 2.54, -- in cm

	round = {
		rocketmdl			= "models/kali/weapons/kornet/parts/9m133 kornet missile.mdl",
		rackmdl				= "models/kali/weapons/kornet/parts/9m133 kornet missile.mdl",
		firedelay			= 4,
		reloadspeed			= 6.0,
		reloaddelay			= 16.0,

		maxlength			= 105,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 20,							-- Armour effectiveness of casing, in mm

		turnrate			= 3,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.5,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 15,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 55,							-- Acceleration in m/s.
		burntime			= 12,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 10,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 300,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0025,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.37),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.5,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 4,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.

	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Laser", "Beam_Riding"},
	fuses		= {"Contact", "Optical", "Timed", "Altitude"},



	racks	= {											-- a whitelist for racks that this missile can load into.
					["1x Kornet"] = true,
					["2x Kornet"] = true,
					["4x Kornet"] = true
			},

	viewcone		= 25,										-- getting outside this cone will break the lock.  Divided by 2.

	armdelay	= 0.15										-- minimum fuse arming delay
} )

-- The AT-3, a short-range wire-guided missile with better anti-tank effectiveness than the BGM-71E but much slower.
ACF_defineGun("AT-3 ASM", { --id
	name			= "AT-3 Sagger Missile",
	desc			= "The AT-3 missile (9M14P1) is a short-range wire-guided anti-tank munition. While powerful and lightweight its speed will make you die of old age before you hit the target.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 52 m/s\nMax Kinetic Pen: 430 mm",
	model			= "models/missiles/at3.mdl",
	effect			= "ACE_MotorTiny",
	effectbooster	= "ACE_MotorTiny",
	gunclass		= "ATGM",
	rack			= "1xAT3RK",									-- Which rack to spawn this missile on?
	length			= 84,										-- Used for the physics calculations
	caliber			= 12.5,
	weight			= 12.5,										-- Don't scale down the weight though!
	year			= 1969,
	modeldiameter	= 3 * 2.54,
	bodydiameter     = 7, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl				= "models/missiles/at3.mdl",
		rackmdl				= "models/missiles/at3.mdl",
		firedelay			= 2,
		reloadspeed			= 5,
		reloaddelay			= 10.0,

		maxlength			= 55,							-- Length of missile. Used for ammo properties.
		propweight			= 1.2,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 13,							-- Armour effectiveness of casing, in mm

		turnrate			= 30,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.7,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 60,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 13,							-- Acceleration in m/s.
		burntime			= 12,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 70,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.2,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.95),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.3,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 6,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.

	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Wire", "Beam_Riding"},
	fuses		= {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {											-- a whitelist for racks that this missile can load into.
					["1xAT3RKS"] = true,
					["1xAT3RK"] = true,
					["1xRK_small"] = true,
					["3xRK"] = true
				},

	skinindex	= {HEAT = 0, HE = 1},
	viewcone		= 60,										-- getting outside this cone will break the lock.  Divided by 2.

	agility			= 0.1, --0.3										-- multiplier for missile turn-rate.
	ghosttime		= 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds

	armdelay	= 0.15										-- minimum fuse arming delay
} )

ACF_defineGun("AT-2 ASM", { --id
	name			= "AT-2 Fleyta Missile",
	desc			= "The AT-2 Missile (9M17P) is a light and highly agile anti-tank missile, the big brother of the Sagger. While the warhead isn't as modernized to the extent of the AT-3 the agility and speed greatly make up for it\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 86 m/s\nMax Kinetic Pen: 438 mm",
	model			= "models/missiles/at2.mdl",
	effect			= "ACE_MotorTiny",
	effectbooster	= "ACE_MissileTiny",
	gunclass		= "ATGM",
	rack			= "1xRK",									-- Which rack to spawn this missile on?
	length			= 115,										-- Used for the physics calculations
	caliber			= 16,
	weight			= 27,										-- Don't scale down the weight though!
	year			= 1969,
	modeldiameter	= 2.8 * 2.54,

	round = {
		rocketmdl				= "models/missiles/at2.mdl",
		rackmdl				= "models/missiles/at2.mdl",
		firedelay			= 2,
		reloadspeed			= 16,
		reloaddelay			= 12.0,

		maxlength			= 55,							-- Length of missile. Used for ammo properties.
		propweight			= 1.2,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 15,							-- Armour effectiveness of casing, in mm

		turnrate			= 55,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.6,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 30,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 15,							-- Acceleration in m/s.
		burntime			= 14,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 95,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.2,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.55),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.3,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 5.25,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent				= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance		= {"Dumb", "Laser", "Wire", "Beam_Riding"},

	fuses			= {"Contact", "Optical", "Timed", "Altitude"},
	viewcone		= 90,										-- getting outside this cone will break the lock.  Divided by 2.
	racks			= {											-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true,
					["1xRK_small"] = true,
					["2x AGM-114"] = true,
					["4x AGM-114"] = true
					},
	ghosttime		= 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.15									-- minimum fuse arming delay
} )

ACF_defineGun("FGM-148 ASM", {
	name			= "FGM-148 Javelin Missile",
	desc			= "A powerful medium-range multi-purpose Missile, being extremely agile, its able to be used vs low altitude aircraft and for attacking top of tanks. But its somewhat slow.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: 125 m/s\nMax Kinetic Pen: 621 mm",
	model			= "models/mcace/Jevelinemissile.mdl",		-- model to spawn on menu
	effect			= "ACE_MotorSmall",
	effectbooster	= "ACE_MotorSmall",
	gunclass		= "ATGM",
	rack			= "1x Javelin",								-- Which rack to spawn this missile on?
	length			= 98,										-- Used for the physics calculations
	caliber			= 12.7,										-- caliber
	weight			= 11.8,										-- Don't scale down the weight though!  --was 97.2
	year			= 1989,										-- year
	modeldiameter	= 3 * 2.54,

	round = {
		rocketmdl			= "models/mcace/Jevelinemissile.mdl", --Why must you typo
		rackmdl				= "models/mcace/Jevelinemissile.mdl",
		firedelay			= 1.5,
		reloadspeed			= 10.0,
		reloaddelay			= 25.0,

		maxlength			= 110,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 13,							-- Armour effectiveness of casing, in mm

		turnrate			= 320,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.45,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 30,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 20,							-- Acceleration in m/s.
		burntime			= 6,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 25,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 140,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.1,							-- Time in seconds for booster runtime
		boostdelay			= 0.45,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0005,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.1),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.5,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 4,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent				= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance		= {"Dumb", "Infrared", "Top_Attack_IR"},				-- here you have Laser for those top attacks, feel free to build one.

	fuses			= {"Contact", "Optical", "Timed", "Altitude"},

	seekcone		= 1.5,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone		= 60,										-- getting outside this cone will break the lock.  Divided by 2.
	racks			= {											-- a whitelist for racks that this missile can load into.
					["1x Javelin"] = true
					},

	armdelay		= 1,										-- minimum fuse arming delay
	ghosttime		= 0.3,									-- Time where this missile will be unable to hit surfaces, in seconds
	SeekSensitivity    = 35

} )


ACF_defineGun("Spike-LR ASM", {
	name			= "Spike LR Missile",
	desc			= "A powerful multi-purpose Missile, being fast and agile but maneuverable enough to hit aircraft or tanks in top attack.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: Yes\nTop Speed: 141 m/s\nMax Kinetic Pen: 667 mm",
	model			= "models/missiles/spikelr2.mdl",		-- model to spawn on menu
	effect			= "ACE_MissileSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass		= "ATGM",
	rack			= "1x Javelin",								-- Which rack to spawn this missile on?
	length			= 67 * 2.53, --Convert to ammocrate units
	caliber			= 17,										-- Real diameter (170 mm).
	weight			= 13,										-- Don't scale down the weight though!  --was 97.2
	year			= 1997,										-- year
	modeldiameter	= 7,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/spikelr2.mdl",
		rackmdl				= "models/missiles/arend/spikelr_closed.mdl",
		firedelay			= 4,
		reloadspeed			= 10,
		reloaddelay			= 25.0,

		maxlength			= 60,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 13,							-- Armour effectiveness of casing, in mm

		turnrate			= 200,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 1.0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 55,							-- Acceleration in m/s.
		burntime			= 6,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 13,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 100,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.25,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.003,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= false,
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(2.5),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.5,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 7,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent				= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance		= {"Dumb", "Infrared", "Top_Attack_IR", "Laser"},				-- here you have Laser for those top attacks, feel free to build one.

	fuses			= {"Contact", "Optical", "Timed", "Altitude"},

	seekcone		= 1.5,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone		= 120,										-- getting outside this cone will break the lock.  Divided by 2.
	racks			= {									-- a whitelist for racks that this missile can load into.
						["1xRK"] = true,
						["2xRK"] = true,
						["3xRK"] = true,
						["4xRK"] = true,
						["1xRK_small"] = true,
						["2x AGM-114"] = true,
						["4x AGM-114"] = true
					},

	armdelay	= 0.15,										-- minimum fuse arming delay
	SeekSensitivity    = 40

} )

ACF_defineGun("Kh-39 LMUR", {
	name			= "Kh-39 LMUR Missile",
	desc			= "Description here please.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: Yes\nTop Speed: 141 m/s\nMax Kinetic Pen: 667 mm",
	model			= "models/missiles/unfolded_lmur.mdl",		-- model to spawn on menu
	effect			= "ACE_MissileSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass		= "ATGM",
	rack			= "1x Javelin",								-- Which rack to spawn this missile on?
	length			= 67 * 2.53, --Convert to ammocrate units
	caliber			= 20,										-- Real diameter (200 mm).
	weight			= 105,										-- Don't scale down the weight though!  --was 97.2
	year			= 2011,										-- year
	modeldiameter	= 7,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/unfolded_lmur.mdl",
		rackmdl				= "models/missiles/unfolded_lmur.mdl",
		firedelay			= 4,
		reloadspeed			= 10,
		reloaddelay			= 25.0,

		maxlength			= 100,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 13,							-- Armour effectiveness of casing, in mm

		turnrate			= 75,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 1,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 80,							-- Acceleration in m/s.
		burntime			= 6,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 115,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.25,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.005,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.1,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.35),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.2,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 4,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent				= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance		= {"Dumb", "Infrared", "Top_Attack_IR", "Laser"},				-- here you have Laser for those top attacks, feel free to build one.

	fuses			= {"Contact", "Optical", "Timed", "Altitude"},

	seekcone		= 1.5,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone		= 80,										-- getting outside this cone will break the lock.  Divided by 2.
	racks			= {									-- a whitelist for racks that this missile can load into.
						["1xRK"] = true,
						["2xRK"] = true,
						["3xRK"] = true,
						["4xRK"] = true,
						["1xRK_small"] = true,
						["2x AGM-114"] = true,
						["4x AGM-114"] = true
					},

	armdelay	= 0.15,										-- minimum fuse arming delay
	SeekSensitivity    = 40

} )
-- The 9M120 Ataka, a laser guided missile with high anti-tank effectiveness.
ACF_defineGun("Ataka ASM", { --id
	name			= "9M120 Ataka Missile",
	desc			= "The 9M120 Ataka is a high-speed anti tank missile used by soviet helicopters and ground vehicles.  It has very limited maneuverability but excellent range and speed, and can be armed with HE and HEAT warheads.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 288 m/s\nMax Kinetic Pen: 814 mm",
	model			= "models/missiles/9m120.mdl",
	effect			= "ACE_MotorSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass		= "ATGM",
	rack			= "1x Ataka",							-- Which rack to spawn this missile on?
	length			= 174,
	caliber			= 13,
	weight			= 45,									-- Don't scale down the weight though!
	year			= 1984,
	modeldiameter	= 3 * 2.54,

	round = {
		rocketmdl				= "models/missiles/9m120.mdl",
		rackmdl				= "models/missiles/9m120.mdl",
		firedelay			= 4,
		reloadspeed			= 6.0,
		reloaddelay			= 30.0,

		maxlength			= 105,							-- Length of missile. Used for ammo properties.
		propweight			= 1.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 21,							-- Armour effectiveness of casing, in mm

		turnrate			= 3,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.65,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 4,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 95,							-- Acceleration in m/s.
		burntime			= 7,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 130,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.25,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.001,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.2,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.134),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.2,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 1.18,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Laser", "Beam_Riding"},
	fuses		= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {											-- a whitelist for racks that this missile can load into.
					["1x Ataka"] = true,
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true
				},

	seekcone		= 20,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone		= 40,										-- getting outside this cone will break the lock.  Divided by 2

	armdelay	= 0.15										-- minimum fuse arming delay
} )

-- The AGM-114, a laser guided missile with high anti-tank effectiveness.
ACF_defineGun("AGM-114 ASM", {						--id
	name 			= "AGM-114 Hellfire Missile",
	desc 			= "The AGM-114 Hellfire is an air-to-surface missile first developed for anti-armor use, but later models were developed for precision strikes against other target types. Bringer of Hell.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No\nTop Speed: 232 m/s\nMax Kinetic Pen: 607 mm",
	model 			= "models/missiles/agm_114.mdl",
	effect			= "ACE_MotorSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass 		= "ATGM",
	rack 			= "2x AGM-114",					-- Which rack to spawn this missile on?
	length 			= 163,
	caliber 		= 17.8,
	weight 			= 45,							-- Don't scale down the weight though!
	modeldiameter	= 3 * 2.54,					-- in cm
	bodydiameter	= 8.5, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)
	year			= 1985,

	round = {
		rocketmdl			= "models/missiles/agm_114.mdl",
		rackmdl				= "models/missiles/agm_114.mdl",
		firedelay			= 4,
		reloadspeed			= 6.0,
		reloaddelay			= 40.0,

		maxlength			= 150,							-- Length of missile. Used for ammo properties.
		propweight			= 1,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 21,							-- Armour effectiveness of casing, in mm

		turnrate			= 5,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.4,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 7,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 70,							-- Acceleration in m/s.
		burntime			= 3.55,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 20,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 0,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0005,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul				= math.sqrt(0.59),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 0.5,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 1.75,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",				-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "Laser", "Radar"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["2x AGM-114"] = true,
					["4x AGM-114"] = true,
					["1xmVLS"] = true,
					["4xmVLS"] = true

				},

	seekcone   = 2.0,
	viewcone   = 30,								-- getting outside this cone will break the lock.  Divided by 2.
	groundclutterfactor = 0,						--Disables radar ground clutter for millimeter wave radar guidance.

	armdelay   = 0.00								-- minimum fuse arming delay
} )

-- The 9M120 Ataka, a laser guided missile with high anti-tank effectiveness.
ACF_defineGun("Vikhr ASM", { --id
	name			= "9K121 Vikhr Missile",
	desc			= "The 9K121 Vikhr is a long range anti tank missile used by soviet helicopters. Slower in comparison to the Ataka, this missile is more maneuverable. Can utilize proxy fuses.\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 748 m/s\nMax Kinetic Pen: 721 mm",
	model			= "models/missiles/9m127.mdl",
	effect			= "ACE_MotorSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass		= "ATGM",
	rack			= "6x 9K121",							-- Which rack to spawn this missile on?
	length			= 112 * 2.53, --Convert to ammocrate units
	caliber			= 13,
	weight			= 198,									-- Don't scale down the weight though!
	year			= 1984,
	modeldiameter	= 6,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/9m127.mdl",
		rackmdl				= "models/missiles/arend/9k121_folded.mdl",
		firedelay			= 3,
		reloadspeed			= 6.0,
		reloaddelay			= 30.0,

		maxlength			= 105,							-- Length of missile. Used for ammo properties.
		propweight			= 1.7,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 21,							-- Armour effectiveness of casing, in mm

		turnrate			= 2,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.5,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 3,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 115,							-- Acceleration in m/s.
		burntime			= 5,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 50,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 50,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.1,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.001,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.2,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(1.148),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.2,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 1,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Laser"},
	fuses		= {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks	= {											-- a whitelist for racks that this missile can load into.
					["6x 9K121"] = true
				},

	seekcone		= 20,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone		= 40,										-- getting outside this cone will break the lock.  Divided by 2.

	armdelay	= 0.15										-- minimum fuse arming delay
} )


ACF_defineGun("MGM-166", { --id
	name			= "MGM-166 LOSAT",
	desc			= "You ever just wake up one day and want to pen 2 meters of armor? Couldn't be me. Stupidly fast and unyieldy. But if it hits have mercy. Getting hit is a significant emotional event\n\nInertial Guidance: No\nECCM: No\nDatalink: No\nTop Speed: 548 m/s\nMax Kinetic Pen: YES!!\n\n\nI should also mention, NO the ammo is not bugged. I had to do some antics to prevent tanks from getting sent to space when hit.",
	model			= "models/missiles/losat.mdl",
	effect			= "ACE_MotorMedium",
	effectbooster	= "ACE_MissileMedium",
	gunclass		= "ATGM",
	rack			= "6xUARRK",							-- Which rack to spawn this missile on?
	length			= 174,
	caliber			= 16.2,
	weight			= 79,									-- Don't scale down the weight though!
	year			= 1984,
	modeldiameter	= 3 * 2.54,

	round = {
		rocketmdl			= "models/missiles/losat.mdl",
		rackmdl				= "models/missiles/losat.mdl",
		firedelay			= 0.5,
		reloadspeed			= 6.0,
		reloaddelay			= 30.0,

		maxlength			= 1,							-- Length of missile. Used for ammo properties.
		minprojlength		= 1,							-- Explicitly pin LOSAT's custom compact projectile layout.
		propweight			= 0.001,						-- Motor mass - motor casing. Used for ammo properties.

		armour				= 21,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.65,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 35,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		thrust				= 250,							-- Acceleration in m/s.
		burntime			= 7,							-- time in seconds for rocket motor to burn at max proppelant.
		startdelay			= 0,

		launchkick			= 10,							-- Speed missile starts with on launch in m/s

		--Technically if you were crazy you could use boost instead of your rocket motor to get thrust independent of burn. Maybe on torpedoes.

		boostacceleration	= 100,							-- Acceleration in m/s of boost motor. Main Engine is not burning at this time.
		boostertime			= 0.5,							-- Time in seconds for booster runtime
		boostdelay			= 0,							-- Delay in seconds before booster activates.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00001,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.05,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.

		penmul			= math.sqrt(0.1),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
		calmul			= 0.000675,	--I guess it was a little too good at transfering energy. Increasing the velocitymul(energy limit) sent tanks to space
		velmul			= 0.02,
	},

	ent			= "acf_missile_to_rack",						-- A workaround ent which spawns an appropriate rack for the missile.
	guidance	= {"Dumb", "Beam_Riding"},
	fuses		= {"Contact"},

	racks	= {											-- a whitelist for racks that this missile can load into.
					["6xUARRK"] = true
				},

	seekcone		= 20,										-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)	--was 25
	viewcone		= 40,										-- getting outside this cone will break the lock.  Divided by 2

	armdelay	= 0.15										-- minimum fuse arming delay
} )

ACF_defineGun("MIM-146", {										-- id
	name             = "MIM-146 ADATS",
	desc             = "Wicked surface to air missile doubling as an anti tank missile. For torturing tanks when you have nothing else to shoot at. \n\nInertial Guidance: False\nECCM: No\nDatalink: Yes\nTop Speed: 178 m/s",
	model            = "models/missiles/mim146.mdl",
	effect           = "ACE_MissileSmall",
	effectbooster	= "ACE_MissileSmall",
	gunclass         = "ATGM",
	rack             = "1x VT-1",								-- Which rack to spawn this missile on?
	length           = 92 * 2.53, --Convert to ammocrate units
	caliber          = 15.2,
	weight           = 51,										-- Don't scale down the weight though!
	year             = 1960,
	modeldiameter    = 8,--Already in ammocrate units

	round = {
		rocketmdl			= "models/missiles/mim146.mdl",
		rackmdl				= "models/missiles/arend/vt1_folded.mdl",
		--rackmdl				= "models/missiles/mim146_folded.mdl",
		firedelay			= 0.75,
		reloadspeed			= 5.0,
		reloaddelay			= 30.0,

		--Formerly 190 and 1. Reduced blast from 213j to 120Mj. For reference a 100kg bomb has 117Kj.
		maxlength			= 145,							-- Length of missile. Used for ammo properties.
		propweight			= 5,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 70,							--Turn rate of missile at max deflection per 100 m/s
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
		velmul				= 0.1,		--No

		dragcoef			= 0.002,						-- percent speed loss per second
		inertialcapable		= false,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		datalink			= true,
		predictiondelay		= 0.25,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.


		penmul			= math.sqrt(0.57),					-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)	--was 0.797
	},

	ent        = "acf_missile_to_rack",					-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb", "Beam_Riding", "Semiactive"},
	fuses      = {"Contact", "Overshoot", "Radio", "Optical", "Timed", "Altitude"},

	racks = {										-- a whitelist for racks that this missile can load into.
				["1x VT-1"] = true
			},

	seekcone           = 6,									-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone           = 70,									-- getting outside this cone will break the lock.  Divided by 2.

	armdelay	= 0.15,									-- minimum fuse arming delay
	guidelay           = 0,									-- Required time (in seconds) for missile to start guiding at target once launched
	ghosttime          = 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	SeekSensitivity    = 2
} )
