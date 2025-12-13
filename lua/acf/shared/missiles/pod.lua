--define the class
ACF_DefineRackClass("POD", {
	spread		= 0.5,
	name			= "Rocket Pod",
	desc			= "An accurate, lightweight rocket launcher which can explode if its armour is pierced.",
	muzzleflash	= "40mm_muzzleflash_noscale",
	rofmod		= 2,
	sound		= "acf_extra/airfx/rocket_fire2.wav",
	soundDistance	= " ",
	soundNormal	= " ",

	hidemissile	= true,
	protectmissile  = true,

	reloadmul	= 8,
} )






ACF_DefineRack("40mm7xPOD", {
	name		= "7x 40mm FFAR Pod",
	desc		= "A lightweight pod for small rockets which is vulnerable to shots and explosions.",
	model	= "models/missiles/launcher7_40mm.mdl",
	gunclass	= "POD",
	weight	= 20,
	year		= 1940,
	magsize	= 7,

	reloadmul	= 150,

	hidemissile	= false,
	protectmissile  = true,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,-2,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(0,-1,-1.733), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(0,1,-1.733), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(0,2,0),  ["offset"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(0,1,1.736), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile7"] = { ["pos"] = Vector(0,-1,1.736), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )



ACF_DefineRack("70mm7xPOD", {
	name		= "7x 70mm FFAR Pod",
	desc		= "A lightweight pod for rockets which is vulnerable to shots and explosions.",
	model	= "models/missiles/launcher7_70mm.mdl",
	gunclass	= "POD",
	weight	= 40,
	year		= 1940,
	magsize	= 7,

	reloadmul	= 150,

	hidemissile	= false,
	protectmissile  = true,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,-3.5,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(0,-1.75,-3.033), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(0,1.75,-3.033), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(0,3.5,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(0,1.75,3.038), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile7"] = { ["pos"] = Vector(0,-1.75,3.038), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )




ACF_DefineRack("1x BGM-71E", {
	name = "BGM-71E Single Tube",
	desc = "A single BGM-71E round.",
	model = "models/missiles/bgm_71e_round.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1970,
	magsize = 1,

	whitelistonly	= true,
	protectmissile  = true,
	hidemissile	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(15.759,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )



ACF_DefineRack("2x BGM-71E", {
	name = "BGM-71E 2x Rack",
	desc = "A BGM-71E rack designed to carry 2 rounds.",
	model = "models/missiles/bgm_71e_2xrk.mdl",
	gunclass = "POD",
	weight = 60,
	year = 1970,
	magsize = 2,
	--caliber = 13, --Obsolete. Left here to have an example. If the missile caliber does not match this tube size precisely it won't be able to be loaded into the launcher.

	whitelistonly	= true,
	protectmissile  = true,
	hidemissile	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(23.639,4.728,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(23.639,-4.728,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )




ACF_DefineRack("4x BGM-71E", {
	name = "BGM-71E 4x Rack",
	desc = "A BGM-71E rack designed to carry 4 rounds.",
	model = "models/missiles/bgm_71e_4xrk.mdl",
	gunclass = "POD",
	weight = 100,
	year = 1970,
	magsize = 4,

	whitelistonly	= true,
	protectmissile  = true,
	hidemissile	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(23.639,4.728,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(23.639,-4.728,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(23.639,4.728,-11.426), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(23.639,-4.728,-11.426), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )


ACF_DefineRack("380mmRW61", {
	name		= "380mm rocket asisted mortar",
	desc		= "A lightweight pod for rocket-asisted mortars which is vulnerable to shots and explosions.",
	model	= "models/launcher/RW61.mdl",
	gunclass	= "POD",
	weight	= 600,
	year		= 1945,
	magsize	= 1,

	hidemissile	= false,
	whitelistonly	= true,
	protectmissile  = true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(8.387,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
	}
} )



-- New-old racks became pods:


ACF_DefineRack("3xUARRK", {
	name = "A-20 3x HVAR Rocket pod",
	desc = "A lightweight rack for bombs which is vulnerable to shots and explosions.",
	model	= "models/missiles/rk3uar.mdl",
	gunclass = "POD",
	weight = 150,
	year = 1941,
	magsize = 3,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(-6.759,0,9.09), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(-6.759,3.188,3.475), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(-6.759,-3.209,3.475), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
	}
} )

ACF_DefineRack("6xUARRK", {
	name = "M270 6x Artillery Launcher",
	desc = "6-pack of death, used to efficiently carry artillery rockets",
	model	= "models/missiles/6pod_rk.mdl",
	rackmdl	= "models/missiles/6pod_cover.mdl",
	gunclass = "POD",
	weight = 600,
	year = 1980,
	magsize = 6,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	inverted = true,

	mountpoints =
	{

		["missile1"] = { ["pos"] = Vector(0,-11.158,5.581), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,0.129,5.581), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(0,11.279,5.581), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(0,-11.159,-5.512), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(0,0.129,-5.512), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(0,11.279,-5.512), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},

	}
} )

ACF_DefineRack("1x FIM-92", {
	name = "Single Munition FIM-92 Rack",
	desc = "A FIM-92 rack designed to carry 1 missile.",
	model	= "models/missiles/fim_92_1xrk.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1984,
	magsize = 1,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("2x FIM-92", {
	name = "Double Munition FIM-92 Rack",
	desc = "A FIM-92 rack designed to carry 2 missiles.",
	model	= "models/missiles/fim_92_2xrk.mdl",
	gunclass = "POD",
	weight = 30,
	year = 1984,
	magsize = 2,
	rofmod = 3,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,3.35,0.45), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,-3.35,0.45), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("4x FIM-92", {
	name = "Quad Munition FIM-92 Rack",
	desc = "A FIM-92 rack designed to carry 4 missile.",
	model	= "models/missiles/fim_92_4xrk.mdl",
	gunclass = "POD",
	weight = 30,
	year = 1984,
	magsize = 4,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,2.6,2.65), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,-2.6,2.65), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(0,2.6,-3.6), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(0,-2.6,-3.6), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )


ACF_DefineRack("1x Strela-1", {
	name = "Single Munition 9M31 Rack",
	desc = "An 9M31 rack designed to carry 1 missile.",
	model	= "models/missiles/9m31_rk1.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1968,
	magsize = 1,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(44.124,2.646,0.132), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("2x Strela-1", {
	name = "Double Munition 9M31 Rack",
	desc = "An 9M31 rack designed to carry 2 missiles.",
	model	= "models/missiles/9m31_rk2.mdl",
	gunclass = "POD",
	weight = 30,
	year = 1968,
	magsize = 2,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(44.119,-5.592,0.132), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(44.119,10.967,0.132), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

--strela-1
ACF_DefineRack("4x Strela-1", {
	name = "Quad Munition 9M31 Rack",
	desc = "An 9m31 rack designed to carry 4 missiles.",
	model	= "models/missiles/9m31_rk4.mdl",
	gunclass = "POD",
	weight = 50,
	year = 1968,
	magsize = 4,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(43.668,-42.664,3.738), ["offset"] = Vector(0.5,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(43.668,-26.105,3.738), ["offset"] = Vector(0.5,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(43.668,25.983,3.738), ["offset"] = Vector(0.5,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(43.668,42.541,3.738), ["offset"] = Vector(0.5,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

--ataka tube
ACF_DefineRack("1x Ataka", {
	name = "Single Munition 9M120 Rack",
	desc = "An 9M120 rack designed to carry 1 missile.",
	model	= "models/missiles/9m120_rk1.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1968,
	magsize = 1,

	protectmissile  = true,
	hidemissile	= true,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,3), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

--spg9 tube
ACF_DefineRack("1x SPG9", {
	name = "SPG-9 Launch Tube",
	desc = "Launch tube for SPG-9 recoilless rocket.",
	model	= "models/spg9/spg9.mdl",
	gunclass = "POD",
	weight = 90,
	year = 1968,
	magsize = 1,
	spread = 0.1,

	protectmissile  = true,
	hidemissile	= true,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

-- 1 Kornet tube
ACF_DefineRack("1x Kornet", {
	name       = "Kornet Launch Tube",
	desc       = "Launch tube for Kornet antitank missile.",
	model      = "models/kali/weapons/kornet/parts/9m133 kornet tube.mdl",
	gunclass   = "POD",
	weight     = 30,
	year       = 1994,
	magsize    = 1,

	protectmissile   = true,
	hidemissile      = true,
	whitelistonly    = true,

	mountpoints =
	{
		missile1 = { pos = Vector(0,0,0), scaledir = Vector(0,0,0) }
	}
} )

-- 2 Kornet tube
ACF_DefineRack("2x Kornet", {
	name       = "Kornet Launch Tube",
	desc       = "A double Launch tube for 2 Kornet missiles.",
	model      = "models/missiles/kornetrack2.mdl",
	gunclass   = "POD",
	weight     = 60,
	year       = 1994,
	magsize    = 2,

	protectmissile   = true,
	hidemissile      = true,
	whitelistonly    = true,

	mountpoints =
	{
		missile1 = { pos = Vector(2,-7.3,-1), scaledir = Vector(0,0,0) },
		missile2 = { pos = Vector(2,7.3,-1), scaledir = Vector(0,0,0) },
	}
} )

-- 4 Kornet tube
ACF_DefineRack("4x Kornet", {
	name       = "Kornet Launch Tube",
	desc       = "A Quad Launch tube for 4 Kornet missiles.",
	model      = "models/missiles/kornetrack4.mdl",
	gunclass   = "POD",
	weight     = 120,
	year       = 1994,
	magsize    = 4,

	protectmissile   = true,
	hidemissile      = true,
	whitelistonly    = true,

	mountpoints =
	{
		missile1 = { pos = Vector(-1,-7.3,4.5), scaledir = Vector(0,0,0) },
		missile2 = { pos = Vector(-1,7.3,4.5), scaledir = Vector(0,0,0) },
		missile3 = { pos = Vector(-1,-7.3,-6.5), scaledir = Vector(0,0,0) },
		missile4 = { pos = Vector(-1,7.3,-6.5), scaledir = Vector(0,0,0) },
	}
} )


--Zuni pod
ACF_DefineRack("127mm4xPOD", {
	name = "5.0 Inch Zuni Pod",
	desc = "LAU-10/A Pod for the Zuni rocket.",
	model	= "models/ghosteh/lau10.mdl",
	gunclass = "POD",
	weight = 100,
	year = 1957,
	magsize = 4,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(5.2,2.75,2.65), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(5.2,-2.75,2.65), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(5.2,2.75,-2.83), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(5.2,-2.75,-2.83), ["scaledir"] = Vector(0,0,0)}
	}
} )

--9m311 pod
ACF_DefineRack("1x 9m311", {
	name = "Single 9M311 Launch Tube",
	desc = "A single 9M311 round.",
	model = "models/missiles/arend/9m311_tube.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1982,
	magsize = 1,
	armour  = 18,

	whitelistonly   = true,
	protectmissile  = true,
	hidemissile     = true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

--Javelin pod. Using the unfixed model since in the new one, missile is created at 90° degrees from original direction. I wonder why.
ACF_DefineRack("1x Javelin", {
	name = "FGM-148 Javelin Launch Tube",
	desc = "A launch tube designed for the javelin.",
	model = "models/mac/Javelin_straight.mdl",
	gunclass = "POD",
	weight = 6.4,
	year = 1989,
	magsize = 1,

	protectmissile  = true,
	hidemissile	= true,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,-1.38,2.4), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("20x S8KO", {
	name = "S-8KO Rocket Pod",
	desc = "The S-8 is a rocket weapon developed by the Soviet Air Force for use by military aircraft. It remains in service with the Russian Aerospace Forces and various export customers.",
	model = "models/missiles/arend/s8kolauncher.mdl",
	gunclass = "POD",
	weight = 100,
	year = 1970,
	magsize = 20,
	armour  = 20,
	whitelistonly   = true,
	protectmissile  = true,
	hidemissile     = false,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,-3.6086,6.968),  ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,3.525,-3.435),   ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(0,3.6086,6.968),    ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(0,-3.525,-3.435),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(0,6.493,4.704),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(0,-6.493,4.704),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile7"] = { ["pos"] = Vector(0,6.488,-5.649),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile8"] = { ["pos"] = Vector(0,-6.488,-5.649),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile9"] = { ["pos"] = Vector(0,2.286,3.424),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile10"] = { ["pos"] = Vector(0,-3.594,-7.954),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile11"] = { ["pos"] = Vector(0,-2.286,3.424),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile12"] = { ["pos"] = Vector(0,3.594,-7.954),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile13"] = { ["pos"] = Vector(0,-8.047,1.336),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile14"] = { ["pos"] = Vector(0,0,-5.04),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile15"] = { ["pos"] = Vector(0,8.047,1.336),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile16"] = { ["pos"] = Vector(0,-4.4812,0.288),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile17"] = { ["pos"] = Vector(0,8.047,-2.351),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile18"] = { ["pos"] = Vector(0,-8.047,-2.351),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile19"] = { ["pos"] = Vector(0,4.4812,0.288),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile20"] = { ["pos"] = Vector(0,0,-8.824),		["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
	}
} )

ACF_DefineRack("2x SRAAM", {
	name = "SRAAM Launcher",
	desc = "A Launcher made for 2 SRAAM missiles",
	model       = "models/missiles/arend/sraam_rack.mdl",
	gunclass = "RK",
	weight = 100,
	year = 1970,
	magsize = 2,
	armour  = 20,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,5,0),  ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(0,-5,0),   ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
	}
} )

ACF_DefineRack("1x VT-1", {
	name = "VT-1 Single Tube",
	desc = "A single VT-1 round.",
	model = "models/missiles/arend/vt1_launcher.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1970,
	magsize = 1,
	armour  = 18,

	whitelistonly   = true,
	protectmissile  = true,
	hidemissile     = false,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("1x HVM", {
	name = "HVM Single Tube",
	desc = "A single Starstreak round.",
	model = "models/missiles/hvm_tube.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1970,
	magsize = 1,
	armour  = 18,

	whitelistonly   = true,
	protectmissile  = true,
	hidemissile     = false,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(0,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("6x 9K121", {
	name = "9K121 Vikhr Rack",
	desc = "The 9K121 Vikhr rack designed to carry 6 9K121 missiles.",
	model       = "models/missiles/arend/9k121_rack.mdl",
	gunclass = "RK",
	weight = 100,
	year = 1984,
	magsize = 6,
	armour  = 20,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(-9.582,6.612,5.098),  ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(-9.582,-6.653,5.098),   ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(-9.582,-9.539,-6.896),    ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(-9.582,-3.19,-6.896),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(-9.582,3.227,-6.896),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(-9.582,9.531,-6.896),     ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
	}
} )

ACF_DefineRack("1x 9M113", {
	name = "9M113 Single Tube",
	desc = "A single 9M113 Konkurs round.",
	model = "models/missiles/arend/9m113_launcher.mdl",
	gunclass = "POD",
	weight = 10,
	year = 1970,
	magsize = 1,
	armour  = 18,

	whitelistonly   = true,
	protectmissile  = true,
	hidemissile     = false,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(17,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)} -- 15.759,0,0
	}
} )


ACF_DefineRack("1xVLS", {
	name = "1x Vertical Launch Cell",
	desc = "Self enclosed vertical launch tube.",
	model	= "models/macc/VLS_SingleBase.mdl",
	rackmdl	= "models/macc/VLS_Single_Cover.mdl",
	gunclass = "POD",
	weight = 1200,
	year = 1960,
	magsize = 1,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	inverted = true,

	mountpoints =
	{

		["missile1"] = { ["pos"] = Vector(134,0,-2.25), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},

	}
} )

ACF_DefineRack("1xmVLS", {
	name = "1x Mini Vertical Launch Cell",
	desc = "Small self enclosed vertical launch tube.",
	model	= "models/macc/VLS_SingleBase_Small.mdl",
	rackmdl	= "models/macc/VLS_Single_Cover_Small.mdl",
	gunclass = "POD",
	weight = 600,
	year = 1960,
	magsize = 1,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	inverted = true,

	mountpoints =
	{

		["missile1"] = { ["pos"] = Vector(50.25,0,-0.84375), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},

	}
} )

ACF_DefineRack("4xVLS", {
	name = "4x Vertical Launch Cell",
	desc = "Quad vertical launch tubes for unleasing the storm.",
	model	= "models/macc/VLS_4X.mdl",
	rackmdl	= "models/macc/VLS_Single_Cover.mdl",
	gunclass = "POD",
	weight = 4800,
	year = 1960,
	magsize = 4,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	inverted = true,

	mountpoints =
	{

		["missile1"] = { ["pos"] = Vector(134,98,-2.25), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(134,32.5,-2.25), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(134,-32.5,-2.25), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(134,-98,-2.25), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)}


	}
} )

ACF_DefineRack("4xmVLS", {
	name = "4x Mini Vertical Launch Cell",
	desc = "Quad vertical launch tubes for unleasing the storm. Small edition.",
	model	= "models/macc/VLS_4X_Small.mdl",
	rackmdl	= "models/macc/VLS_Single_Cover_Small.mdl",
	gunclass = "POD",
	weight = 2400,
	year = 1960,
	magsize = 1,

	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	inverted = true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(50.25,0,-0.84375), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile1"] = { ["pos"] = Vector(50.25,36.75,-0.84375), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(50.25,12.1875,-0.84375), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(50.25,-12.1875,-0.84375), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(50.25,-36.75,-0.84375), ["offset"] = Vector(0,0.1,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("1xTorpedo", {
	name = "1x 533mm Torpedo Rack",
	desc = "A single 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/1x1xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 1,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("2xTorpedo", {
	name = "2x 533mm Torpedo Rack",
	desc = "Twin 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/1x2xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 2,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(28,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(28,-25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("3xTorpedo", {
	name = "3x 533mm Torpedo Rack",
	desc = "Triple 533cm torpedo rack.",
	model	= "models/golem/TorpedoLaunchers/1x3xTorpedoLauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 3,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(28,25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(28,0,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(28,-25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("4xTorpedo", {
	name = "4x 533mm Torpedo Rack",
	desc = "A quad 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/1x4xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 4,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,-37.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(12,-12.65,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(12,12.65,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(12,37.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("5xTorpedo", {
	name = "5x 533mm Torpedo Rack",
	desc = "Quintuple 533cm torpedo rack.",
	model	= "models/golem/TorpedoLaunchers/1x5xTorpedoLauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 4,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,37.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(12,12.5,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(12,-12.5,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(12,-37.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(12,-62.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("6xTorpedo", {
	name = "6x 533mm Torpedo Rack",
	desc = "Sextuple 533cm torpedo rack.",
	model	= "models/golem/TorpedoLaunchers/1x6xTorpedoLauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 4,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,62.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(12,37,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(12,12.5,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(12,-12.5,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(12,-37,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(12,-62.25,0), ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("1xSmallTorpedo", {
	name = "1x 533mm Torpedo Rack",
	desc = "A single 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/375x1xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 1,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,0,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("2xSmallTorpedo", {
	name = "2x 533mm Torpedo Rack",
	desc = "Twin 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/375x2xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 2,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(28,0,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(28,-25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("3xSmallTorpedo", {
	name = "3x 533mm Torpedo Rack",
	desc = "Triple 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/375x3xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 3,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(28,25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(28,0,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(28,-25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("4xSmallTorpedo", {
	name = "4x 533mm Torpedo Rack",
	desc = "A quad 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/375x4xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 4,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,-37.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(12,-12.65,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(12,12.65,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(12,37.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("5xSmallTorpedo", {
	name = "5x 533mm Torpedo Rack",
	desc = "Quintuple 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/375x5xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 4,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,37.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(12,12.5,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(12,-12.5,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(12,-37.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(12,-62.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )

ACF_DefineRack("6xSmallTorpedo", {
	name = "6x 533mm Torpedo Rack",
	desc = "Sextuple 533cm torpedo rack.",
	model	= "models/golem/torpedolaunchers/375x6xtorpedolauncher.mdl",
	gunclass = "POD",
	weight = 700,
	year = 1889,
	magsize = 4,
	protectmissile  = true,
	hidemissile	= false,
	whitelistonly	= true,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(12,62.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile2"] = { ["pos"] = Vector(12,37,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile3"] = { ["pos"] = Vector(12,12.5,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile4"] = { ["pos"] = Vector(12,-12.5,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile5"] = { ["pos"] = Vector(12,-37,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},
		["missile6"] = { ["pos"] = Vector(12,-62.25,0) * 0.375, ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)}
	}
} )