
-- V-Twin engines

ACF_DefineEngine( "0.6-V2", {
	name = "600cc V-Twin",
	desc = "Twin cylinder bike engine, torquey for its size",
	model = "models/engines/v-twins2.mdl",
	sound = "acf_engines/vtwin_small.wav",
	category = "V-Twin",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 30,
	torque = 75,
	flywheelmass = 0.01,
	idlerpm = 900,
	limitrpm = 7000,
	acepoints = 89
} )

ACF_DefineEngine( "1.2-V2", {
	name = "1200cc V-Twin",
	desc = "Large displacement vtwin engine",
	model = "models/engines/v-twinm2.mdl",
	sound = "acf_engines/vtwin_medium.wav",
	category = "V-Twin",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 50,
	torque = 128,
	flywheelmass = 0.02,
	idlerpm = 725,
	limitrpm = 6250,
	acepoints = 133
} )

ACF_DefineEngine( "2.4-V2", {
	name = "2400cc V-Twin",
	desc = "Huge fucking Vtwin 'MURRICA FUCK YEAH",
	model = "models/engines/v-twinl2.mdl",
	sound = "acf_engines/vtwin_large.wav",
	category = "V-Twin",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 100,
	torque = 240,
	flywheelmass = 0.075,
	idlerpm = 900,
	limitrpm = 6000,
	acepoints = 242
} )
