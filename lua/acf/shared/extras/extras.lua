ACE.DefineExtras("WindSensor", {
	name = "Wind Sensor",
	ent = "ace_wind_sensor",
	category = "Misc",
	desc = "A simple wind sensor that detects the current wind direction and speed.\n\nUseful for long-range artillery calculations and smoke prediction.\n\nOutputs:\n- Wind (Vector): Raw wind vector\n- WindSpeed (Number): Wind magnitude in u/s\n- WindAngle (Angle): Wind direction",
	model = "models/props_c17/TrapPropeller_Lever.mdl",
	weight = 5,
	acepoints = 0,
})

ACE.DefineExtras("GForceMeter", {
	name = "G-Force Meter",
	ent = "ace_gforce_meter",
	category = "Misc",
	desc = "A sensor that measures the current G-force experienced at its position.\n\nCalculates from its own position, works when parented.\nStationary reads 1G (gravity).\n\nOutputs:\n- GForce: Total G-force magnitude\n- GForceVec: G-force direction vector\n- GForceX/Y/Z: Individual axis values",
	model = "models/bull/various/gyroscope.mdl",
	weight = 2,
	acepoints = 0,
})

ACE.DefineExtras("APS_Static", {
	name = "Static APS",
	ent = "ace_aps_static",
	category = "APS",
	desc = "Configurable static APS with onboard directional anti-missile radar. Link ACF guns and compatible ammunition, then configure charges, range, reload, radar size, and coverage.",
	model = "models/golem/Zaslin_APS.mdl",
	weight = 25,
	acepoints = 0,
	apsconfig = {1, 3, 5, 1, 90, 45},
	apspreset = "Static",
	guicreate = function(_, data) ACE.APSMenuGUICreate(data) end,
})

ACE.DefineExtras("APS_Zaslin", {
	name = "Zaslin APS",
	ent = "ace_aps_static",
	category = "APS",
	desc = "Zaslin preset: small onboard directional anti-missile radar, linked ammunition, and a 15-second APS reload.",
	model = "models/golem/Zaslin_APS.mdl",
	weight = 25,
	acepoints = 0,
	apsconfig = {1, 3, 15, 1, 90, 45},
	apspreset = "Zaslin",
	guicreate = function(_, data) ACE.APSMenuGUICreate(data) end,
})

ACE.DefineExtras("APS_Gimbal", {
	name = "APS (Gimbal)",
	ent = "ace_aps_gimbal",
	category = "APS",
	desc = "A gimbal active protection system. Link missile radars and the configured number of ACF guns; yaw and pitch limits determine when each gun can fire.",
	model = "models/props_lab/reciever01a.mdl",
	weight = 25,
	acepoints = 0,
})
