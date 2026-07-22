
-- 9-Speed Gearboxes

-- Weight
local Gear9SW = 200
local Gear9MW = 400
local Gear9LW = 750
local StWB = 0.75 --straight weight bonus mulitplier

-- Torque Rating
local Gear9ST = 1050
local Gear9MT = 2890
local Gear9LT = 8960
local StTB = 1.25 --straight torque bonus multiplier

-- Inline

ACE_DefineGearbox( "9Gear-L-S", {
	name = "9-Speed, Inline, Small",
	desc = "A small and light 9 speed gearbox.",
	model = "models/engines/linear_s.mdl",
	category = "9-Speed",
	weight = Gear9SW,
	switch = 0.15,
	maxtq = Gear9ST,
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-L-M", {
	name = "9-Speed, Inline, Medium",
	desc = "A medium duty 9 speed gearbox .. ",
	model = "models/engines/linear_m.mdl",
	category = "9-Speed",
	weight = Gear9MW,
	switch = 0.2,
	maxtq = Gear9MT,
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-L-L", {
	name = "9-Speed, Inline, Large",
	desc = "Heavy duty 9 speed gearbox, however rather heavy.",
	model = "models/engines/linear_l.mdl",
	category = "9-Speed",
	weight = Gear9LW,
	switch = 0.3,
	maxtq = Gear9LT,
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

-- Inline Dual Clutch

ACE_DefineGearbox( "9Gear-LD-S", {
	name = "9-Speed, Inline, Small, Dual Clutch",
	desc = "A small and light 9 speed gearbox The dual clutch allows you to apply power and brake each side independently\n\nThe Final Drive slider is a multiplier applied to all the other gear ratios",
	model = "models/engines/linear_s.mdl",
	category = "9-Speed",
	weight = Gear9SW,
	switch = 0.15,
	maxtq = Gear9ST,
	gears = 9,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-LD-M", {
	name = "9-Speed, Inline, Medium, Dual Clutch",
	desc = "A a medium duty 9 speed gearbox. The dual clutch allows you to apply power and brake each side independently\n\nThe Final Drive slider is a multiplier applied to all the other gear ratios",
	model = "models/engines/linear_m.mdl",
	category = "9-Speed",
	weight = Gear9MW,
	switch = 0.2,
	maxtq = Gear9MT,
	gears = 9,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-LD-L", {
	name = "9-Speed, Inline, Large, Dual Clutch",
	desc = "Heavy duty 9 speed gearbox. The dual clutch allows you to apply power and brake each side independently\n\nThe Final Drive slider is a multiplier applied to all the other gear ratios",
	model = "models/engines/linear_l.mdl",
	category = "9-Speed",
	weight = Gear9LW,
	switch = 0.3,
	maxtq = Gear9LT,
	gears = 9,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

-- Transaxial

ACE_DefineGearbox( "9Gear-T-S", {
	name = "9-Speed, Transaxial, Small",
	desc = "A small and light 9 speed gearbox .. ",
	model = "models/engines/transaxial_s.mdl",
	category = "9-Speed",
	weight = Gear9SW,
	switch = 0.15,
	maxtq = Gear9ST,
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-T-M", {
	name = "9-Speed, Transaxial, Medium",
	desc = "A medium duty 9 speed gearbox .. ",
	model = "models/engines/transaxial_m.mdl",
	category = "9-Speed",
	weight = Gear9MW,
	switch = 0.2,
	maxtq = Gear9MT,
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-T-L", {
	name = "9-Speed, Transaxial, Large",
	desc = "Heavy duty 9 speed gearbox, however rather heavy.",
	model = "models/engines/transaxial_l.mdl",
	category = "9-Speed",
	weight = Gear9LW,
	switch = 0.3,
	maxtq = Gear9LT,
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

-- Transaxial Dual Clutch

ACE_DefineGearbox( "9Gear-TD-S", {
	name = "9-Speed, Transaxial, Small, Dual Clutch",
	desc = "A small and light 9 speed gearbox The dual clutch allows you to apply power and brake each side independently\n\nThe Final Drive slider is a multiplier applied to all the other gear ratios",
	model = "models/engines/transaxial_s.mdl",
	category = "9-Speed",
	weight = Gear9SW,
	switch = 0.15,
	maxtq = Gear9ST,
	gears = 9,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-TD-M", {
	name = "9-Speed, Transaxial, Medium, Dual Clutch",
	desc = "A a medium duty 9 speed gearbox. The dual clutch allows you to apply power and brake each side independently\n\nThe Final Drive slider is a multiplier applied to all the other gear ratios",
	model = "models/engines/transaxial_m.mdl",
	category = "9-Speed",
	weight = Gear9MW,
	switch = 0.2,
	maxtq = Gear9MT,
	gears = 9,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-TD-L", {
	name = "9-Speed, Transaxial, Large, Dual Clutch",
	desc = "Heavy duty 9 speed gearbox. The dual clutch allows you to apply power and brake each side independently\n\nThe Final Drive slider is a multiplier applied to all the other gear ratios",
	model = "models/engines/transaxial_l.mdl",
	category = "9-Speed",
	weight = Gear9LW,
	switch = 0.3,
	maxtq = Gear9LT,
	gears = 9,
	doubleclutch = true,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

-- Straight-through gearboxes

ACE_DefineGearbox( "9Gear-ST-S", {
	name = "9-Speed, Straight, Small",
	desc = "A small and light 9 speed straight-through gearbox.",
	model = "models/engines/t5small.mdl",
	category = "9-Speed",
	weight = math.floor(Gear9SW * StWB),
	switch = 0.15,
	maxtq = math.floor(Gear9ST * StTB),
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-ST-M", {
	name = "9-Speed, Straight, Medium",
	desc = "A medium 9 speed straight-through gearbox.",
	model = "models/engines/t5med.mdl",
	category = "9-Speed",
	weight = math.floor(Gear9MW * StWB),
	switch = 0.2,
	maxtq = math.floor(Gear9MT * StTB),
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )

ACE_DefineGearbox( "9Gear-ST-L", {
	name = "9-Speed, Straight, Large",
	desc = "A large 9 speed straight-through gearbox.",
	model = "models/engines/t5large.mdl",
	category = "9-Speed",
	weight = math.floor(Gear9LW * StWB),
	switch = 0.3,
	maxtq = math.floor(Gear9LT * StTB),
	gears = 9,
	geartable = {
		[ 0 ] = 0,
		[ 1 ] = 0.1,
		[ 2 ] = 0.2,
		[ 3 ] = 0.3,
		[ 4 ] = 0.4,
		[ 5 ] = 0.5,
		[ 6 ] = 0.6,
		[ 7 ] = 0.7,
		[ 8 ] = 0.8,
		[ 9 ] = -0.1,
		[ -1 ] = 0.5
	}
} )
