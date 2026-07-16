--define the class
ACF_defineGunClass("HMG", {
	type = "Gun",
	spread = 0.17,
	name = "Heavy Machinegun",
	desc = ACFTranslation.GunClasses[7],
	muzzleflash = "MG",
	rofmod = 0.16,
	year = 1935,
	sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
	noloader = true,

	longbarrel = {
		index = 2,
		submodel = 4,
		newpos = "muzzle2"
	}
} )

ACF_defineGun("30mmHMGShort", {
	name = "Shortened 30mm Heavy Machinegun",
	desc = "30mm shell chucker, light and compact. Great for lobbing mid sized HE shells at infantry.",
	model = "models/machinegun/machinegun_30mm_compact.mdl",
	sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
	gunclass = "HMG",
	caliber = 3.01,
	weight = 140,
	year = 1941,
	rofmod = 0.55, --at 1.05, 495rpm;
	round = {
		maxlength = 25,
		propweight = 0.03
	},
	acepoints = 150
} )

ACF_defineGun("40mmHMGShort", {
	name = "Shortened 40mm Heavy Machinegun",
	desc = "The heaviest of the heavy machineguns. Lobs low velocity shells at a decent rof for its weight.",
	model = "models/machinegun/machinegun_40mm_compact.mdl",
	sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
	gunclass = "HMG",
	caliber = 4.0,
	weight = 205,
	year = 1955,
	rofmod = 0.45, --at 0.75, 455rpm
	round = {
		maxlength = 32,
		propweight = 0.12
	},
	acepoints = 300
} )

--add a gun to the class
ACF_defineGun("20mmHMG", {
	name = "20mm Heavy Machinegun",
	desc = "The lightest of the HMGs, the 20mm has a rapid fire rate but suffers from poor payload size.  Often used to strafe ground troops or annoy low-flying aircraft.",
	model = "models/machinegun/machinegun_20mm_compact.mdl",
	sound = "ace_weapons/multi_sound/20mm_hmg_multi.mp3",
	gunclass = "HMG",
	caliber = 2.0,
	weight = 80,
	year = 1935,
	rofmod = 0.6, --at 1.5, 675rpm; at 2.0, 480rpm
	magsize = 60,
	magreload = 5,
	round = {
		maxlength = 32,
		propweight = 0.13
	},
	acepoints = 200
} )

ACF_defineGun("30mmHMG", {
	name = "30mm Heavy Machinegun",
	desc = "30mm shell chucker, light and compact. Your average cold war dogfight go-to.",
	model = "models/machinegun/machinegun_30mm_compact.mdl",
	sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
	gunclass = "HMG",
	caliber = 3.0,
	weight = 150,
	year = 1941,
	rofmod = 0.4, --at 1.05, 495rpm;
	magsize = 50,
	magreload = 6,
	round = {
		maxlength = 39,
		propweight = 0.35
	},
	acepoints = 300
} )

ACF_defineGun("40mmHMG", {
	name = "40mm Heavy Machinegun",
	desc = "The heaviest of the heavy machineguns.  Massively powerful with a killer reload and hefty ammunition requirements, it can pop even relatively heavy targets with ease.",
	model = "models/machinegun/machinegun_40mm_compact.mdl",
	sound = "ace_weapons/multi_sound/30mm_hmg_multi.mp3",
	gunclass = "HMG",
	caliber = 4.0,
	weight = 300,
	year = 1955,
	rofmod = 0.47, --at 0.75, 455rpm
	magsize = 35,
	magreload = 7,
	round = {
		maxlength = 45,
		propweight = 0.9
	},
	acepoints = 450
} )
