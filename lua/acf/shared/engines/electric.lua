
-- Electric motors

ACF_DefineEngine( "Electric-Small", {
	name				= "Electric motor, Small",
	desc				= "A small electric motor, loads of torque, but low power\n\nElectric motors provide huge amounts of torque, but are very heavy",
	model			= "models/engines/emotorsmall.mdl",
	sound			= "acf_engines/electric_small.wav",
	category			= "Electric",
	fuel				= "Electric",
	enginetype		= "Electric",
	weight			= 147,
	torque			= 564, --400
	flywheelmass		= 0.07,
	idlerpm			= 0, --40
	limitrpm			= 18215,
	iselec			= true,
	flywheeloverride	= 4750,
	acepoints = 953
} )

ACF_DefineEngine( "Electric-Medium", {
	name				= "Electric motor, Medium",
	desc				= "A medium electric motor, loads of torque, but low power\n\nElectric motors provide huge amounts of torque, but are very heavy",
	model			= "models/engines/emotormed.mdl",
	sound			= "acf_engines/electric_medium.wav",
	category			= "Electric",
	fuel				= "Electric",
	enginetype		= "Electric",
	weight			= 160,
	torque			= 900,
	flywheelmass		= 0.15,
	idlerpm			= 0,
	limitrpm			= 20000,
	iselec			= true,
	flywheeloverride	= 8000,
	acepoints = 1672

} )

ACF_DefineEngine( "Electric-Large", {
	name				= "Electric motor, Large",
	desc				= "A huge electric motor, loads of torque, but low power\n\nElectric motors provide huge amounts of torque, but are very heavy",
	model			= "models/engines/emotorlarge.mdl",
	sound			= "acf_engines/electric_large.wav",
	category			= "Electric",
	fuel				= "Electric",
	enginetype		= "Electric",
	weight			= 240,
	torque			= 1200,
	flywheelmass		= 0.2,
	idlerpm			= 0,
	limitrpm			= 20000,
	iselec			= true,
	flywheeloverride	= 8000,
	acepoints = 2228

} )

ACF_DefineEngine( "Electric-Tiny-NoBatt", {
	name = "Electric motor, Tiny, Standalone",
	desc = "Basically a Nissan Leaf motor.  Can power electric razors, desk fans, or your hopes and dreams\n\nElectric motors provide huge amounts of torque, but are very heavy.\n\nStandalone electric motors don't have integrated batteries, saving on weight and volume, but require you to supply your own batteries.",
	model = "models/engines/emotor-standalone-tiny.mdl",
	sound = "acf_engines/electric_small.wav",
	category = "Electric",
	fuel = "Electric",
	enginetype = "Electric",
	weight = 58, --35
	torque = 189, --30
	flywheelmass = 0.05,
	idlerpm = 0, --40
	limitrpm = 11300,
	iselec = true,
	flywheeloverride = 4750,
	acepoints = 248
} )



ACF_DefineEngine( "Electric-Small-NoBatt", {
	name = "Electric motor, Small, Standalone",
	desc = "A small electric motor, loads of torque, but low power\n\nElectric motors provide huge amounts of torque, but are very heavy.\n\nStandalone electric motors don't have integrated batteries, saving on weight and volume, but require you to supply your own batteries.",
	model = "models/engines/emotor-standalone-sml.mdl",
	sound = "acf_engines/electric_small.wav",
	category = "Electric",
	fuel = "Electric",
	enginetype = "Electric",
	weight = 47, --25
	torque = 270, --400
	flywheelmass = 0.07,
	idlerpm = 0, --40
	limitrpm = 18215,
	iselec = true,
	flywheeloverride = 4750,
	acepoints = 570
} )

ACF_DefineEngine( "Electric-Medium-NoBatt", {
	name = "Electric motor, Medium, Standalone",
	desc = "A medium electric motor, loads of torque, but low power\n\nElectric motors provide huge amounts of torque, but are very heavy.\n\nStandalone electric motors don't have integrated batteries, saving on weight and volume, but require you to supply your own batteries.",
	model = "models/engines/emotor-standalone-mid.mdl",
	sound = "acf_engines/electric_medium.wav",
	category = "Electric",
	fuel = "Electric",
	enginetype = "Electric",
	weight = 65, --800
	torque = 510,
	flywheelmass = 0.15,
	idlerpm = 0,
	limitrpm = 20000,
	iselec = true,
	flywheeloverride = 8000,
	acepoints = 1184
} )

ACF_DefineEngine( "Electric-Large-NoBatt", {
	name = "Electric motor, Large, Standalone",
	desc = "A huge electric motor, loads of torque, but low power\n\nElectric motors provide huge amounts of torque, but are very heavy.\n\nStandalone electric motors don't have integrated batteries, saving on weight and volume, but require you to supply your own batteries.",
	model = "models/engines/emotor-standalone-big.mdl",
	sound = "acf_engines/electric_large.wav",
	category = "Electric",
	fuel = "Electric",
	enginetype = "Electric",
	weight = 140, --1900
	torque = 870,
	flywheelmass = 0.2,
	idlerpm = 0,
	limitrpm = 20000,
	iselec = true,
	flywheeloverride = 6000,
	acepoints = 2018
} )


--Note: Buff torque for every engine when radiators come, i think radiators will be mandatory for electric stuff
