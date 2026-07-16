--define the class
ACF_defineGunClass("GL", {
	type = "Gun",
	spread = 0.4,
	name = "Grenade Launcher",
	desc = ACFTranslation.GunClasses[6],
	muzzleflash = "MO",
	rofmod = 1,
	year = 1970,
	sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
	nolights	= true,
	noloader = true,

} )

--add a gun to the class
ACF_defineGun("40mmGL", { --id
	name = "40mm Grenade Launcher",
	desc = "The 40mm chews up infantry but is about as useful as tits on a nun for fighting armor.  Often found on 4x4s rolling through the third world.",
	model = "models/launcher/40mmgl.mdl",
	sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
	gunclass = "GL",
	caliber = 4.0,
	weight = 55,
	magsize = 48,
	rofmod = 0.45,
	magreload = 7.5,
	year = 1970,
	round = {
		maxlength = 7.5,
		propweight = 0.01
	},
	acepoints = 250,
	gunnerexception = true --Bypasses regular gunner rules.
} )

ACF_defineGun("20mmGL", { --id
	name = "20mm Grenade Launcher",
	desc = "The 20mm is the embodyment of wimpy weapons, although it has a large clip and can fire HE it is bloody weak							using 40mm GL as placeholder bc the 20mm mini is borked",
	model = "models/launcher/20mmgl.mdl",
	sound = "ace_weapons/multi_sound/12_7mm_multi.mp3",
	gunclass = "GL",
	caliber = 3.01,
	weight = 10,
	magsize = 72,
	rofmod = 0.55,
	magreload = 8,
	year = 1970,
	round = {
		maxlength = 7,
		propweight = 0.005
	},
	acepoints = 150,
	gunnerexception = true --Bypasses regular gunner rules.
} )
