--define the class
ACF_defineGunClass("AL", {
	type = "Gun",
	spread = 0.12,
	name = "Autoloader",
	desc = ACFTranslation.GunClasses[3],
	muzzleflash = "C",
	rofmod = 0.64,
	year = 1946,
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	noloader = true,
} )

--add a gun to the class
ACF_defineGun("50mmAL", { --id
	name = "50mm Drum Autoloader",
	desc = "A lightweight bullet spitting monster found on certain ground attack planes. Capable of rapidly filling targets with many high pen darts.",
	model = "models/tankgun/tankgun_al_50mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	gunclass = "AL",
	caliber = 5,
	weight = 850,
	year = 1946,
	rofmod = 0.8,
	magsize = 12,
	magreload = 20,
	round = {
		maxlength = 63,
		propweight = 2.1
	},
} )

--add a gun to the class
ACF_defineGun("75mmAL", { --id
	name = "75mm Drum Autoloader",
	desc = "A quick-firing 75mm gun, pops off a number of rounds in relatively short order.",
	model = "models/tankgun/tankgun_al_75mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	gunclass = "AL",
	caliber = 7.5,
	weight = 980,
	year = 1946,
	rofmod = 0.7,
	magsize = 12,
	magreload = 30,
	round = {
		maxlength = 78,
		propweight = 3.8
	},
} )

ACF_defineGun("100mmAL", {
	name = "100mm Drum Autoloader",
	desc = "The 100mm is good for rapidly hitting medium armor, then running like your ass is on fire to reload.",
	model = "models/tankgun/tankgun_al_100mm.mdl",
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	gunclass = "AL",
	caliber = 10.0,
	weight = 1800,
	year = 1956,
	rofmod = 0.7,
	magsize = 12,
	magreload = 35,
	round = {
		maxlength = 93,
		propweight = 20
	},
} )

ACF_defineGun("120mmAL", {
	name = "120mm Drum Autoloader",
	desc = "The 120mm autoloader can do serious damage before reloading, but the reload time is killer.",
	model = "models/tankgun/tankgun_al_120mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	gunclass = "AL",
	caliber = 12.0,
	weight = 2700,
	year = 1956,
	rofmod = 0.7,
	magsize = 12,
	magreload = 35,
	round = {
		maxlength = 115,
		propweight = 30
	},
} )

ACF_defineGun("140mmAL", {
	name = "140mm Drum Autoloader",
	desc = "The 140mm can shred a medium tank's armor with one magazine, and even function as shoot & scoot artillery, with its useful HE payload.",
	model = "models/tankgun/tankgun_al_140mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	gunclass = "AL",
	caliber = 14.0,
	weight = 4800,
	year = 1970,
	rofmod = 0.7,
	magsize = 12,
	magreload = 40,
	round = {
		maxlength = 140,
		propweight = 60
	},
} )


ACF_defineGun("170mmAL", {
	name = "170mm Drum Autoloader",
	desc = "The 170mm can shred an average 40ton tank's armor with one magazine.",
	model = "models/tankgun/tankgun_al_170mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	autosound = "acf_extra/tankfx/reload.wav",
	gunclass = "AL",
	caliber = 17.0,
	weight = 12460,
	year = 1970,
	rofmod = 0.7,
	magsize = 12,
	magreload = 40,
	round = {
		maxlength = 154,
		propweight = 34
	},
} )



--PLACEHOLDERS until we get an actual autoloader system.

ACF_defineGun("50mmBAL", {
	name = "50mm Breech Autoloader",
	desc = "PLACEHOLDER. 50mm Breech Autoloader. Autoloading giving it a consistent rate of fire in all conditions.",
	model = "models/tankgun_new/tankgun_50mm.mdl",
	sound = "ace_weapons/multi_sound/50mm_multi.mp3",
	gunclass = "AL",
	caliber = 5,
	weight = 900,
	year = 1960,
	rofmod = 1.2,
	round = {
		maxlength = 63,
		propweight = 2.1
	},
} )

ACF_defineGun("75mmBAL", {
	name = "75mm Breech Autoloader",
	desc = "PLACEHOLDER. 75mm Breech Autoloader. Autoloading giving it a consistent rate of fire in all conditions.",
	model = "models/tankgun_new/tankgun_75mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	gunclass = "AL",
	caliber = 7.5,
	weight = 1400,
	year = 1960,
	rofmod = 1.2,
	round = {
		maxlength = 78,
		propweight = 3.8
	},
} )

ACF_defineGun("100mmBAL", {
	name = "100mm Breech Autoloader",
	desc = "PLACEHOLDER. 100mm Breech Autoloader, with good penetration performance, can perform a deadly strike in one single pass. Seen on those modern tank destroyers.",
	model = "models/tankgun_new/tankgun_100mm.mdl",
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",
	gunclass = "AL",
	caliber = 10.0,
	weight = 2350,
	year = 1960,
	rofmod = 1.2,
	round = {
		maxlength = 93,
		propweight = 20
	},
} )

ACF_defineGun("120mmBAL", {
	name = "120mm Breech Autoloader",
	desc = "PLACEHOLDER. 120mm Breech Autoloader. Gives up some of the burst rate of fire of manually loaded guns for consistency and not having the cost of training loaders.",
	model = "models/tankgun_new/tankgun_120mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "AL",
	caliber = 12.0,
	weight = 4700,
	year = 1970,
	rofmod = 1.2,
	round = {
		maxlength = 115,
		propweight = 30
	},
} )

ACF_defineGun("140mmBAL", {
	name = "140mm Breech Autoloader",
	desc = "PLACEHOLDER. 140mm Breech Autoloader, Beefy 140mm autoloading cannon for dealing with heavily armored MBTs. With a consistent ROF due to the autoloader.",
	model = "models/tankgun_new/tankgun_140mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "AL",
	caliber = 14.0,
	weight = 6300,
	year = 1995,
	rofmod = 1.2,
	round = {
		maxlength = 140,
		propweight = 60
	},
} )

ACF_defineGun("170mmBAL", {
	name = "170mm Breech Autoloader",
	desc = "PLACEHOLDER. 170mm Breech Autoloader. Absolutely massive breechloading cannon perfect for tank destroyers looking to rip apart armor without spaghettifying your loader's arms.",
	model = "models/tankgun_new/tankgun_170mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "AL",
	caliber = 17.0,
	weight = 15350,
	year = 1990,
	rofmod = 1.2,
	round = {
		maxlength = 180,
		propweight = 34
	},
} )
