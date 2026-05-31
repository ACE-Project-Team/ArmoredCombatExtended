ACE_DefineTransformer("ACE Transformer", {
	name = "Transformer",
	ent = "ace_transformer",
	category = "Transformers",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 24, W = 24, H = 24, Shape = "Box" },
	desc = "A grid transformer - it changes the AC line voltage. Step UP for low-loss, high-capacity transmission across a map; step DOWN to the voltage a device or charger actually needs.\n\nHow to use (link tool):\n1. Link it into the grid the same way as stations - to a Transfer Station or another Transformer. A line is drawn between them.\n2. Set its OUTPUT Voltage by wire; that is the voltage it presents on the line (and what a Consumer tapping it will see).\n\nIts size sets its ampacity, so a bigger transformer carries more power - voltage is not a free capacity dial. Power capacity = ampacity x voltage, so the same unit moves more at higher voltage. It runs hotter the more it carries; overload it and it overheats, sparks and trips offline until torch-repaired.\n\nWhy you can't cheat voltage: voltage only holds while there's real power behind it. A tiny battery behind a step-up reads high voltage unloaded but collapses (browns out) the instant a load pulls on it.\n\nInputs:\n- Active (Number): 1 to enable\n- Voltage (Number): output line voltage\nOutputs:\n- Voltage / Throughput (kW) / Capacity (kW) / Temperature (C)\n- Tripped (1 when overheated offline)",
})
