ACE_DefineExtras("WindSensor", {
	name = "Wind Sensor",
	ent = "ace_wind_sensor",
	category = "Misc",
	desc = "A simple wind sensor that detects the current wind direction and speed.\n\nUseful for long-range artillery calculations and smoke prediction.\n\nOutputs:\n- Wind (Vector): Raw wind vector\n- WindSpeed (Number): Wind magnitude in u/s\n- WindAngle (Angle): Wind direction",
	model = "models/props_c17/TrapPropeller_Lever.mdl",
	weight = 5,
	acepoints = 0,
})

ACE_DefineExtras("GForceMeter", {
	name = "G-Force Meter",
	ent = "ace_gforce_meter",
	category = "Misc",
	desc = "A sensor that measures the current G-force experienced at its position.\n\nCalculates from its own position, works when parented.\nStationary reads 1G (gravity).\n\nOutputs:\n- GForce: Total G-force magnitude\n- GForceVec: G-force direction vector\n- GForceX/Y/Z: Individual axis values",
	model = "models/bull/various/gyroscope.mdl",
	weight = 2,
	acepoints = 0,
})
