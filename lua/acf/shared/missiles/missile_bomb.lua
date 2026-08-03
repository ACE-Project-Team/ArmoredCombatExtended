--define the class
ACE.DefineGunClass("BOMB", {
	type           = "missile",  -- i know i know
	spread         = 1,
	name           = "[Bomb] - General Purpose Bomb",
	desc           = ACE.Translation.MissileClasses[5],
	muzzleflash    = "40mm_muzzleflash_noscale",
	rofmod         = 0.1,
	year           = 1915,
	sound          = "acf_extra/tankfx/clunk.wav",
	soundDistance  = " ",
	soundNormal    = " ",
	nothrust       = true,

	reloadmul      = 8
} )


-- Balance the round in line with the 40mm pod rocket.
ACE.DefineGun("50kgBOMB", {						-- id
	name             = "50kg Free Falling Bomb",
	desc             = "Old 100lb bomb, most effective vs exposed infantry and light trucks.",
	model            = "models/bombs/fab50.mdl",
	gunclass         = "BOMB",
	rack             = "3xRK",					-- Which rack to spawn this missile on?
	length           = 90,
	caliber          = 5.0,
	weight           = 50,						-- Don't scale down the weight though!
	year             = 1915,
	modeldiameter    = 11.15,					-- in cm

	round = {
		rocketmdl			= "models/bombs/fab50.mdl",
		rackmdl				= "models/bombs/fab50.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 30.0,
		inaccuracy			= 2.0,

		maxlength			= 600,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0015,						-- percent speed loss per second


		penmul      = math.sqrt(0.05),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
				["1xRK_small"] = true,
				["1xRK"] = true,
				["2xRK"] = true,
				["3xRK"] = true,
				["4xRK"] = true
			},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
} )


ACE.DefineGun("100kgBOMB", {						-- id
	name             = "100kg Free Falling Bomb",
	desc             = "An old 250lb WW2 bomb, as used by Soviet bombers to destroy enemies of the Motherland.",
	model            = "models/bombs/fab100.mdl",
	gunclass         = "BOMB",
	rack             = "1xRK",					-- Which rack to spawn this missile on?
	length           = 106,
	caliber          = 10.0,
	weight           = 100,						-- Don't scale down the weight though!
	year             = 1939,
	modeldiameter    = 13,				-- in cm

	round = {
		rocketmdl			= "models/bombs/fab100.mdl",
		rackmdl				= "models/bombs/fab100.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 45.0,
		inaccuracy			= 2.0,

		maxlength			= 400,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0025,						-- percent speed loss per second


		penmul      = math.sqrt(0.3),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
					["1xRK_small"] = true,
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true
				},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
} )

ACE.DefineGun("250kgBOMB", {						-- id
	name             = "250kg Free Falling Bomb",
	desc             = "A heavy 500lb bomb, widely used as a tank buster on various WW2 aircraft.",
	model            = "models/bombs/fab250.mdl",
	gunclass         = "BOMB",
	rack             = "1xRK",					-- Which rack to spawn this missile on?
	length           = 207,
	caliber          = 12.5,
	weight           = 250,						-- Don't scale down the weight though!
	year             = 1941,
	modeldiameter    = 15, -- in cm

	round = {
		rocketmdl			= "models/bombs/fab250.mdl",
		rackmdl				= "models/bombs/fab250.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 60.0,
		inaccuracy			= 2.0,

		maxlength			= 750,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.005,						-- percent speed loss per second


		penmul      = math.sqrt(0.3),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
				["1xRK_small"] = true,
				["1xRK"] = true,
				["2xRK"] = true,
				["3xRK"] = true,
				["4xRK"] = true
			},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
} )

ACE.DefineGun("500kgBOMB", {						-- id
	name             = "500kg Free Falling Bomb",
	desc             = "A 1000lb bomb, as found in the heavy bombers of late WW2. Best used against fortifications or immobile targets.",
	model            = "models/bombs/fab500.mdl",
	gunclass         = "BOMB",
	rack             = "1xRK",					-- Which rack to spawn this missile on?
	length           = 210, --i know. Real one is too big for the largest of the ammocrates
	caliber          = 30,
	weight           = 500,						-- Don't scale down the weight though!
	year             = 1943,
	modeldiameter    = 18,				-- in cm

	round = {
		rocketmdl			= "models/bombs/fab500.mdl",
		rackmdl				= "models/bombs/fab500.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 80.0,
		inaccuracy			= 2.0,

		maxlength			= 300,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 50,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.0075,						-- percent speed loss per second


		penmul      = math.sqrt(0.3),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
				["1xRK"] = true,
				["2xRK"] = true
			},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
} )

ACE.DefineGun("1000kgBOMB", {					-- id
	name             = "1000kg Free Falling Bomb",
	desc             = "A 2000lb bomb. Nothing is surviving the blast of this one, this munition will turn everything it touches to ashes. Handle with care.",
	model            = "models/bombs/an_m66.mdl",
	gunclass         = "BOMB",
	rack             = "1xRK",					-- Which rack to spawn this missile on?
	length           = 227, --i know. Real one is too big for the largest of the ammocrates
	caliber          = 30,
	weight           = 1000,						-- Don't scale down the weight though!
	year             = 1945,
	modeldiameter    = 26,				-- in cm

	round = {
		rocketmdl			= "models/bombs/an_m66.mdl",
		rackmdl				= "models/bombs/an_m66.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 100.0,
		inaccuracy			= 2.0,

		maxlength			= 700,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 60,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.01,						-- percent speed loss per second


		penmul      = math.sqrt(0.3),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
				["1xRK"] = true
			},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
} )


ACE.DefineGun("Mk82Bomb", {						-- id
	name			= "MK-82 General Purpose Bomb",
	desc			= "Small low drag general purpose bomb. You can carry a lot of these.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No",
	model			= "models/bombs/gbu/gbu12.mdl",
	gunclass		= "BOMB",
	rack			= "1xRK",						-- Which rack to spawn this missile on?
	length			= 225,
	caliber			= 27.3,
	weight			= 215,							-- Don't scale down the weight though!
	year			= 1976,
	modeldiameter	= 12,					-- in cm
	bodydiameter     = 12.5, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/bombs/gbu/gbu12_fold.mdl",
		rackmdl				= "models/bombs/gbu/gbu12.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 60.0,
		inaccuracy			= 2.0,

		maxlength			= 850,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00075,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.




		penmul      = math.sqrt(0.1),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent		= "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses	= {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true
				},

	seekcone	= 2,							-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone	= 60,							-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00								-- minimum fuse arming delay
} )

ACE.DefineGun("Mk83Bomb", {						-- id
	name			= "MK-83 General Purpose Bomb",
	desc			= "Low drag general purpose bomb. Packs a sizable warhead perfect for nailing heavy targets.\n\nInertial Guidance: Yes\nECCM: No\nDatalink: No",
	model			= "models/bombs/gbu/gbu16.mdl",
	gunclass		= "BOMB",
	rack			= "1xRK",						-- Which rack to spawn this missile on?
	length			= 264,
	caliber		= 35.6,
	weight			= 425,							-- Don't scale down the weight though!
	year			= 1976,
	modeldiameter	= 13,					-- in cm
	bodydiameter     = 13.8, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/bombs/gbu/gbu16_fold.mdl",
		rackmdl				= "models/bombs/gbu/gbu16.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 80.0,
		inaccuracy			= 2.0,

		maxlength			= 830,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 30,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00075,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.


		penmul      = math.sqrt(0.15),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent		= "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses	= {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true
				},

	seekcone	= 2,							-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone	= 60,							-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime	= 0.5,							-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00								-- minimum fuse arming delay
} )

ACE.DefineGun("Mk84Bomb", {						-- id
	name			= "MK-84 General Purpose Bomb",
	desc			= "Low drag general purpose bomb with a massive warhead.\n\nInertial Guidance: No\nECCM: No\nDatalink: No",
	model			= "models/bombs/gbu/gbu10.mdl",
	gunclass		= "BOMB",
	rack			= "1xRK",						-- Which rack to spawn this missile on?
	length			= 320,
	caliber		= 45.7,
	weight			= 900,							-- Don't scale down the weight though!
	year			= 1976,
	modeldiameter	= 20,					-- in cm
	round = {
		rocketmdl			= "models/bombs/gbu/gbu10_fold.mdl",
		rackmdl				= "models/bombs/gbu/gbu10.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 100.0,
		inaccuracy			= 2.0,

		maxlength			= 1400,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 40,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00075,						-- percent speed loss per second
		inertialcapable		= true,							-- Whether missile is capable of inertial guidance. Inertially guided missiles will follow their last track after losing the target. And can be fired offbore outside their seeker's viewcone.
		predictiondelay		= 0.5,							-- Delay before enabling missile steering guidance. Missile will run straight at the aimpoint until this time. Done to cause missile to not self delete because it tries to steer its velocity at launch.


		penmul      = math.sqrt(0.2),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent		= "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses	= {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {									-- a whitelist for racks that this missile can load into.'
					["1xRK"] = true,
					["2xRK"] = true
				},

	seekcone	= 2,							-- getting inside this cone will get you locked.  Divided by 2 ('seekcone = 40' means 80 degrees total.)
	viewcone	= 60,							-- getting outside this cone will break the lock.  Divided by 2.
	SeekSensitivity    = 5,

	ghosttime	= 0.5,							-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00								-- minimum fuse arming delay
} )

ACE.DefineGun("100kgGBOMB", {					-- id
	name             = "100kg Glide Bomb",
	desc             = "A 250-pound bomb, fitted with fins for a longer reach.  Well suited to dive bombing, but bulkier and heavier from its fins.",
	model            = "models/missiles/micro.mdl",
	gunclass         = "BOMB",
	rack             = "1xRK",					-- Which rack to spawn this missile on?
	length           = 121,
	caliber          = 10.0,
	weight           = 150,						-- Don't scale down the weight though!
	year             = 1939,
	modeldiameter    = 13,				-- in cm

	round = {
		rocketmdl			= "models/missiles/micro.mdl",
		rackmdl				= "models/missiles/micro.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 35.0,
		inaccuracy			= 2.0,

		maxlength			= 400,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.45,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00075,						-- percent speed loss per second


		penmul      = math.sqrt(0.3),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
				["1xRK_small"] = true,
				["1xRK"] = true,
				["2xRK"] = true,
				["3xRK"] = true,
				["4xRK"] = true
			},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
})


ACE.DefineGun("250kgGBOMB", {					-- id
	name             = "250kg Glide Bomb",
	desc             = "A heavy 500lb bomb, fitted with fins for a gliding trajectory better suited to striking point targets.",
	model            = "models/bombs/glide250.mdl",
	gunclass         = "BOMB",
	rack             = "1xRK",					-- Which rack to spawn this missile on?
	length           = 165,
	caliber          = 12.5,
	weight           = 375,						-- Don't scale down the weight though!
	year             = 1941,
	modeldiameter    = 15.29,				-- in cm
	bodydiameter     = 16.5, -- If this ordnance has fixed fins. Add this to count the body without finds, to ensure the missile will fit properly on the rack (doesnt affect the ammo dimension)

	round = {
		rocketmdl			= "models/bombs/glide250.mdl",
		rackmdl				= "models/bombs/glide250.mdl",
		firedelay			= 0.1,
		reloadspeed			= 0.3,
		reloaddelay			= 50.0,
		inaccuracy			= 2.0,

		maxlength			= 750,							-- Length of missile. Used for ammo properties.
		propweight			= 0,							-- Motor mass - motor casing. Used for ammo properties.

		armour				= 25,							-- Armour effectiveness of casing, in mm

		turnrate			= 0,							--Turn rate of missile at max deflection per 100 m/s
		finefficiency		= 0.45,							--Fraction of speed redirected every second at max deflection
		thrusterturnrate	= 0,							--Max turnrate from thrusters regardless of speed. Active only if the missile motor is active.

		fusetime			= 20,							--Time in seconds after launch/booster stop before missile scuttles

		dragcoef			= 0.00075,						-- percent speed loss per second


		penmul      = math.sqrt(0.3),			-- HEAT velocity multiplier. Squared relation to penetration (math.sqrt(2) means 2x pen)
		calmul			= 1,	--Adjust this first. Used to balance the damage of kinetic missiles. Multiplier for the projectile caliber. Won't affect HEAT.
		velmul			= 2,		--Used to balance the penetration of kinetic missiles. Multiplier for the velocity of the projectile on impact.
	},

	ent        = "acf_missile_to_rack",			-- A workaround ent which spawns an appropriate rack for the missile.
	guidance   = {"Dumb"},
	fuses      = {"Contact", "Optical", "Timed", "Altitude"},

	racks	= {								-- a whitelist for racks that this missile can load into.
					["1xRK_small"] = true,
					["1xRK"] = true,
					["2xRK"] = true,
					["3xRK"] = true,
					["4xRK"] = true
				},

	ghosttime	= 0.5,									-- Time where this missile will be unable to hit surfaces, in seconds
	armdelay	= 0.00							-- minimum fuse arming delay
} )
