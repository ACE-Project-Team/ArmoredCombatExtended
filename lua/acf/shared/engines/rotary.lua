
-- Wankel engines

ACF_DefineEngine( "900cc-R", {
	name = "0.9L Rotary",
	desc = "Small 2-rotor Wankel; suited for yard use\n\nWankels have rather wide powerbands, but are very high strung",
	model = "models/engines/wankel_2_small.mdl",
	sound = "acf_engines/wankel_small.wav",
	category = "Rotary",
	fuel = "Petrol",
	enginetype = "Wankel",
	weight = 50,
	torque = 117,
	flywheelmass = 0.06,
	idlerpm = 950,
	limitrpm = 9200,
	acepoints = 179
} )

ACF_DefineEngine( "1.3L-R", {
	name = "1.3L Rotary",
	desc = "Medium 2-rotor Wankel\n\nWankels have rather wide powerbands, but are very high strung",
	model = "models/engines/wankel_2_med.mdl",
	sound = "acf_engines/wankel_medium.wav",
	category = "Rotary",
	fuel = "Petrol",
	enginetype = "Wankel",
	weight = 140,
	torque = 186,
	flywheelmass = 0.06,
	idlerpm = 950,
	limitrpm = 9000,
	acepoints = 280
} )

ACF_DefineEngine( "2.0L-R", {
	name = "2.0L Rotary",
	desc = "High performance 3-rotor Wankel\n\nWankels have rather wide powerbands, but are very high strung",
	model = "models/engines/wankel_3_med.mdl",
	sound = "acf_engines/wankel_large.wav",
	category = "Rotary",
	fuel = "Petrol",
	enginetype = "Wankel",
	weight = 200,
	torque = 282,
	flywheelmass = 0.1,
	idlerpm = 950,
	limitrpm = 9500,
	acepoints = 447
} )
