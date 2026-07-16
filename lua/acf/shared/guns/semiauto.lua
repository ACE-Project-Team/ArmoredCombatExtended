--define the class
ACF_defineGunClass("SA", {
	type = "Gun",
	spread = 0.15,
	name = "Semiautomatic Cannon",
	desc = ACFTranslation.GunClasses[12],
	muzzleflash = "AC",
	rofmod = 0.5,
	year = 1935,
	sound = "ace_weapons/multi_sound/20mm_multi.mp3",
	noloader = true,

} )

--add a gun to the class
ACF_defineGun("25mmSA", { --id
	name = "25mm Semiautomatic Cannon",
	desc = "The 25mm semiauto can quickly put five rounds downrange, being lethal, yet light.",
	model = "models/autocannon/semiautocannon_25mm.mdl",
	sound = "ace_weapons/multi_sound/20mm_multi.mp3",
	gunclass = "SA",
	caliber = 2.5,
	weight = 75,
	year = 1935,
	rofmod = 0.45,
	magsize = 12,
	magreload = 2,
	round = {
		maxlength = 39,
		propweight = 0.5
	},
	acepoints = 600
} )

ACF_defineGun("37mmSA", {
	name = "37mm Semiautomatic Cannon",
	desc = "The 37mm is surprisingly powerful, its five-round clips boasting a respectable payload and a high muzzle velocity.",
	model = "models/autocannon/semiautocannon_37mm.mdl",
	sound = "ace_weapons/multi_sound/30mm_multi.mp3",
	gunclass = "SA",
	caliber = 3.7,
	weight = 180,
	year = 1940,
	rofmod = 0.4,
	magsize = 15,
	magreload = 4,
	round = {
		maxlength = 42,
		propweight = 1.125
	},
	acepoints = 700
} )

ACF_defineGun("45mmSA", { --
	name = "45mm Semiautomatic Cannon",
	desc = "The 45mm can easily shred light armor, with a respectable rate of fire, but its armor penetration pales in comparison to regular cannons.",
	model = "models/autocannon/semiautocannon_45mm.mdl",
	sound = "ace_weapons/multi_sound/40mm_multi.mp3",
	gunclass = "SA",
	caliber = 4.5,
	weight = 495,
	year = 1965,
	rofmod = 0.325,
	magsize = 12,
	magreload = 5,
	round = {
		maxlength = 52,
		propweight = 1.8
	},
	acepoints = 1000
} )

ACF_defineGun("57mmSA", {
	name = "57mm Semiautomatic Cannon",
	desc = "The 57mm is a respectable light armament, offering considerable penetration and moderate fire rate.",
	model = "models/autocannon/semiautocannon_57mm.mdl",
	sound = "ace_weapons/multi_sound/50mm_multi.mp3",
	gunclass = "SA",
	caliber = 5.7,
	weight = 780,
	year = 1965,
	rofmod = 0.4,
	magsize = 12,
	magreload = 9,
	round = {
		maxlength = 62,
		propweight = 2
	},
	acepoints = 1400
} )

ACF_defineGun("76mmSA", {
	name = "76mm Semiautomatic Cannon",
	desc = "The 76mm semiauto is a fearsome weapon, able to put 12 76mm rounds downrange in 7 seconds.",
	model = "models/autocannon/semiautocannon_76mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	gunclass = "SA",
	caliber = 7.62,
	weight = 1700,
	year = 1984,
	rofmod = 0.325,
	magsize = 12,
	magreload = 12,
	round = {
		maxlength = 70,
		propweight = 4.75
	},
	acepoints = 1900
} )
