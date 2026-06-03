ACE_DefineTransformer("ACE Transformer", {
	name = "Transformer",
	ent = "ace_transformer",
	category = "Transformers",
	AllowedShapes = { Box = true },
	MenuDefault = { L = 24, W = 24, H = 24, Shape = "Box" },
	desc = "Changes the grid's voltage. Step UP to send power a long way with little loss; step DOWN to the voltage a device needs.\n\nHow to use:\n1. Link it into the grid like a station (to a station, power line, or another transformer).\n2. Set its output Voltage by wire - that's the voltage it puts on the line past it.\n3. Switch it on (Active) - while off it passes no power.\n\nIts size sets how much power it can carry and how high it can step. It runs hotter the more it carries; overload it and it trips off until torch-repaired.\n\nNote: voltage only holds while there's real power behind it - a tiny battery behind a big step-up collapses the moment a load pulls on it.\n\nModel: scalable Box, or a substation prop.\n\nInputs: Active, Voltage.\nOutputs: Voltage, Throughput, Capacity, Temperature, Tripped.",
})
