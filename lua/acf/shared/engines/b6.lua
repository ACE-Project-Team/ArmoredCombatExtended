
-- Flat 6 engines

ACF_DefineEngine( "2.8-B6", {
	name = "2.8L Flat 6 Petrol",
	desc = "Car sized flat six engine, sporty and light",
	model = "models/engines/b6small.mdl",
	sound = "acf_engines/b6_petrolsmall.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 100,
	torque = 204,
	flywheelmass = 0.08,
	idlerpm = 750,
	limitrpm = 7250,
	acepoints = 247
} )

ACF_DefineEngine( "5.0-B6", {
	name = "5.0L Flat 6 Petrol",
	desc = "Sports car grade flat six, renown for their smooth operation and light weight",
	model = "models/engines/b6med.mdl",
	sound = "acf_engines/b6_petrolmedium.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 240,
	torque = 495,
	flywheelmass = 0.11,
	idlerpm = 900,
	limitrpm = 6800,
	acepoints = 564
} )

ACF_DefineEngine( "8.3-B6", {
	name = "8.3L Flat 6 Multifuel",
	desc = "Military-grade multifuel boxer engine.  Although heavy, it is compact, durable, and has excellent performance under adverse conditions.",
	model = "models/engines/b6med.mdl",
	sound = "acf_engines/v8_diesel.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 480,
	torque = 848,
	flywheelmass = 0.65,
	idlerpm = 500,
	limitrpm = 4200,
	acepoints = 677
} )

ACF_DefineEngine( "10.0-B6", {
	name = "10.0L Flat 6 Petrol",
	desc = "Aircraft grade boxer with a high rev range biased powerband",
	model = "models/engines/b6large.mdl",
	sound = "acf_engines/b6_petrollarge.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 650,
	torque = 1575,
	flywheelmass = 1,
	idlerpm = 620,
	limitrpm = 4500,
	acepoints = 1429
} )

ACF_DefineEngine( "5.4-B6", {
	name = "5.4L Flat 6 Multifuel",
	desc = "Military-grade multifuel boxer engine.  Although heavy, it is compact, durable, and has excellent performance under adverse conditions.",
	model = "models/engines/b6med.mdl",
	sound = "acf_engines/v8_diesel.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 380,
	torque = 825,
	flywheelmass = 0.65,
	idlerpm = 500,
	limitrpm = 3500,
	acepoints = 531
} )

ACF_DefineEngine( "15.8-B6", {
	name = "15.8L Flat 6 Petrol",
	desc = "Monstrous aircraft-grade boxer with a high rev range biased powerband",
	model = "models/engines/b6large.mdl",
	sound = "acf_engines/b6_petrollarge.wav",
	category = "B6",
	fuel = "Petrol",
	enginetype = "GenericPetrol",
	weight = 725,
	torque = 1650,
	flywheelmass = 1,
	idlerpm = 620,
	limitrpm = 4900,
	acepoints = 1354
} )

ACF_DefineEngine( "13.6-B6", {
	name = "13.6L Flat 6 Multifuel",
	desc = "5TDF. Compact flat tank engine, with great power reserve, but with comparably high consumption. T-64 classic.",
	model = "models/engines/b6med.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 1040,
	torque = 3320,
	flywheelmass = 6,
	idlerpm = 600,
	limitrpm = 2800,
	acepoints = 1734
} )

ACF_DefineEngine( "20.7-B6", {
	name = "20.7L Flat 6 Multifuel",
	desc = "6TD-1. Not so large flat tank engine, with great power reserve, but with comparably high consumption.",
	model = "models/engines/b6med.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 1180,
	torque = 3908,
	flywheelmass = 6.4,
	idlerpm = 600,
	limitrpm = 2800,
	acepoints = 2041
} )

ACF_DefineEngine( "22.9-B6", {
	name = "22.9L Flat 6 Multifuel",
	desc = "6TD-2E. Large flat tank engine, with big power reserve, but with comparably high consumption",
	model = "models/engines/b6xlarge.mdl",
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 1180,
	torque = 5512,
	flywheelmass = 6.4,
	idlerpm = 600,
	limitrpm = 2600,
	acepoints = 2684
} )

ACF_DefineEngine( "25.9-B6", {
	name = "25.9L Flat 6 Multifuel",
	desc = "6TD-3, designed by Kharkiv. Large flat tank engine, with really big power reserve, but with monstrous consumption",
	model = "models/engines/b6huge.mdl", --We really need a huge model for this
	sound = "acf_extra/vehiclefx/engines/gnomefather/t64.wav",
	category = "B6",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 1220,
	torque = 5997,
	flywheelmass = 6.6,
	idlerpm = 600,
	limitrpm = 2800,
	acepoints = 3132
} )
