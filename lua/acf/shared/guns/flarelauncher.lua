--define the class
ACF_defineGunClass("FGL", {
	type = "Gun",
	spread = 3,
	name = "Flare Launcher",
	desc = ACFTranslation.GunClasses[5],
	muzzleflash = "MO",
	rofmod = 0.6,
	year = 1970,
	sound = "acf_new/weapons/skyfire/close/close (1).wav",

	ammoBlacklist	= {"AP", "APHE", "FL", "HE", "HEAT", "HP", "SM"} -- ok fun's over
} )

--add a gun to the class
ACF_defineGun("40mmFGL", { --id
	name = "40mm Flare Launcher",
	desc = "Put on an all-American fireworks show with this flare launcher: high fire rate, low distraction rate.  Fill the air with flare.  Careful of your reload time.",
	model = "models/missiles/blackjellypod.mdl",
	sound = "acf_extra/tankfx/flare_launch.wav",
	gunclass = "FGL",
	caliber = 4.0,
	weight = 75,
	magsize = 30,
	magreload = 30,
	year = 1970,
	round = {
		maxlength = 9,
		propweight = 0.007
	},
	acepoints = 150,
	gunnerexception = true --Bypasses regular gunner rules.
} )

--add a gun to the class
ACF_defineGun("60mmFGL", { --id
	name = "60mm Flare Launcher",
	desc = "Large countermeasure shooting out heavy flares. Has fewer shots than the its 40mm counterpart but reloads faster and is much better for distracting.",
	model = "models/launcher/40mmgl.mdl",
	sound = "acf_extra/tankfx/flare_launch.wav",
	gunclass = "FGL",
	caliber = 6.0,
	weight = 125,
	magsize = 6,
	magreload = 20,
	year = 1970,
	round = {
		maxlength = 3,
		propweight = 0.014
	},
	acepoints = 150,
	gunnerexception = true --Bypasses regular gunner rules.
} )
