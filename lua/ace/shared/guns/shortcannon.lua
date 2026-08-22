--define the class
ACE.DefineGunClass("SC", {
	type = "Gun",
	spread = 0.20,
	name = "Short-Barrel Cannon",
	desc = ACE.Translation.GunClasses[13],
	muzzleflash = "MO",
	rofmod = 1,
	maxrof = 25, -- maximum rounds per minute
	year = 1915,
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",

} )

--add a gun to the class
ACE.DefineGun("37mmSC", {
	name = "37mm Short Cannon",
	desc = "Quick-firing and light, but penetration is laughable.  You're better off throwing rocks.",
	model = "models/tankgun/tankgun_short_37mm.mdl",
	sound = "ace_weapons/multi_sound/50mm_multi.mp3",
	gunclass = "SC",
	caliber = 3.7,
	weight = 55,
	maxrof = 60, -- maximum rounds per minute
	year = 1915,
	round = {
		maxlength = 45,
		propweight = 0.29
	},
} )

ACE.DefineGun("50mmSC", {
	name = "50mm Short Cannon",
	desc = "The 50mm is a quick-firing pea-shooter, good for scouts, and common on old interwar tanks.",
	model = "models/tankgun/tankgun_short_50mm.mdl",
	sound = "ace_weapons/multi_sound/50mm_multi.mp3",
	gunclass = "SC",
	caliber = 5.0,
	weight = 300,
	maxrof = 37, -- maximum rounds per minute
	year = 1915,
	round = {
		maxlength = 63,
		propweight = 0.6,
	},
} )

ACE.DefineGun("75mmSC", {
	name = "75mm Short Cannon",
	desc = "The 75mm is common WW2 medium tank armament, and still useful in many other applications.",
	model = "models/tankgun/tankgun_short_75mm.mdl",
	sound = "ace_weapons/multi_sound/75mm_multi.mp3",
	gunclass = "SC",
	caliber = 7.5,
	weight = 480,
	maxrof = 35, -- maximum rounds per minute
	year = 1936,
	round = {
		maxlength = 76,
		propweight = 2
	},
} )

ACE.DefineGun("85mmSC", {
	name = "85mm Short Cannon",
	desc = "Like the 85mm Cannon except shorter and mildly angrier.",
	model = "models/tankgun/tankgun_short_85mm.mdl",
	gunclass = "SC",
	caliber = 8.5,
	weight = 850,
	maxrof = 30, -- maximum rounds per minute
	year = 1942,
	round = {
		maxlength = 84.5,
		propweight = 3.25
	},
} )

ACE.DefineGun("100mmSC", {
	name = "100mm Short Cannon",
	desc = "The 100mm is an effective infantry-support or antitank weapon, with a lot of uses and surprising lethality.",
	model = "models/tankgun/tankgun_short_100mm.mdl",
	sound = "ace_weapons/multi_sound/100mm_multi.mp3",
	gunclass = "SC",
	caliber = 10.0,
	weight = 1000,
	maxrof = 25, -- maximum rounds per minute
	year = 1940,
	round = {
		maxlength = 93,
		propweight = 4.5
	},
} )

ACE.DefineGun("120mmSC", {
	name = "120mm Short Cannon",
	desc = "The 120mm is a formidable yet lightweight weapon, with excellent performance against larger vehicles.",
	model = "models/tankgun/tankgun_short_120mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "SC",
	caliber = 12.0,
	weight = 1400,
	maxrof = 23, -- maximum rounds per minute
	year = 1944,
	round = {
		maxlength = 110,
		propweight = 8.5
	},
} )

ACE.DefineGun("140mmSC", {
	name = "140mm Short Cannon",
	desc = "A specialized weapon, developed from dark magic and anti-heavy tank hatred.  Deal with it.",
	model = "models/tankgun/tankgun_short_140mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "SC",
	caliber = 14.0,
	weight = 2050,
	maxrof = 12, -- maximum rounds per minute
	year = 1999,
	round = {
		maxlength = 127,
		propweight = 12.8
	},
} )

ACE.DefineGun("170mmSC", {
	name = "170mm Short Cannon",
	desc = "A specialized weapon, developed from dark magic and anti-heavy tank hatred.  Deal with it.",
	model = "models/tankgun/tankgun_short_170mm.mdl",
	sound = "ace_weapons/multi_sound/120mm_multi.mp3",
	gunclass = "SC",
	caliber = 17.0,
	weight = 3200,
	maxrof = 6.7, -- maximum rounds per minute
	year = 1999,
	round = {
		maxlength = 147,
		propweight = 14.8
	},
} )


