
-- Radial engines

ACF_DefineEngine( "3.8-R7", {
	name = "3.8L R7 Petrol",
	desc = "A tiny, old worn-out radial.",
	model = "models/engines/radial7s.mdl",
	sound = "acf_engines/r7_petrolsmall.wav",
	category = "Radial",
	fuel = "Petrol",
	enginetype = "Radial",
	weight = 105,
	torque = 582,
	flywheelmass = 0.22,
	idlerpm = 700,
	limitrpm = 4800,
	acepoints = 394
} )

ACF_DefineEngine( "11.0-R7", {
	name = "11.0 R7 Petrol",
	desc = "Mid range radial, thirsty and smooth",
	model = "models/engines/radial7m.mdl",
	sound = "acf_engines/r7_petrolmedium.wav",
	category = "Radial",
	fuel = "Petrol",
	enginetype = "Radial",
	weight = 190,
	torque = 1050,
	flywheelmass = 0.45,
	idlerpm = 600,
	limitrpm = 4400,
	acepoints = 652
} )

ACF_DefineEngine( "24.0-R7", {
	name = "24.0L R7 Petrol",
	desc = "Massive American radial monster, destined for fighter aircraft and heavy tanks.",
	model = "models/engines/radial7l.mdl",
	sound = "acf_engines/r7_petrollarge.wav",
	category = "Radial",
	fuel = "Petrol",
	enginetype = "Radial",
	weight = 475,
	torque = 3027,
	flywheelmass = 3.4,
	idlerpm = 750,
	limitrpm = 3500,
	acepoints = 1526
} )


ACF_DefineEngine( "8.0-R7", {
	name = "8.0 R7 Diesel",
	desc = "Military-grade radial engine, similar to a ZO 02A.  Heavy and with a narrow powerband, but efficient, and well-optimized to cruising.",
	model = "models/engines/radial7m.mdl",
	sound = "acf_engines/r7_petrolmedium.wav",
	category = "Radial",
	fuel = "Multifuel",
	enginetype = "GenericDiesel",
	weight = 225,
	torque = 1500,
	flywheelmass = 1.0,
	idlerpm = 400,
	limitrpm = 2800,
	acepoints = 618
} )
