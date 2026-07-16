ACF_DefineEngine( "3.6-V6", {
	name = "3.6L V6 Petrol",
	desc = "Meaty Car sized V6, lots of torque\n\nV6s are more torquey than the Boxer and Inline 6s but suffer in power",
	model = "models/engines/v6small.mdl",
	sound = "acf_engines/v6_petrolsmall.wav",
	category = "V6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 190,
	torque = 380,
	flywheelmass = 0.25,
	idlerpm = 700,
	limitrpm = 5000,
	acepoints = 319
} )

ACF_DefineEngine( "6.2-V6", {
	name = "6.2L V6 Petrol",
	desc = "Heavy duty 6V71 v6, throatier than an LA whore, but loaded with torque\n\nV6s are more torquey than the Boxer and Inline 6s but suffer in power",
	model = "models/engines/v6med.mdl",
	sound = "acf_engines/v6_petrolmedium.wav",
	category = "V6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 360,
	torque = 708,
	flywheelmass = 0.45,
	idlerpm = 800,
	limitrpm = 5000,
	acepoints = 596
} )

ACF_DefineEngine( "5.2-V6", {
	name = "5.2L V6 Diesel",
	desc = "Light AFV-grade two-stroke multifuel, high output but heavy",
	model = "models/engines/v6med.mdl",
	sound = "acf_engines/i5_dieselmedium.wav",
	category = "V6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 520,
	torque = 728,
	flywheelmass = 0.8,
	idlerpm = 650,
	limitrpm = 4300,
	acepoints = 576
} )

ACF_DefineEngine( "12.0-V6", {
	name = "12.0L V6 Petrol",
	desc = "Fuck duty V6, guts ripped from god himself diluted in salt and shaped into an engine.\n\nV6s are more torquey than the Boxer and Inline 6s but suffer in power",
	model = "models/engines/v6large.mdl",
	sound = "acf_engines/v6_petrollarge.wav",
	category = "V6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 675,
	torque = 2168,
	flywheelmass = 4,
	idlerpm = 600,
	limitrpm = 3800,
	acepoints = 1389
} )

ACF_DefineEngine( "15.0-V6", {
	name = "15.0L V6 Diesel",
	desc = "Powerful military-grade large V6, with impressive output.  Well suited to moderately-sized AFVs and able to handle multiple fuel types.\n\nV6s are more torquey than the Boxer and Inline 6s but suffer in power",
	model = "models/engines/v6large.mdl",
	sound = "acf_engines/v6_diesellarge.wav",
	category = "V6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 900,
	torque = 2650,
	flywheelmass = 6.4,
	idlerpm = 400,
	limitrpm = 3100,
	acepoints = 1507
} )
