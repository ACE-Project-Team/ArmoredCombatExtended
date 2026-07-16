
-- Single-cylinder engines

ACF_DefineEngine( "0.25-I1", {
	name = "250cc Single",
	desc = "Tiny bike engine",
	model = "models/engines/1cylsml.mdl",
	sound = "acf_engines/i1_small.wav",
	category = "Single",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 15,
	torque = 30,
	flywheelmass = 0.005,
	idlerpm = 1200,
	limitrpm = 7500,
	acepoints = 37
} )

ACF_DefineEngine( "0.5-I1", {
	name = "500cc Single",
	desc = "Large single cylinder bike engine",
	model = "models/engines/1cylmed.mdl",
	sound = "acf_engines/i1_medium.wav",
	category = "Single",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 20,
	torque = 60,
	flywheelmass = 0.005,
	idlerpm = 900,
	limitrpm = 8000,
	acepoints = 79
} )

ACF_DefineEngine( "1.3-I1", {
	name = "1300cc Single",
	desc = "Ridiculously large single cylinder engine, seriously what the fuck",
	model = "models/engines/1cylbig.mdl",
	sound = "acf_engines/i1_large.wav",
	category = "Single",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 50,
	torque = 135,
	flywheelmass = 0.1,
	idlerpm = 600,
	limitrpm = 6700,
	acepoints = 151
} )
