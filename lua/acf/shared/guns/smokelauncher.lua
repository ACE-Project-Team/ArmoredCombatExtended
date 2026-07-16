--define the class
ACF_defineGunClass("SL", {
	type		= "Gun",
	spread		= 0.2,
	name		= "Smoke Launcher",
	desc		= ACFTranslation.GunClasses[14],
	muzzleflash = "MO",
	rofmod		= 50,
	year		= 1941,
	sound		= "ace_weapons/multi_sound/smoke_multi.mp3",
	nolights	= true
} )

--add a gun to the class
ACF_defineGun("40mmSL", { --id
	name		= "40mm Smoke Launcher",
	desc		= "",
	model		= "models/launcher/40mmsl.mdl",
	sound		= "ace_weapons/multi_sound/smoke_multi.mp3",
	gunclass	= "SL",
	caliber	= 4.0,
	rofmod		= 0.2,
	weight		= 1,
	year		= 1941,
	round = {
		maxlength	= 17.5,
		propweight	= 0.007
	},
	acepoints = 10,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("20mmSL", { --id
	name		= "20mm Smoke Launcher",
	desc		= "",
	model		= "models/launcher/20mmsl.mdl",
	sound		= "ace_weapons/multi_sound/smoke_multi.mp3",
	gunclass	= "SL",
	caliber	= 2.0,
	rofmod		= 2,
	weight		= 1,
	year		= 1941,
	round = {
		maxlength	= 17.5,
		propweight	= 0.0055
	},
	acepoints = 5,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("40mmCL", { --id
	name		= "40mm Countermeasure Launcher",
	desc		= "A revolver-style launcher capable of firing off several smoke or flare rounds.",
	model		= "models/launcher/40mmgl.mdl",
	sound		= "ace_weapons/multi_sound/smoke_multi.mp3",
	gunclass	= "SL",
	caliber	= 4.0,
	weight		= 10,
	rofmod		= 0.015,
	magsize	= 6,
	magreload	= 20,
	year		= 1975,
	round = {
		maxlength	= 17.5,
		propweight	= 0.007
	},
	acepoints = 30,
	gunnerexception = true --Bypasses regular gunner rules.
} )
