
-- Inline 6 engines

-- Petrol

ACF_DefineEngine( "2.2-I6", {
	name = "2.2L I6 Petrol",
	desc = "Car sized I6 petrol with power in the high revs",
	model = "models/engines/inline6s.mdl",
	sound = "acf_engines/l6_petrolsmall2.wav",
	category = "I6",
	fuel = "Petrol",
	enginetype = "I6",
	weight = 60,
	torque = 195,
	flywheelmass = 0.1,
	idlerpm = 800,
	limitrpm = 7200
} )

ACF_DefineEngine( "4.8-I6", {
	name = "4.8L I6 Petrol",
	desc = "Light truck duty I6, good for offroad applications",
	model = "models/engines/inline6m.mdl",
	sound = "acf_engines/l6_petrolmedium.wav",
	category = "I6",
	fuel = "Petrol",
	enginetype = "I6",
	weight = 150,
	torque = 540,
	flywheelmass = 0.2,
	idlerpm = 900,
	limitrpm = 5500
} )

ACF_DefineEngine( "17.2-I6", {
	name = "17.2L I6 Petrol",
	desc = "Heavy tractor duty petrol I6, decent overall powerband",
	model = "models/engines/inline6l.mdl",
	sound = "acf_engines/l6_petrollarge2.wav",
	category = "I6",
	fuel = "Petrol",
	enginetype = "I6",
	weight = 425,
	torque = 1440,
	flywheelmass = 2.5,
	idlerpm = 800,
	limitrpm = 4250
} )

-- Diesel

ACF_DefineEngine( "3.0-I6", {
	name = "3.0L I6 Diesel",
	desc = "Car sized I6 diesel, good, wide powerband",
	model = "models/engines/inline6s.mdl",
	sound = "acf_engines/l6_dieselsmall.wav",
	category = "I6",
	fuel = "Diesel",
	enginetype = "I6",
	weight = 75,
	torque = 300,
	flywheelmass = 0.5,
	idlerpm = 650,
	limitrpm = 4500
} )

ACF_DefineEngine( "6.5-I6", {
	name = "6.5L I6 Diesel",
	desc = "Truck duty I6, good overall powerband and torque",
	model = "models/engines/inline6m.mdl",
	sound = "acf_engines/l6_dieselmedium4.wav",
	category = "I6",
	fuel = "Diesel",
	enginetype = "I6",
	weight = 225,
	torque = 780,
	flywheelmass = 1.5,
	idlerpm = 600,
	limitrpm = 4000
} )

ACF_DefineEngine( "20.0-I6", {
	name = "20.0L I6 Diesel",
	desc = "Heavy duty diesel I6, used in generators and heavy movers",
	model = "models/engines/inline6l.mdl",
	sound = "acf_engines/l6_diesellarge2.wav",
	category = "I6",
	fuel = "Diesel",
	enginetype = "I6",
	weight = 600,
	torque = 2550,
	flywheelmass = 8,
	idlerpm = 400,
	limitrpm = 2600
} )
