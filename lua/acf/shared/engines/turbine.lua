
-- Gas turbines

ACF_DefineEngine( "Turbine-Small-Trans", {
	name = "Gas Turbine, Small, Transaxial",
	desc = "A small gas turbine, high power and a very wide powerband\n\nThese turbines are optimized for aero use, but can be used in other specialized roles, being powerful but suffering from poor throttle response and fuel consumption.\n\nOutputs to the side instead of rear.",
	model = "models/engines/turbine_s.mdl",
	sound = "acf_engines/turbine_small.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 160,
	torque = 660,
	flywheelmass = 2.3,
	idlerpm = 1400,
	limitrpm = 10000,
	iselec = true,
	istrans = true,
	flywheeloverride = 4167,
	acepoints = 612
} )

ACF_DefineEngine( "Turbine-Medium-Trans", {
	name = "Gas Turbine, Medium, Transaxial",
	desc = "A medium gas turbine, moderate power but a very wide powerband\n\nThese turbines are optimized for aero use, but can be used in other specialized roles, being powerful but suffering from poor throttle response and fuel consumption.\n\nOutputs to the side instead of rear.",
	model = "models/engines/turbine_m.mdl",
	sound = "acf_engines/turbine_medium.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 320,
	torque = 975,
	flywheelmass = 3.4,
	idlerpm = 1800,
	limitrpm = 12000,
	iselec = true,
	istrans = true,
	flywheeloverride = 5000,
	acepoints = 1096
} )

ACF_DefineEngine( "Turbine-Large-Trans", {
	name = "Gas Turbine, Large, Transaxial",
	desc = "A large gas turbine, powerful with a wide powerband\n\nThese turbines are optimized for aero use, but can be used in other specialized roles, being powerful but suffering from poor throttle response and fuel consumption.\n\nOutputs to the side instead of rear.",
	model = "models/engines/turbine_l.mdl",
	sound = "acf_engines/turbine_large.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 880,
	torque = 2388,
	flywheelmass = 8.4,
	idlerpm = 2000,
	limitrpm = 13500,
	iselec = true,
	istrans = true,
	flywheeloverride = 5625,
	acepoints = 3017
} )

ACF_DefineEngine( "Turbine-Small", {
	name = "Gas Turbine, Small",
	desc = "A small gas turbine, high power and a very wide powerband\n\nThese turbines are optimized for aero use, but can be used in other specialized roles, being powerful but suffering from poor throttle response and fuel consumption.",
	model = "models/engines/gasturbine_s.mdl",
	sound = "acf_engines/turbine_small.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 200,
	torque = 825,
	flywheelmass = 2.9,
	idlerpm = 1400,
	limitrpm = 10000,
	iselec = true,
	flywheeloverride = 4167,
	acepoints = 765
} )

ACF_DefineEngine( "Turbine-Medium", {
	name = "Gas Turbine, Medium",
	desc = "A medium gas turbine, moderate power but a very wide powerband\n\nThese turbines are optimized for aero use, but can be used in other specialized roles, being powerful but suffering from poor throttle response and fuel consumption.",
	model = "models/engines/gasturbine_m.mdl",
	sound = "acf_engines/turbine_medium.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 400,
	torque = 1220,
	flywheelmass = 4.3,
	idlerpm = 1800,
	limitrpm = 12000,
	iselec = true,
	flywheeloverride = 5000,
	acepoints = 1372
} )

ACF_DefineEngine( "Turbine-Large", {
	name = "Gas Turbine, Large",
	desc = "A large gas turbine, powerful with a wide powerband\n\nThese turbines are optimized for aero use, but can be used in other specialized roles, being powerful but suffering from poor throttle response and fuel consumption.",
	model = "models/engines/gasturbine_l.mdl",
	sound = "acf_engines/turbine_large.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 1100,
	torque = 2985,
	flywheelmass = 10.5,
	idlerpm = 2000,
	limitrpm = 13500,
	iselec = true,
	flywheeloverride = 5625,
	acepoints = 3770
} )

--Forward facing ground turbines

ACF_DefineEngine( "Turbine-Ground-Small", {
	name = "Ground Gas Turbine, Small",
	desc = "A small gas turbine, fitted with ground-use air filters and tuned for ground use.\n\nGround-use turbines have excellent low-rev performance and are deceptively powerful, easily propelling loads that would have equivalent reciprocating engines struggling; however, they have sluggish throttle response, high gearbox demands, high fuel usage, and low tolerance to damage.",
	model = "models/engines/gasturbine_s.mdl",
	sound = "acf_engines/turbine_small.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 350,
	torque = 1200,
	flywheelmass = 14.3,
	idlerpm = 700,
	limitrpm = 3000,
	iselec = true,
	flywheeloverride = 1667,
	acepoints = 440
} )

ACF_DefineEngine( "Turbine-Ground-Medium", {
	name = "Ground Gas Turbine, Medium",
	desc = "A medium gas turbine, fitted with ground-use air filters and tuned for ground use.\n\nGround-use turbines have excellent low-rev performance and are deceptively powerful, easily propelling loads that would have equivalent reciprocating engines struggling; however, they have sluggish throttle response, high gearbox demands, high fuel usage, and low tolerance to damage.",
	model = "models/engines/gasturbine_m.mdl",
	sound = "acf_engines/turbine_medium.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine", --This is done to give proper fuel consumption and make the turbines not instant-torque from idle
	weight = 600,
	torque = 1800,
	flywheelmass = 29.6,
	idlerpm = 600,
	limitrpm = 3000,
	iselec = true,
	flywheeloverride = 1450,
	pitch = 115,
	acepoints = 638
} )

ACF_DefineEngine( "Turbine-Ground-Large", {
	name = "Ground Gas Turbine, Large",
	desc = "A large gas turbine, fitted with ground-use air filters and tuned for ground use. Doesn't have the sheer power output of an aero gas turbine, but compensates with an imperial fuckload of torque.\n\nGround-use turbines have excellent low-rev performance and are deceptively powerful, easily propelling loads that would have equivalent reciprocating engines struggling; however, they have sluggish throttle response, high gearbox demands, high fuel usage, and low tolerance to damage.",
	model = "models/engines/gasturbine_l.mdl",
	sound = "acf_engines/turbine_large.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 1650,
	torque = 6000,
	flywheelmass = 75,
	idlerpm = 500,
	limitrpm = 3000,
	iselec = true,
	flywheeloverride = 1250,
	pitch = 135,
	acepoints = 2060
} )

--Transaxial Ground Turbines

ACF_DefineEngine( "Turbine-Small-Ground-Trans", {
	name = "Ground Gas Turbine, Small, Transaxial",
	desc = "A small gas turbine, fitted with ground-use air filters and tuned for ground use.\n\nGround-use turbines have excellent low-rev performance and are deceptively powerful, easily propelling loads that would have equivalent reciprocating engines struggling; however, they have sluggish throttle response, high gearbox demands, high fuel usage, and low tolerance to damage.  Outputs to the side instead of rear.",
	model = "models/engines/turbine_s.mdl",
	sound = "acf_engines/turbine_small.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 280,
	torque = 900,
	flywheelmass = 11.4,
	idlerpm = 700,
	limitrpm = 3000,
	iselec = true,
	istrans = true,
	flywheeloverride = 1667,
	acepoints = 734
} )

ACF_DefineEngine( "Turbine-Medium-Ground-Trans", {
	name = "Ground Gas Turbine, Medium, Transaxial",
	desc = "A medium gas turbine, fitted with ground-use air filters and tuned for ground use.\n\nGround-use turbines have excellent low-rev performance and are deceptively powerful, easily propelling loads that would have equivalent reciprocating engines struggling; however, they have sluggish throttle response, high gearbox demands, high fuel usage, and low tolerance to damage.  Outputs to the side instead of rear.",
	model = "models/engines/turbine_m.mdl",
	sound = "acf_engines/turbine_medium.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 480,
	torque = 1350,
	flywheelmass = 23.7,
	idlerpm = 600,
	limitrpm = 3000,
	iselec = true,
	istrans = true,
	flywheeloverride = 1450,
	pitch = 115,
	acepoints = 1316
} )

ACF_DefineEngine( "Turbine-Large-Ground-Trans", {
	name = "Ground Gas Turbine, Large, Transaxial",
	desc = "A large gas turbine, fitted with ground-use air filters and tuned for ground use.  Doesn't have the sheer power output of an aero gas turbine, but compensates with an imperial fuckload of torque.\n\nGround-use turbines have excellent low-rev performance and are deceptively powerful, easily propelling loads that would have equivalent reciprocating engines struggling; however, they have sluggish throttle response, high gearbox demands, high fuel usage, and low tolerance to damage.  Outputs to the side instead of rear.",
	model = "models/engines/turbine_l.mdl",
	sound = "acf_engines/turbine_large.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 1320,
	torque = 4500,
	flywheelmass = 60,
	idlerpm = 500,
	limitrpm = 3000,
	iselec = true,
	istrans = true,
	flywheeloverride = 1250,
	pitch = 135,
	acepoints = 3620
} )




ACF_DefineEngine( "(+)Turbine-Small-SuperAero", {
	name = "(+)Turboshaft, Small",
	desc = "Gaghr Aerobine, notorious for being used in littlebirds. Experimental.",
	model = "models/engines/gasturbine_s.mdl",
	sound = "acf_engines/turbine_small.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 72,
	torque = 525,
	flywheelmass = 0.5,
	idlerpm = 1000,
	limitrpm = 14000,
	iselec = true,
	pitch = 70,
	flywheeloverride = 12000,
	acepoints = 635
} )



ACF_DefineEngine( "AGT 1500 Large Turbine", {
	name = "AGT 1500 Large Turbine",
	desc = "The gas turbine used in the M1 Abrams. Low output RPM due to an internal reduction gearbox. Plenty of low end torque and a wide powerband.",
	model = "models/engines/gasturbine_l.mdl",
	sound = "acf_extra/vehiclefx/engines/abrams.wav",
	category = "Turbine",
	fuel = "Multifuel",
	enginetype = "Turbine",
	weight = 2500,
	torque = 6780,
	torquecurve = {1, 0.82, 0.65, 0.529},
	flywheelmass = 10.5,
	idlerpm = 300,
	limitrpm = 3000,
	iselec = true,
	pitch = 130,
	flywheeloverride = 5300,
	acepoints = 3518
} )
