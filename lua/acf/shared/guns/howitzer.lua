--define the class
ACF_defineGunClass("HW", {
	type = "Gun",
	spread = 0.15,
	name = "Howitzer",
	desc = ACFTranslation.GunClasses[8],
	muzzleflash = "C",
	rofmod = 1.5,
	maxrof = 20, -- maximum rounds per minute
	year = 1900,
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",

} )

--add a gun to the class
ACF_defineGun("75mmHW", { --id
	name = "75mm Howitzer",
	desc = "Often found being towed by large smelly animals, the 75mm has a high rate of fire, and is surprisingly lethal against light armor.  Great for a sustained barrage against someone you really don't like.",
	model = "models/howitzer/howitzer_75mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 7.5,
	weight = 550,
	maxrof = 20, -- maximum rounds per minute
	year = 1900,
	round = {
		maxlength = 60,
		propweight = 1.8
	},
	acepoints = 750
} )

ACF_defineGun("105mmHW", {
	name = "105mm Howitzer",
	desc = "The 105 lobs a big shell far, and its HEAT rounds can be extremely effective against even heavier armor.",
	model = "models/howitzer/howitzer_105mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 10.5,
	weight = 980,
	maxrof = 14, -- maximum rounds per minute
	year = 1900,
	round = {
		maxlength = 86,
		propweight = 3.75
	},
	acepoints = 950
} )

ACF_defineGun("122mmHW", {
	name = "122mm Howitzer",
	desc = "The 122mm bridges the gap between the 105 and the 155, providing a lethal round with a big splash radius.",
	model = "models/howitzer/howitzer_122mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 12.2,
	weight = 1450,
	maxrof = 11, -- maximum rounds per minute
	year = 1900,
	round = {
		maxlength = 106,
		propweight = 7
	},
	acepoints = 1790
} )

ACF_defineGun("155mmHW", {
	name = "155mm Howitzer",
	desc = "The 155 is a classic heavy artillery round, with good reason.  A versatile weapon, it's found on most modern SPGs.",
	model = "models/howitzer/howitzer_155mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 15.5,
	weight = 2100,
	maxrof = 9, -- maximum rounds per minute
	year = 1900,
	round = {
		maxlength = 124,
		propweight = 13.5
	},
	acepoints = 2060
} )

ACF_defineGun("203mmHW", {
	name = "203mm Howitzer",
	desc = "An 8-inch deck gun, found on siege artillery and cruisers.",
	model = "models/howitzer/howitzer_203mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 20.3,
	maxrof = 4, -- maximum rounds per minute
	weight = 3900,
	year = 1900,
	round = {
		maxlength = 162.4,
		propweight = 28.5
	},
	acepoints = 2750
} )


ACF_defineGun("240mmHW", {
	name = "240mm Howitzer",
	desc = "A 9.4-inch deck gun, found on heavy siege artillery and cruisers.",
	model = "models/howitzer/howitzer_240mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 24.0,
	weight = 8000,
	maxrof = 3, -- maximum rounds per minute
	year = 1900,
	round = {
		maxlength = 192.0,
		propweight = 33.7
	},
	acepoints = 5500
} )

ACF_defineGun("290mmHW", {
	name = "290mm Howitzer",
	desc = " Mother of all howitzers. This 12in beast was used to shell absurd underground compound. Using it is truly a warcrime.",
	model = "models/howitzer/howitzer_290mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 29,
	weight = 26800,
	maxrof = 2.1, -- maximum rounds per minute
	year = 1900,
	round = {
		maxlength = 360,
		propweight = 57.0
	},
	acepoints = 8950
} )

ACF_defineGun("406mmHW", {
	name = "406mm Howitzer",
	desc = "The ultimate anti everything weapon, this absurd 16 inch gun can commonly be found on American Battleships and emplacements and its mere existence is a warcrime. HOW COULD YOU YOU MONSTER!",
	model = "models/howitzer/howitzer_406mm.mdl",
	sound = "ace_weapons/multi_sound/howitzer_multi.mp3",
	gunclass = "HW",
	caliber = 40.6,
	weight = 50000,
	maxrof = 1.5, -- maximum rounds per minute
	year = 1920,
	round = {
		maxlength = 540,
		propweight = 40000
	},
	acepoints = 16000
} )

