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

ACE_DefineExtras("ECM", {
	name = "ECM Jammer",
	ent = "ace_ecm",
	category = "Sensors",
	desc = "An electronic countermeasures pod. When active, it jams enemy radars within range, degrading their tracking.\n\nHow to use:\n1. Wire its Active input to switch it on.\n2. Optionally aim its jamming with JamDirection / JamPos.\n\nInputs:\n- Active (Number): on/off\n- JamDirection (Vector) / JamPos (Vector): directional jamming\nOutputs:\n- JamCount (Number): radars currently jammed",
	model = "models/missiles/minipod.mdl",
	weight = 1000,
	acepoints = 500,
})

ACE_DefineExtras("RWRDirectional", {
	name = "RWR (Directional)",
	ent = "ace_rwr_dir",
	category = "Sensors",
	desc = "A radar warning receiver that reports the direction of radars and missile seekers painting you - for cockpit threat displays and evasion logic.\n\nOutputs the bearing to detected emitters.",
	model = "models/radar/radar_sml.mdl",
	weight = 30,
	acepoints = 0,
})

ACE_DefineExtras("RWRSpherical", {
	name = "RWR (Spherical)",
	ent = "ace_rwr_sphere",
	category = "Sensors",
	desc = "A radar warning receiver with full spherical coverage - reports all emitters painting you, regardless of direction. Good for an omnidirectional threat picture.",
	model = "models/maxofs2d/hover_basic.mdl",
	weight = 65,
	acepoints = 0,
})

ACE_DefineExtras("FuelPump", {
	name = "Fuel Pump (Booster)",
	ent = "ace_fuel_pump",
	category = "Fuel",
	desc = "A booster node for fuel pipelines - the fuel analogue of a relay station. Friction drains a pipeline's pressure over distance; each pump you splice into the line restores pressure so the fuel can keep going.\n\nHow to use:\n1. Lay pipes from a supply tank toward a destination.\n2. When a long run won't deliver, link a Pump between two pipes (or to a pipe and a tank). It extends the reachable range.\n\nPlace pumps periodically along very long pipelines.",
	model = "models/maxofs2d/thruster_propeller.mdl",
	weight = 40,
	acepoints = 0,
})

ACE_DefineExtras("Refinery", {
	name = "Refinery",
	ent = "ace_refinery",
	category = "Fuel",
	desc = "Turns crude Oil + electricity into Petrol or Diesel - the middle of the fuel chain.\n\nHow to use (link tool):\n1. Link an Oil tank (crude input).\n2. Link an Electric battery (power).\n3. Link a Petrol or Diesel tank (the product output - its type decides what you make; a Universal output makes Petrol).\n4. Wire Active.\n\nIt consumes a bit more crude than product (refining loss) and draws power; it runs hot.\n\nOutputs: Refining (L/s), Oil Draw, Elec Draw, Heat.",
	model = "models/props_c17/furnitureboiler001a.mdl",
	weight = 200,
	acepoints = 0,
})

ACE_DefineExtras("PowerBreaker", {
	name = "Power Breaker",
	ent = "ace_power_breaker",
	category = "Electricity",
	desc = "An overcurrent breaker that protects a station. Link it to a Transfer Station; if that station carries more than the breaker's Rating (kW) for a moment, the breaker trips it offline to protect the grid.\n\nInputs:\n- Rating (Number): trip threshold in kW\n- Reset (Number): rising edge re-closes it\nOutputs:\n- Tripped (1 when open)\n- Current (kW through the station)",
	model = "models/xqm/hydcontrolbox.mdl",
	weight = 15,
	acepoints = 0,
})

ACE_DefineExtras("PowerCollector", {
	name = "Power Collector",
	ent = "ace_power_collector",
	category = "Electricity",
	desc = "A pantograph-style pickup for trains/trams. Mount it on the vehicle and link it to the vehicle's Electric battery; it charges that battery whenever it's near an energised Source station (within range).\n\nOutputs:\n- Connected (1 when picking up)\n- Throughput (kW)",
	model = "models/props_trainstation/mount_connection001a.mdl",
	weight = 30,
	acepoints = 0,
})

ACE_DefineExtras("OpticalComputer", {
	name = "Optical Computer",
	ent = "acf_opticalcomputer",
	category = "Misc",
	desc = "The optical guidance computer for GLATGMs (gun-launched ATGMs). Mount it on a vehicle that fires GLATGM rounds so they can be optically guided onto your aim point. It does not affect any other missile or guidance type.",
	model = "models/props_lab/monitor01b.mdl",
	weight = 50,
	acepoints = 0,
})