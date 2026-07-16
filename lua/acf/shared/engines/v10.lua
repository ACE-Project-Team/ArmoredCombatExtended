--V10s

ACF_DefineEngine( "4.3-V10", {
	name = "4.3L V10 Petrol",
	desc = "Small-block V-10 gasoline engine, great for powering a hot rod lincoln",
	model = "models/engines/v10sml.mdl",
	sound = "acf_engines/v10_petrolsmall.wav",
	category = "V10",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 160,
	torque = 432,
	flywheelmass = 0.2,
	idlerpm = 900,
	limitrpm = 6250,
	acepoints = 454
} )

ACF_DefineEngine( "8.0-V10", {
	name = "8.0L V10 Petrol",
	desc = "Beefy 10-cylinder gas engine, gets 9 kids to soccer practice",
	model = "models/engines/v10med.mdl",
	sound = "acf_engines/v10_petrolmedium.wav",
	category = "V10",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 300,
	torque = 735,
	flywheelmass = 0.5,
	idlerpm = 750,
	limitrpm = 6500,
	acepoints = 799
} )

ACF_DefineEngine( "22.0-V10", {
	name = "22.0L V10 Multifuel",
	desc = "Heavy multifuel V-10, gearbox-shredding torque but very heavy.",
	model = "models/engines/v10big.mdl",
	sound = "acf_engines/v10_diesellarge.wav",
	category = "V10",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 1600,
	torque = 3908,
	flywheelmass = 5,
	idlerpm = 525,
	limitrpm = 2500,
	acepoints = 1820
} )
ACF_DefineEngine( "23.0-V10", {
	name = "23.0L V10 Petrol",
	desc = "You should be crazy to install this engine.Designed for drag racers",
	model = "models/engines/v10big.mdl",
	sound = "acf_engines/v10_petrolmedium.wav",
	category = "V10",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 2110,
	torque = 1800,
	flywheelmass = 0.45,
	idlerpm = 1000,
	limitrpm = 9000,
	acepoints = 2705
} )
