
-- V12 engines

-- Petrol

ACF_DefineEngine( "4.6-V12", {
	name = "4.6L V12 Petrol",
	desc = "An elderly racecar engine; low on torque, but plenty of power",
	model = "models/engines/v12s.mdl",
	sound = "acf_engines/v12_petrolsmall.wav",
	category = "V12",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 188,
	torque = 352,
	flywheelmass = 0.2,
	idlerpm = 1000,
	limitrpm = 8000,
	acepoints = 473
} )

ACF_DefineEngine( "7.0-V12", {
	name = "7.0L V12 Petrol",
	desc = "A high end V12; primarily found in very expensive cars",
	model = "models/engines/v12s.mdl",
	sound = "acf_engines/v12_petrolmedium.wav",
	category = "V12",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 360,
	torque = 450,
	flywheelmass = 0.45,
	idlerpm = 800,
	limitrpm = 7500,
	acepoints = 564
} )

ACF_DefineEngine( "23.0-V12", {
	name = "23.0L V12 Petrol",
	desc = "A large, thirsty gasoline V12, found in early cold war tanks",
	model = "models/engines/v12l.mdl",
	sound = "acf_engines/v12_petrollarge.wav",
	category = "V12",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 1350,
	torque = 2888,
	flywheelmass = 5,
	idlerpm = 600,
	limitrpm = 3250,
	acepoints = 1594
} )

ACF_DefineEngine( "25.0-V12", {
	name = "25.0L V12 Petrol",
	desc = "Best petrol V12 engine ever ",
	model = "models/engines/v12l.mdl",
	sound = "acf_engines/v12_petrollarge.wav",
	category = "V12",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 2600,
	torque = 3075,
	flywheelmass = 5.2,
	idlerpm = 500,
	limitrpm = 5000,
	acepoints = 2563
} )

-- Diesel

ACF_DefineEngine( "4.0-V12", {
	name = "4.0L V12 Diesel",
	desc = "Reliable truck-duty diesel; a lot of smooth torque",
	model = "models/engines/v12s.mdl",
	sound = "acf_engines/v12_dieselsmall.wav",
	category = "V12",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 305,
	torque = 562,
	flywheelmass = 0.475,
	idlerpm = 650,
	limitrpm = 4000,
	acepoints = 414
} )

ACF_DefineEngine( "9.2-V12", {
	name = "9.2L V12 Diesel",
	desc = "High torque light-tank V12, used mainly for vehicles that require balls",
	model = "models/engines/v12m.mdl",
	sound = "acf_engines/v12_dieselmedium.wav",
	category = "V12",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 600,
	torque = 1125,
	flywheelmass = 2.5,
	idlerpm = 675,
	limitrpm = 3500,
	acepoints = 730
} )

ACF_DefineEngine( "21.0-V12", {
	name = "21.0L V12 Diesel",
	desc = "AVDS-1790-2 tank engine; massively powerful, but enormous and heavy",
	model = "models/engines/v12l.mdl",
	sound = "acf_engines/v12_diesellarge.wav",
	category = "V12",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 1800,
	torque = 5340,
	flywheelmass = 7,
	idlerpm = 400,
	limitrpm = 2500,
	acepoints = 2460
} )

ACF_DefineEngine( "13.0-V12", {
	name = "13.0L V12 Petrol",
	desc = "Thirsty gasoline v12, good torque and power for medium applications.",
	model = "models/engines/v12m.mdl",
	sound = "acf_engines/v12_special.wav",
	category = "V12",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 520,
	torque = 990,
	flywheelmass = 1,
	idlerpm = 700,
	limitrpm = 4250,
	acepoints = 711
} )

ACF_DefineEngine( "16.5-V12", {
	name = "16.5L V12 Diesel",
	desc = "V-2-34. Pretty powerful but heavy with nice torque.",
	model = "models/engines/v8l.mdl",
	sound = "acf_engines/v12_dieselmedium.wav",
	category = "V12",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 1050,
	torque = 1650,
	flywheelmass = 2,
	idlerpm = 675,
	limitrpm = 3500,
	acepoints = 1071
} )

ACF_DefineEngine( "24.8-V12", {
	name = "24.8-V12 Diesel",
	desc = "AVDS-1790-9A tank engine; massively powerful, but enormous and heavy",
	model = "models/engines/v12l.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/m60.wav",
	category = "V12",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 2100,
	torque = 5400,
	flywheelmass = 7,
	idlerpm = 500,
	limitrpm = 2800,
	acepoints = 2799
} )

ACF_DefineEngine( "27.0-V12", {
	name = "27.0-V12 Diesel",
	desc = "AVDS-1790-1500 tank engine; massively powerful, but enormous and heavy. Best diesel engine in V12",
	model = "models/engines/v12lbig.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/m60.wav",
	category = "V12",
	fuel = "Diesel",
	enginetype = "GenericDiesel",
	weight = 3150,
	torque = 6630,
	flywheelmass = 6.6,
	idlerpm = 500,
	limitrpm = 2800,
	acepoints = 3436
} )
