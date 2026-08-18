
-- Flat 6 engines

ACF_DefineEngine( "2.8-B6", {
	name = "2.8L Flat 6 Petrol",
	desc = "Car sized flat six engine, sporty and light",
	model = "models/engines/b6small.mdl",
	sound = "acf_engines/b6_petrolsmall.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "B6",
	weight = 50,
	torque = 204,
	flywheelmass = 0.08,
	idlerpm = 750,
	limitrpm = 7250
} )

ACF_DefineEngine( "5.0-B6", {
	name = "5.0L Flat 6 Petrol",
	desc = "Sports car grade flat six, renown for their smooth operation and light weight",
	model = "models/engines/b6med.mdl",
	sound = "acf_engines/b6_petrolmedium.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "B6",
	weight = 120,
	torque = 495,
	flywheelmass = 0.11,
	idlerpm = 900,
	limitrpm = 6800
} )

ACF_DefineEngine( "5.4-B6", {
	name = "5.4L Flat 6 Multifuel",
	desc = "Military-grade multifuel boxer engine.  Although heavy, it is compact, durable, and has excellent performance under adverse conditions.",
	model = "models/engines/b6med.mdl",
	sound = "acf_engines/v8_diesel.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "B6",
	weight = 170,
	torque = 825,
	flywheelmass = 0.65,
	idlerpm = 500,
	limitrpm = 3500
} )

ACF_DefineEngine( "8.3-B6", {
	name = "8.3L Flat 6 Multifuel",
	desc = "Military-grade multifuel boxer engine.  Although heavy, it is compact, durable, and has excellent performance under adverse conditions.",
	model = "models/engines/b6med.mdl",
	sound = "acf_engines/v8_diesel.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "B6",
	weight = 240,
	torque = 848,
	flywheelmass = 0.65,
	idlerpm = 500,
	limitrpm = 4200
} )

ACF_DefineEngine( "10.0-B6", {
	name = "10.0L Flat 6 Petrol",
	desc = "Aircraft grade boxer with a high rev range biased powerband",
	model = "models/engines/b6large.mdl",
	sound = "acf_engines/b6_petrollarge.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "B6",
	weight = 325,
	torque = 1575,
	flywheelmass = 1,
	idlerpm = 620,
	limitrpm = 4500
} )

ACF_DefineEngine( "15.8-B6", {
	name = "15.8L Flat 6 Petrol",
	desc = "Monstrous aircraft-grade boxer with a high rev range biased powerband",
	model = "models/engines/b6large.mdl",
	sound = "acf_engines/b6_petrollarge.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "B6",
	weight = 363,
	torque = 1900,
	flywheelmass = 1,
	idlerpm = 620,
	limitrpm = 4900
} )

ACF_DefineEngine( "20.7-B6", {
	name = "20.7L Flat 6 Multifuel",
	desc = "A compact and torquey boxer engine with great power and torque.",
	model = "models/engines/b6large.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "B6",
	weight = 570,
	torque = 3378,
	flywheelmass = 6.4,
	idlerpm = 600,
	limitrpm = 2800
} )

ACF_DefineEngine( "22.9-B6", {
	name = "22.9L Flat 6 Multifuel",
	desc = "Compact monster of a boxer with a fantastic power output and excellent torque for the form.",
	model = "models/engines/b6xlarge.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "B6",
	weight = 570,
	torque = 6344,
	flywheelmass = 6.4,
	idlerpm = 600,
	limitrpm = 2600
} )

ACF_DefineEngine( "25.9-B6", {
	name = "25.9L Flat 6 Multifuel",
	desc = "Extremely powerful monster of a mega-boxer engine with enough torque to move a city block.",
	model = "models/engines/b6huge.mdl", --We really need a huge model for this
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "B6",
	weight = 610,
	torque = 11997,
	flywheelmass = 6.6,
	idlerpm = 600,
	limitrpm = 2800
} )
