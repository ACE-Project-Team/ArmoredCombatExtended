ACE_DefineAlternator("ACE Alternator", {
	name = "Alternator",
	ent = "ace_alternator",
	category = "Alternators",
	AllowedShapes = { Box = true, Cylinder = true },
	MenuDefault = { L = 20, W = 20, H = 20, Shape = "Box" },
	desc = "A scalable generator that turns spinning machinery into electricity.\n\nHow to use:\n1. Link it to a spinning shaft - a prop on an axis, a gearbox output, or a wheel - with the link tool.\n2. Link an Electric battery to store what it makes.\n3. Feed it a Load (0-1). The higher the load, the harder it drags on the shaft and the more power it produces.\n\nThe drag rises with shaft speed and fades to nothing as it slows, so it gently brakes the shaft without ever stalling or driving it. Bigger units make more power but are heavier and run hotter under load.\n\nInputs:\n- Active (Number): 1 to enable\n- Load (Number): 0-1 generating load\n\nOutputs:\n- RPM (Number): current shaft RPM\n- Output Power (Number): electrical output in kW\n- Efficiency (Number): 0-1\n- Heat (Number): temperature in C",
})
