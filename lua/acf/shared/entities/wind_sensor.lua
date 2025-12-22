ACF_DefineEntity("WindSensor", {
	name = "Wind Sensor",
	ent = "ace_wind_sensor",
	category = "Misc",
	desc = "A simple wind sensor that detects the current wind direction and speed. Useful for long-range artillery calculations and smoke prediction.\n\nOutputs:\n- Wind (Vector): Raw wind vector\n- WindSpeed (Number): Wind magnitude in u/s\n- WindAngle (Angle): Wind direction",
	model = "models/props_c17/TrapPropeller_Lever.mdl",
	weight = 5,
	acepoints = 5,
})