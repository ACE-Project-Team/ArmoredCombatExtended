--define the class
ACF_DefineRackClass("RK", {
	spread         = 1,
	name           = "Munitions Rack",
	desc           = "A lightweight rack for rockets and bombs which is vulnerable to shots and explosions.",
	muzzleflash    = "40mm_muzzleflash_noscale",
	rofmod         = 1,
	reloadmul      = 8,
} )

--add a gun to the class
ACF_DefineRack("1xRK", {
	name = "Single Universal Rack",
	desc = "A lightweight rack for rockets and bombs which is vulnerable to shots and explosions.",
	model	= "models/missiles/rkx1.mdl",
	gunclass = "RK",
	weight = 50,
	rofmod = 2,
	year = 1915,

	mountpoints = {
		missile1 = { pos = Vector(0, 0, 3.65), scaledir = Vector(0, 0, -1)}
	}
} )

--add a gun to the class
ACF_DefineRack("1xRK_small", {
	name = "Single Small Universal Rack",
	desc = "A lightweight rack for a single rocket or bomb which is vulnerable to shots and explosions.",
	model	= "models/missiles/rkx1_sml.mdl",
	gunclass = "RK",
	weight = 50,
	rofmod = 2,
	year = 1915,

	mountpoints = {
		missile1 = { pos = Vector(0, 0, 3.6), scaledir = Vector(0, 0, -1)}
	}
} )

ACF_DefineRack("2xRK", {
	name = "Dual Universal Rack",
	desc = "A lightweight rack for 2 rockets or bombs which is vulnerable to shots and explosions.",
	model	= "models/missiles/rack_double.mdl",
	gunclass = "RK",
	weight = 75,
	year = 1915,

	mountpoints = {
		missile1 = { pos = Vector(4,-12.6,-1.7), scaledir = Vector(0, -1, 0)},
		missile2 = { pos = Vector(4,12.6,-1.7),  scaledir = Vector(0, 1, 0)}
	}
} )

ACF_DefineRack("3xRK", {
	name = "BRU-42 Rack",
	desc = "A lightweight rack for 3 rockets or bombs which is vulnerable to shots and explosions.",
	model	= "models/missiles/bomb_3xrk.mdl",
	gunclass = "RK",
	weight = 100,
	year = 1936,

	magsize = 3,

	mountpoints = {
		missile1 = { pos = Vector(1.9,0,-7.7), scaledir = Vector(0,0,-1)},
		missile2 = { pos = Vector(2.3,3.2,0.4),	scaledir = Vector(0,1,-1)},
		missile3 = { pos = Vector(2.3,-3.2,0.4), scaledir = Vector(0,-1,-1)},
	}
} )

ACF_DefineRack("4xRK", {
	name = "Quad Universal Rack",
	desc = "A lightweight rack for 4 rockets or bombs which is vulnerable to shots and explosions.",
	model	= "models/missiles/rack_quad.mdl",
	gunclass = "RK",
	weight = 125,
	year = 1936,

	mountpoints =
	{
		missile1 = { pos = Vector(0,12,9), scaledir = Vector(0,1,0)},
		missile2 = { pos = Vector(0,-12,9), scaledir = Vector(0,-1,0)},
		missile3 = { pos = Vector(0,-12.6,-3.4), scaledir = Vector(0,0,-1)},
		missile4 = { pos = Vector(0,12.6,-3.4), scaledir = Vector(0,0,-1)}
	}
} )

ACF_DefineRack("2x AGM-114", {
	name = "Dual AGM-114 Rack",
	desc = "An AGM-114 rack designed to carry 2 missiles.",
	model	= "models/missiles/agm_114_2xrk.mdl",
	gunclass = "RK",
	weight = 50,
	year = 1984,

	mountpoints =
	{
		missile1 = { pos = Vector(0,-7.9,5.7), scaledir = Vector(0,0,-1)},
		missile2 = { pos = Vector(0,7.9,5.7), scaledir = Vector(0,0,-1)},
	}
} )

ACF_DefineRack("4x AGM-114", {
	name = "Quad AGM-114 Rack",
	desc = "An AGM-114 rack designed to carry 4 missiles.",
	model	= "models/missiles/agm_114_4xrk.mdl",
	gunclass = "RK",
	weight = 100,
	year = 1984,

	mountpoints =
	{
		missile1 = { pos = Vector(0,-7.9,5.7), scaledir = Vector(0,0,-1)},
		missile2 = { pos = Vector(0,7.9,5.7), scaledir = Vector(0,0,-1)},
		missile3 = { pos = Vector(0,-7.9,-12.1), scaledir = Vector(0,0,-1)},
		missile4 = { pos = Vector(0,7.9,-12.1), scaledir = Vector(0,0,-1)}
	}
} )

ACF_DefineRack("1xAT3RK", {
	name = "Single AT-3 Missile Rack",
	desc = "An AT-3 anti tank missile handheld rack",
	model	= "models/missiles/at3rk.mdl",
	gunclass = "RK",
	weight = 30,
	rofmod = 1.4,
	year = 1969,

	mountpoints =
	{
		missile1 = { pos = Vector(3.5,-0.2,-2.55), scaledir = Vector(0, 0, 1)}
	}
} )

ACF_DefineRack("1xAT3RKS", {
	name = "Single AT-3 Missile Rack designed for AFV",
	desc = "An AT-3 anti tank missile handheld rack",
	model	= "models/missiles/at3rs.mdl",
	gunclass = "RK",
	weight = 40,
	rofmod = 1,
	year = 1972,

	mountpoints =
	{
		missile1 = { pos = Vector(21.225,-0.2,2.6), scaledir = Vector(0, 0, 1) }
	}
} )

--TOR pod
ACF_DefineRack("1x9M331 Pod", {
	name = "9M331 Pod",
	desc = "Launch Pod for TOR misiles.",
	model	= "models/missiles/arend/9m331_launcher_4_v2.mdl",
	gunclass = "POD",
	weight = 100,
	year = 1986,
	magsize = 1,
	whitelistonly   = true,
	protectmissile  = false,
	hidemissile     = false,

	mountpoints =
	{
		["missile1"] = { ["pos"] = Vector(-8.3,0,-6.2),  ["offset"] = Vector(0,0,0), ["scaledir"] = Vector(0,0,0)},

	}
} )